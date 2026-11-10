 """Dashboard admin: đếm trực tiếp trên các bảng nghiệp vụ, không lưu bảng tổng hợp."""

import datetime as dt

from psycopg2.extensions import connection as Connection

BUCKETS = 10  # số cột của biểu đồ nhỏ trên mỗi thẻ
LOCAL_TZ = dt.timezone(dt.timedelta(hours=7))  # from/to là ngày theo giờ Việt Nam (không có DST)

# (tên, bảng, cột thời gian, điều kiện) — chuỗi cố định, không nhận từ người dùng
_SERIES = {
    "users": ("account.users", "created_at", "status <> 'deleted'"),
    "children": ("child.children", "created_at", "deleted_at IS NULL"),
    "assessments": ("assessment.assessments", "completed_at", "status = 'completed'"),
    "diary": ("diary.diary_entries", "created_at", "deleted_at IS NULL"),
}


def _window(cur, date_from: dt.date | None, date_to: dt.date | None):
    """[start, end); không chọn ngày bắt đầu thì lấy từ người dùng đầu tiên."""
    now = dt.datetime.now(LOCAL_TZ)
    end = (
        dt.datetime.combine(date_to + dt.timedelta(days=1), dt.time(), LOCAL_TZ)
        if date_to
        else now
    )
    if date_from:
        start = dt.datetime.combine(date_from, dt.time(), LOCAL_TZ)
    else:
        cur.execute("SELECT min(created_at) AS first FROM account.users")
        start = cur.fetchone()["first"] or end - dt.timedelta(days=30)
    if start >= end:
        start = end - dt.timedelta(days=1)
    return start, end


def _series(cur, name: str, start: dt.datetime, end: dt.datetime) -> list[int]:
    table, column, condition = _SERIES[name]
    cur.execute(
        f"""
        SELECT width_bucket(extract(epoch FROM {column}), %(s)s, %(e)s, %(n)s) AS bucket,
               count(*)::int AS total
        FROM {table}
        WHERE {condition} AND {column} >= %(start)s AND {column} < %(end)s
        GROUP BY bucket
        """,
        {"s": start.timestamp(), "e": end.timestamp(), "n": BUCKETS, "start": start, "end": end},
    )
    counts = [0] * BUCKETS
    for row in cur.fetchall():
        if 1 <= row["bucket"] <= BUCKETS:
            counts[row["bucket"] - 1] = row["total"]
    return counts


def dashboard(conn: Connection, date_from: dt.date | None, date_to: dt.date | None) -> dict:
    with conn.cursor() as cur:
        start, end = _window(cur, date_from, date_to)
        window = {"start": start, "end": end, "since30": dt.datetime.now(LOCAL_TZ) - dt.timedelta(days=30)}
        cur.execute(
            """
            SELECT
              (SELECT count(*) FROM account.users WHERE status <> 'deleted')::int AS users_total,
              (SELECT count(*) FROM account.users WHERE status = 'active')::int AS users_active,
              (SELECT count(*) FROM account.users WHERE status <> 'deleted'
                 AND created_at >= %(since30)s)::int AS users_new30,
              (SELECT count(*) FROM child.children WHERE deleted_at IS NULL)::int AS children_total,
              (SELECT count(*) FROM child.children WHERE deleted_at IS NULL
                 AND created_at >= %(since30)s)::int AS children_new30,
              (SELECT count(*) FROM assessment.assessments
                 WHERE started_at >= %(start)s AND started_at < %(end)s)::int AS assessments_started,
              (SELECT count(*) FROM assessment.assessments WHERE status = 'completed'
                 AND started_at >= %(start)s AND started_at < %(end)s)::int AS assessments_started_completed,
              (SELECT count(DISTINCT child_id) FROM diary.diary_entries WHERE deleted_at IS NULL
                 AND created_at >= %(start)s AND created_at < %(end)s)::int AS diary_children
            """,
            window,
        )
        totals = cur.fetchone()
        series = {name: _series(cur, name, start, end) for name in _SERIES}

        cur.execute(
            """
            SELECT r.id, r.user_id, u.display_name, u.email, u.phone, r.reason,
                   r.requested_at, r.scheduled_at,
                   (SELECT count(*) FROM child.children c
                    WHERE c.owner_user_id = r.user_id AND c.deleted_at IS NULL)::int AS owned_children
            FROM account.data_deletion_requests r
            JOIN account.users u ON u.id = r.user_id
            WHERE r.status = 'pending' AND r.requested_at >= %(start)s AND r.requested_at < %(end)s
            ORDER BY r.scheduled_at NULLS LAST, r.requested_at
            """,
            window,
        )
        deletions = cur.fetchall()

        cur.execute(
            """
            SELECT u.id, u.display_name, u.email, u.phone, u.status, u.created_at,
                   (SELECT count(*) FROM child.children c
                    WHERE c.owner_user_id = u.id AND c.deleted_at IS NULL)::int AS owned_children
            FROM account.users u
            WHERE u.status <> 'deleted' AND u.created_at >= %(start)s AND u.created_at < %(end)s
            ORDER BY u.created_at DESC
            LIMIT 5
            """,
            window,
        )
        newest = cur.fetchall()

    started = totals["assessments_started"]
    return {
        "range": {"start": start, "end": end},
        "users": {
            "total": totals["users_total"],
            "active": totals["users_active"],
            "new30d": totals["users_new30"],
            "newInRange": sum(series["users"]),
            "series": series["users"],
        },
        "children": {
            "total": totals["children_total"],
            "new30d": totals["children_new30"],
            "newInRange": sum(series["children"]),
            "series": series["children"],
        },
        "assessments": {
            "completedInRange": sum(series["assessments"]),
            "completionRate": round(100 * totals["assessments_started_completed"] / started) if started else None,
            "series": series["assessments"],
        },
        "diary": {
            "entriesInRange": sum(series["diary"]),
            "childrenInRange": totals["diary_children"],
            "series": series["diary"],
        },
        "pendingDeletions": [
            {
                "id": row["id"],
                "userId": row["user_id"],
                "name": row["display_name"],
                "contact": row["email"] or row["phone"],
                "reason": row["reason"],
                "requestedAt": row["requested_at"],
                "scheduledAt": row["scheduled_at"],
                "ownedChildren": row["owned_children"],
            }
            for row in deletions
        ],
        "newestUsers": [
            {
                "id": row["id"],
                "name": row["display_name"],
                "email": row["email"],
                "phone": row["phone"],
                "status": row["status"],
                "joinedAt": row["created_at"],
                "ownedChildren": row["owned_children"],
            }
            for row in newest
        ],
    }
