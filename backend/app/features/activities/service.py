"""Kho hoạt động (activity.*): nội dung chỉ đọc + "Đã làm" theo bé, "Yêu thích" theo phụ huynh."""

from uuid import UUID

from fastapi import HTTPException, status
from psycopg2.extensions import connection as Connection

# child_member_permissions.data_scope cho "Đã làm" (F23)
SCOPE = "activities"

_SUMMARY_COLUMNS = """
    a.id, g.code AS group_code, a.title, a.summary, a.age_from_months, a.age_to_months,
    a.duration_minutes, a.thumbnail_url
"""

# Mục đã trả riêng qua steps / lyrics nên bỏ khỏi sections
_SKIPPED_SECTIONS = {"Các bước thực hiện", "Lời bài hát / đồng dao"}


def list_groups(conn: Connection) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT g.code, g.name, g.description, g.emoji, g.tint_hex,
                   count(a.id) FILTER (WHERE a.status = 'published') AS activity_count
            FROM activity.activity_groups g
            LEFT JOIN activity.activities a ON a.group_id = g.id
            WHERE g.is_active
            GROUP BY g.id
            ORDER BY g.sort_order, g.id
            """
        )
        return cur.fetchall()


def list_activities(conn: Connection, group: str | None, age_months: int | None) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(
            f"""
            SELECT {_SUMMARY_COLUMNS}
            FROM activity.activities a
            LEFT JOIN activity.activity_groups g ON g.id = a.group_id
            WHERE a.status = 'published'
              AND (%(group)s::text IS NULL OR g.code = %(group)s)
              AND (%(age)s::int IS NULL OR %(age)s BETWEEN a.age_from_months AND a.age_to_months)
            ORDER BY a.age_from_months, a.age_to_months, a.title
            """,
            {"group": group, "age": age_months},
        )
        return cur.fetchall()


def get_activity(conn: Connection, activity_id: UUID) -> dict:
    with conn.cursor() as cur:
        cur.execute(
            f"""
            SELECT {_SUMMARY_COLUMNS}, a.goal, a.materials, coalesce(a.material_items, '{{}}') AS material_items,
                   a.needs_adult, a.lyrics, a.content
            FROM activity.activities a
            LEFT JOIN activity.activity_groups g ON g.id = a.group_id
            WHERE a.id = %s AND a.status = 'published'
            """,
            (str(activity_id),),
        )
        activity = cur.fetchone()
        if activity is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy hoạt động")
        cur.execute(
            """
            SELECT step_number AS number, title, instruction, image_url
            FROM activity.activity_steps WHERE activity_id = %s ORDER BY step_number
            """,
            (str(activity_id),),
        )
        steps = cur.fetchall()
        cur.execute(
            """
            SELECT media_type, url, caption
            FROM activity.activity_media WHERE activity_id = %s ORDER BY sort_order, id
            """,
            (str(activity_id),),
        )
        media = cur.fetchall()
    return {**activity, "sections": parse_sections(activity.pop("content")), "steps": steps, "media": media}


def _require_published(cur, activity_id: UUID) -> None:
    cur.execute(
        "SELECT 1 FROM activity.activities WHERE id = %s AND status = 'published'",
        (str(activity_id),),
    )
    if cur.fetchone() is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy hoạt động")


def list_progress(conn: Connection, child_id: UUID) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT activity_id, status, completed_at
            FROM activity.child_activity_progress
            WHERE child_id = %s
            ORDER BY completed_at DESC NULLS LAST
            """,
            (str(child_id),),
        )
        return cur.fetchall()


def set_progress(conn: Connection, child_id: UUID, activity_id: UUID, user_id: UUID, done: bool) -> list[dict]:
    """Đánh dấu / bỏ đánh dấu "Đã làm"; bỏ đánh dấu thì xóa dòng."""
    with conn, conn.cursor() as cur:
        _require_published(cur, activity_id)
        if done:
            cur.execute(
                """
                INSERT INTO activity.child_activity_progress
                    (child_id, activity_id, status, completed_at, updated_by)
                VALUES (%s, %s, 'done', now(), %s)
                ON CONFLICT (child_id, activity_id) DO UPDATE
                SET status = 'done',
                    completed_at = coalesce(child_activity_progress.completed_at, now()),
                    updated_by = EXCLUDED.updated_by, updated_at = now()
                """,
                (str(child_id), str(activity_id), str(user_id)),
            )
        else:
            cur.execute(
                "DELETE FROM activity.child_activity_progress WHERE child_id = %s AND activity_id = %s",
                (str(child_id), str(activity_id)),
            )
    return list_progress(conn, child_id)


def list_favorites(conn: Connection, user_id: UUID) -> list[UUID]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT activity_id FROM activity.activity_favorites
            WHERE user_id = %s ORDER BY created_at DESC
            """,
            (str(user_id),),
        )
        return [r["activity_id"] for r in cur.fetchall()]


def set_favorite(conn: Connection, user_id: UUID, activity_id: UUID, favorite: bool) -> list[UUID]:
    with conn, conn.cursor() as cur:
        if favorite:
            _require_published(cur, activity_id)
            cur.execute(
                """
                INSERT INTO activity.activity_favorites (user_id, activity_id) VALUES (%s, %s)
                ON CONFLICT DO NOTHING
                """,
                (str(user_id), str(activity_id)),
            )
        else:
            cur.execute(
                "DELETE FROM activity.activity_favorites WHERE user_id = %s AND activity_id = %s",
                (str(user_id), str(activity_id)),
            )
    return list_favorites(conn, user_id)


def parse_sections(content: str) -> list[dict]:
    """Tách content markdown theo tiêu đề `## `; bỏ phần mở đầu, trích dẫn và dòng nguồn."""
    sections = []
    for chunk in ("\n" + content).split("\n## ")[1:]:
        title, _, body = chunk.partition("\n")
        paragraphs = [
            p for p in body.strip().split("\n\n") if p and not p.startswith(">") and not p.startswith("_Nguồn")
        ]
        if title.strip() not in _SKIPPED_SECTIONS and paragraphs:
            sections.append({"title": title.strip(), "body": "\n\n".join(paragraphs)})
    return sections
