"""Quản trị kho hoạt động: nhóm, hoạt động, các bước, ảnh (quyền activity.write)."""

import uuid
from pathlib import Path
from uuid import UUID

from fastapi import HTTPException, UploadFile, status
from psycopg2 import errors
from psycopg2.extensions import connection as Connection

from app.features.activities.schema import (
    AdminActivityCreate,
    AdminActivityUpdate,
    AdminGroupCreate,
    AdminGroupUpdate,
    AdminMediaUpdate,
    AdminStepIn,
)
from app.shared.audit import audit

STATIC_DIR = Path(__file__).resolve().parents[3] / "static"
UPLOAD_PREFIX = "/static/activities/uploads"
MAX_IMAGE_BYTES = 5 * 1024 * 1024
# Nhận diện ảnh theo vài byte đầu, không tin Content-Type của trình duyệt
_IMAGE_SIGNATURES = ((b"\xff\xd8\xff", ".jpg"), (b"\x89PNG\r\n\x1a\n", ".png"))

_GROUP_COLUMNS = {"code", "name", "description", "emoji", "tint_hex", "detail_kind", "sort_order", "is_active"}
_ACTIVITY_COLUMNS = {
    "title", "summary", "content", "group_id", "status", "age_from_months", "age_to_months",
    "duration_minutes", "materials", "material_items", "goal", "safety_note", "needs_adult",
    "lyrics", "thumbnail_url",
}


def _integrity(error: Exception) -> HTTPException:
    if isinstance(error, errors.UniqueViolation):
        return HTTPException(status.HTTP_409_CONFLICT, "Mã đã tồn tại")
    if isinstance(error, errors.ForeignKeyViolation):
        return HTTPException(status.HTTP_409_CONFLICT, "Nhóm không tồn tại")
    return HTTPException(422, "Dữ liệu không hợp lệ")


# ---------------------------------------------------------------------
# Nhóm
# ---------------------------------------------------------------------
_GROUP_SELECT = """
    SELECT g.id, g.code, g.name, g.description, g.emoji, g.tint_hex, g.detail_kind, g.sort_order, g.is_active,
           count(a.id) AS activity_count,
           count(a.id) FILTER (WHERE a.status = 'published') AS published_count
    FROM activity.activity_groups g
    LEFT JOIN activity.activities a ON a.group_id = g.id
"""


def _group(cur, group_id: int) -> dict:
    cur.execute(_GROUP_SELECT + " WHERE g.id = %s GROUP BY g.id", (group_id,))
    row = cur.fetchone()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy nhóm")
    return row


def list_groups(conn: Connection) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(_GROUP_SELECT + " GROUP BY g.id ORDER BY g.sort_order, g.id")
        return cur.fetchall()


def create_group(conn: Connection, role: str, body: AdminGroupCreate) -> dict:
    data = {k: v for k, v in body.model_dump(exclude_unset=True).items() if k in _GROUP_COLUMNS}
    data["code"], data["name"] = body.code, body.name
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                f"INSERT INTO activity.activity_groups ({', '.join(data)}) "
                f"VALUES ({', '.join(f'%({k})s' for k in data)}) RETURNING id",
                data,
            )
            group_id = cur.fetchone()["id"]
            audit(cur, role, "create", "activity_group", group_id, None, data)
            return _group(cur, group_id)
    except (errors.IntegrityError, errors.CheckViolation) as error:
        raise _integrity(error) from None


def update_group(conn: Connection, role: str, group_id: int, body: AdminGroupUpdate) -> dict:
    changes = body.model_dump(exclude_unset=True)
    try:
        with conn, conn.cursor() as cur:
            before = _group(cur, group_id)
            if not changes:
                return before
            cur.execute(
                f"UPDATE activity.activity_groups SET {', '.join(f'{k} = %({k})s' for k in changes)}, "
                "updated_at = now() WHERE id = %(_id)s",
                {**changes, "_id": group_id},
            )
            after = _group(cur, group_id)
            audit(cur, role, "update", "activity_group", group_id, before, after)
            return after
    except (errors.IntegrityError, errors.CheckViolation) as error:
        raise _integrity(error) from None


# ---------------------------------------------------------------------
# Hoạt động
# ---------------------------------------------------------------------
def list_activities(conn: Connection) -> list[dict]:
    """Mọi trạng thái; lọc / tìm ở web (136+ dòng)."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT a.id, a.title, a.group_id, g.name AS group_name, a.status, a.age_from_months,
                   a.age_to_months, a.duration_minutes, a.thumbnail_url, a.updated_at,
                   (SELECT count(*) FROM activity.activity_steps s WHERE s.activity_id = a.id) AS step_count,
                   (SELECT count(*) FROM activity.activity_media m WHERE m.activity_id = a.id) AS media_count
            FROM activity.activities a
            LEFT JOIN activity.activity_groups g ON g.id = a.group_id
            ORDER BY a.age_from_months, a.age_to_months, a.title
            """
        )
        return cur.fetchall()


def _activity(cur, activity_id: UUID) -> dict:
    cur.execute(
        """
        SELECT id, title, summary, content, group_id, status, age_from_months, age_to_months,
               duration_minutes, materials, coalesce(material_items, '{}') AS material_items, goal,
               safety_note, needs_adult, lyrics, thumbnail_url, published_at, created_at, updated_at
        FROM activity.activities WHERE id = %s
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
        SELECT id, media_type, url, caption, sort_order
        FROM activity.activity_media WHERE activity_id = %s ORDER BY sort_order, id
        """,
        (str(activity_id),),
    )
    return {**activity, "steps": steps, "media": cur.fetchall()}


def get_activity(conn: Connection, activity_id: UUID) -> dict:
    with conn.cursor() as cur:
        return _activity(cur, activity_id)


def create_activity(conn: Connection, role: str, body: AdminActivityCreate) -> dict:
    """Tạo bản nháp; soạn nội dung, bước, ảnh rồi mới xuất bản."""
    data = body.model_dump()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO activity.activities
                    (title, group_id, age_from_months, age_to_months, content, activity_type, status, needs_adult)
                VALUES (%(title)s, %(group_id)s, %(age_from_months)s, %(age_to_months)s, '', 'play', 'draft', true)
                RETURNING id
                """,
                data,
            )
            activity_id = cur.fetchone()["id"]
            audit(cur, role, "create", "activity", activity_id, None, data)
            return _activity(cur, activity_id)
    except (errors.IntegrityError, errors.CheckViolation) as error:
        raise _integrity(error) from None


def update_activity(conn: Connection, role: str, activity_id: UUID, body: AdminActivityUpdate) -> dict:
    changes = body.model_dump(exclude_unset=True)
    try:
        with conn, conn.cursor() as cur:
            before = _activity(cur, activity_id)
            if not changes:
                return before
            ages = (
                changes.get("age_from_months", before["age_from_months"]),
                changes.get("age_to_months", before["age_to_months"]),
            )
            if ages[0] > ages[1]:
                raise HTTPException(422, "Tuổi bắt đầu phải nhỏ hơn hoặc bằng tuổi kết thúc")
            publishing = changes.get("status") == "published" and before["status"] != "published"
            content = changes.get("content", before["content"]) or ""
            if publishing and not content.strip() and not before["steps"]:
                raise HTTPException(422, "Cần có nội dung hoặc ít nhất 1 bước trước khi xuất bản")
            assignments = [f"{k} = %({k})s" for k in changes]
            if publishing and before["published_at"] is None:
                assignments.append("published_at = now()")
            cur.execute(
                f"UPDATE activity.activities SET {', '.join(assignments)}, updated_at = now() WHERE id = %(_id)s",
                {**changes, "_id": str(activity_id)},
            )
            after = _activity(cur, activity_id)
            audit(cur, role, "publish" if publishing else "update", "activity", activity_id,
                  _brief(before), _brief(after))
            return after
    except (errors.IntegrityError, errors.CheckViolation) as error:
        raise _integrity(error) from None


def _brief(activity: dict) -> dict:
    """Bản ghi nhật ký: bỏ danh sách bước / ảnh cho gọn."""
    return {k: v for k, v in activity.items() if k not in ("steps", "media")}


def replace_steps(conn: Connection, role: str, activity_id: UUID, steps: list[AdminStepIn]) -> dict:
    """Ghi đè các bước theo thứ tự gửi lên (đánh số 1..n).

    Sửa tại chỗ theo số thứ tự thay vì xóa hết rồi thêm lại: diary_entry_steps tham
    chiếu step id (ON DELETE CASCADE), xóa sẽ mất các bước phụ huynh đã đánh dấu.
    Chỉ các bước thừa ở cuối bị xóa.
    """
    with conn, conn.cursor() as cur:
        before = _activity(cur, activity_id)
        urls = {m["url"] for m in before["media"]}
        if any(s.image_url and s.image_url not in urls for s in steps):
            raise HTTPException(422, "Ảnh của bước phải là ảnh đã tải lên cho hoạt động này")
        for number, step in enumerate(steps, 1):
            values = (step.title, step.instruction.strip(), step.image_url, str(activity_id), number)
            if number <= len(before["steps"]):
                cur.execute(
                    """
                    UPDATE activity.activity_steps SET title = %s, instruction = %s, image_url = %s
                    WHERE activity_id = %s AND step_number = %s
                    """,
                    values,
                )
            else:
                cur.execute(
                    """
                    INSERT INTO activity.activity_steps (title, instruction, image_url, activity_id, step_number)
                    VALUES (%s, %s, %s, %s, %s)
                    """,
                    values,
                )
        cur.execute(
            "DELETE FROM activity.activity_steps WHERE activity_id = %s AND step_number > %s",
            (str(activity_id), len(steps)),
        )
        cur.execute("UPDATE activity.activities SET updated_at = now() WHERE id = %s", (str(activity_id),))
        after = _activity(cur, activity_id)
        audit(cur, role, "update_steps", "activity", activity_id,
              {"steps": before["steps"]}, {"steps": after["steps"]})
        return after


# ---------------------------------------------------------------------
# Ảnh
# ---------------------------------------------------------------------
async def upload_image(
    conn: Connection, role: str, activity_id: UUID, file: UploadFile, caption: str | None
) -> dict:
    data = await file.read(MAX_IMAGE_BYTES + 1)
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Ảnh tối đa 5 MB")
    ext = next((e for sig, e in _IMAGE_SIGNATURES if data.startswith(sig)), None)
    if ext is None and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        ext = ".webp"
    if ext is None:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Chỉ nhận ảnh JPG, PNG hoặc WebP")

    with conn, conn.cursor() as cur:
        _activity(cur, activity_id)
        name = f"{uuid.uuid4().hex}{ext}"
        folder = STATIC_DIR / "activities" / "uploads" / str(activity_id)
        folder.mkdir(parents=True, exist_ok=True)
        (folder / name).write_bytes(data)
        url = f"{UPLOAD_PREFIX}/{activity_id}/{name}"
        cur.execute(
            """
            INSERT INTO activity.activity_media (activity_id, media_type, url, caption, sort_order)
            SELECT %s, 'image', %s, %s, coalesce(max(sort_order) + 1, 0)
            FROM activity.activity_media WHERE activity_id = %s
            RETURNING id
            """,
            (str(activity_id), url, caption, str(activity_id)),
        )
        media_id = cur.fetchone()["id"]
        # Hoạt động chưa có ảnh đại diện: dùng ảnh đầu tiên
        cur.execute(
            "UPDATE activity.activities SET thumbnail_url = coalesce(thumbnail_url, %s), updated_at = now() "
            "WHERE id = %s",
            (url, str(activity_id)),
        )
        audit(cur, role, "upload", "activity_media", media_id, None, {"activityId": activity_id, "url": url})
        return _activity(cur, activity_id)


def _media(cur, media_id: UUID) -> dict:
    cur.execute("SELECT * FROM activity.activity_media WHERE id = %s", (str(media_id),))
    media = cur.fetchone()
    if media is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy ảnh")
    return media


def update_media(conn: Connection, role: str, media_id: UUID, body: AdminMediaUpdate) -> dict:
    changes = body.model_dump(exclude_unset=True)
    with conn, conn.cursor() as cur:
        before = _media(cur, media_id)
        if changes:
            cur.execute(
                f"UPDATE activity.activity_media SET {', '.join(f'{k} = %({k})s' for k in changes)} "
                "WHERE id = %(_id)s",
                {**changes, "_id": str(media_id)},
            )
            audit(cur, role, "update", "activity_media", media_id, before, changes)
        return _activity(cur, before["activity_id"])


def delete_media(conn: Connection, role: str, media_id: UUID) -> dict:
    """Xóa ảnh; gỡ khỏi ảnh đại diện / các bước. File chỉ bị xóa nếu do admin tải lên."""
    with conn, conn.cursor() as cur:
        media = _media(cur, media_id)
        activity_id, url = media["activity_id"], media["url"]
        cur.execute("DELETE FROM activity.activity_media WHERE id = %s", (str(media_id),))
        cur.execute(
            "UPDATE activity.activity_steps SET image_url = NULL WHERE activity_id = %s AND image_url = %s",
            (str(activity_id), url),
        )
        cur.execute(
            """
            UPDATE activity.activities a SET updated_at = now(),
                thumbnail_url = CASE WHEN a.thumbnail_url = %(url)s THEN
                    (SELECT m.url FROM activity.activity_media m WHERE m.activity_id = a.id
                     ORDER BY m.sort_order, m.id LIMIT 1)
                    ELSE a.thumbnail_url END
            WHERE a.id = %(id)s
            """,
            {"url": url, "id": str(activity_id)},
        )
        audit(cur, role, "delete", "activity_media", media_id, dict(media), None)
        result = _activity(cur, activity_id)
    if url.startswith(UPLOAD_PREFIX + "/"):
        (STATIC_DIR / url.removeprefix("/static/")).unlink(missing_ok=True)
    return result
