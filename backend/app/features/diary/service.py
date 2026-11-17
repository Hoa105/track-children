"""Nhật ký phát triển (F07): lưu bản nhật ký mobile ghi để không mất khi đổi máy.

Mobile sinh id nhật ký (client_ref) và gửi cả bài mỗi lần lưu (PUT = thêm hoặc
sửa). Xóa là xóa mềm; nhật ký đã xóa không được tạo lại bằng cùng id.

Ảnh / video: mobile lưu nhật ký (kèm danh sách id file) rồi tải từng file lên
MinIO qua backend. Mobile xem file bằng link tải có thời hạn.
"""

import mimetypes
from pathlib import Path
from uuid import UUID

from fastapi import HTTPException, UploadFile, status
from psycopg2.extensions import connection as Connection
from psycopg2.extras import Json

from app.core.config import settings
from app.features.diary.schema import DiaryEntryIn
from app.shared import storage

SCOPE = "diary"
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".gif"}
VIDEO_SUFFIXES = {".mp4", ".mov", ".m4v", ".3gp", ".webm", ".mkv"}

_SELECT = """
    SELECT e.id AS pk,
           coalesce(e.client_ref, e.id::text) AS id,
           coalesce(e.entry_at, e.entry_date::timestamp) AS date,
           coalesce(e.content, e.title, '') AS note,
           e.mood, e.activity_ref AS activity_id, e.activity_name,
           e.video_insight AS insight, e.updated_at,
           coalesce(array_agg(d.code ORDER BY d.sort_order) FILTER (WHERE d.code IS NOT NULL),
                    '{}') AS domains
    FROM diary.diary_entries e
    LEFT JOIN diary.diary_entry_domains ed ON ed.entry_id = e.id
    LEFT JOIN criteria.developmental_domains d ON d.id = ed.domain_id
"""


def _media_item(row: dict, base_url: str) -> dict:
    url, expires_at = storage.presign(row["storage_key"], base_url)
    return {
        "id": row["id"],
        "type": row["media_type"],
        "url": url,
        "expires_at": expires_at,
        "size_bytes": row["size_bytes"],
    }


def _with_media(cur, entries: list[dict], base_url: str) -> list[dict]:
    """Gắn file đã tải lên xong (link tải ký theo base_url) vào từng nhật ký."""
    by_entry: dict = {e["pk"]: [] for e in entries}
    if by_entry:
        cur.execute(
            """
            SELECT m.id, m.entry_id, m.media_type, m.storage_key, m.size_bytes
            FROM diary.diary_media m
            JOIN diary.diary_entries e ON e.id = m.entry_id
            WHERE m.entry_id = ANY(%s::uuid[]) AND m.status = 'ready' AND m.storage_key IS NOT NULL
            ORDER BY array_position(e.media_order, m.id) NULLS LAST, m.created_at
            """,
            ([str(pk) for pk in by_entry],),
        )
        for row in cur.fetchall():
            by_entry[row["entry_id"]].append(_media_item(row, base_url))
    return [{**e, "media": by_entry[e["pk"]]} for e in entries]


def _entry_pk(cur, child_id: UUID, entry_id: str) -> UUID:
    cur.execute(
        """
        SELECT id FROM diary.diary_entries
        WHERE child_id = %s AND client_ref = %s AND deleted_at IS NULL
        """,
        (str(child_id), entry_id),
    )
    row = cur.fetchone()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy nhật ký")
    return row["id"]


def list_entries(conn: Connection, child_id: UUID, base_url: str) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(
            f"""{_SELECT}
            WHERE e.child_id = %s AND e.deleted_at IS NULL
            GROUP BY e.id
            ORDER BY date DESC, e.created_at DESC
            """,
            (str(child_id),),
        )
        return _with_media(cur, cur.fetchall(), base_url)


def save_entry(
    conn: Connection,
    child_id: UUID,
    user_id: UUID,
    entry_id: str,
    body: DiaryEntryIn,
    base_url: str,
) -> dict:
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO diary.diary_entries
                (child_id, client_ref, author_id, content, mood, entry_at, entry_date,
                 activity_id, activity_ref, activity_name, video_insight, media_order)
            VALUES (%(child)s, %(ref)s, %(user)s, %(note)s, %(mood)s, %(at)s, %(at)s::date,
                    (SELECT id FROM activity.activities WHERE id::text = %(activity)s),
                    %(activity)s, %(activity_name)s, %(insight)s, %(media)s::uuid[])
            ON CONFLICT (child_id, client_ref) WHERE client_ref IS NOT NULL DO UPDATE
            SET content = EXCLUDED.content, mood = EXCLUDED.mood,
                entry_at = EXCLUDED.entry_at, entry_date = EXCLUDED.entry_date,
                activity_id = EXCLUDED.activity_id, activity_ref = EXCLUDED.activity_ref,
                activity_name = EXCLUDED.activity_name, video_insight = EXCLUDED.video_insight,
                media_order = EXCLUDED.media_order, updated_by = %(user)s, updated_at = now()
            WHERE diary_entries.deleted_at IS NULL
            RETURNING id
            """,
            {
                "child": str(child_id),
                "ref": entry_id,
                "user": str(user_id),
                "note": body.note,
                "mood": body.mood,
                "at": body.date.replace(tzinfo=None),
                "activity": body.activity_id,
                "activity_name": body.activity_name,
                "insight": None if body.insight is None else Json(body.insight),
                "media": [str(m.id) for m in body.media],
            },
        )
        row = cur.fetchone()
        if row is None:
            raise HTTPException(status.HTTP_410_GONE, "Nhật ký này đã bị xóa")
        pk = row["id"]
        cur.execute("DELETE FROM diary.diary_entry_domains WHERE entry_id = %s", (pk,))
        cur.execute(
            """
            INSERT INTO diary.diary_entry_domains (entry_id, domain_id)
            SELECT %s, id FROM criteria.developmental_domains WHERE code = ANY(%s)
            """,
            (pk, list(body.domains)),
        )
        keep = [str(m.id) for m in body.media]
        cur.execute(
            """
            DELETE FROM diary.diary_media
            WHERE entry_id = %s AND NOT (id = ANY(%s::uuid[]))
            RETURNING storage_key
            """,
            (pk, keep),
        )
        removed = [r["storage_key"] for r in cur.fetchall() if r["storage_key"]]
        cur.execute(f"{_SELECT} WHERE e.id = %s GROUP BY e.id", (pk,))
        entry = _with_media(cur, [cur.fetchone()], base_url)[0]
    for key in removed:
        storage.remove(key)
    return entry


def _media_kind(upload: UploadFile) -> tuple[str, str]:
    """(image | video, đuôi file). Android đôi khi gửi application/octet-stream → xét cả đuôi."""
    suffix = Path(upload.filename or "").suffix.lower()
    content_type = (upload.content_type or "").lower()
    if content_type.startswith("image/") or suffix in IMAGE_SUFFIXES:
        return "image", suffix if suffix in IMAGE_SUFFIXES else ".jpg"
    if content_type.startswith("video/") or suffix in VIDEO_SUFFIXES:
        return "video", suffix if suffix in VIDEO_SUFFIXES else ".mp4"
    raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, "Chỉ nhận ảnh hoặc video")


def upload_media(
    conn: Connection,
    child_id: UUID,
    entry_id: str,
    media_id: UUID,
    upload: UploadFile,
    base_url: str,
) -> dict:
    """Lưu file lên MinIO. Gửi lại cùng media_id thì ghi đè (mobile thử lại khi mất mạng)."""
    kind, suffix = _media_kind(upload)
    limit_mb = settings.diary_image_max_mb if kind == "image" else settings.diary_video_max_mb
    size = upload.size
    if size is None:
        upload.file.seek(0, 2)
        size = upload.file.tell()
        upload.file.seek(0)
    if size > limit_mb * 1024 * 1024:
        raise HTTPException(
            413,
            f"{'Ảnh' if kind == 'image' else 'Video'} vượt quá {limit_mb} MB",
        )
    key = f"diary/{child_id}/{media_id}{suffix}"
    content_type = (upload.content_type or "").lower()
    if not content_type.startswith(f"{kind}/"):
        # MinIO trả lại content-type này khi tải; iOS cần đúng loại mới phát được video
        content_type = mimetypes.guess_type(f"x{suffix}")[0] or (
            "image/jpeg" if kind == "image" else "video/mp4"
        )
    with conn, conn.cursor() as cur:
        pk = _entry_pk(cur, child_id, entry_id)
        cur.execute(
            """
            INSERT INTO diary.diary_media
                (id, entry_id, media_type, storage_key, content_type, status)
            VALUES (%s, %s, %s, %s, %s, 'uploading')
            ON CONFLICT (id) DO UPDATE
            SET media_type = EXCLUDED.media_type, storage_key = EXCLUDED.storage_key,
                content_type = EXCLUDED.content_type, status = 'uploading'
            WHERE diary_media.entry_id = EXCLUDED.entry_id
            RETURNING id
            """,
            (str(media_id), pk, kind, key, content_type),
        )
        if cur.fetchone() is None:
            raise HTTPException(status.HTTP_409_CONFLICT, "File thuộc nhật ký khác")
    # Đã commit trạng thái 'uploading'; tải file lâu không giữ transaction
    try:
        storage.put(key, upload.file, size, content_type)
    except storage.StorageError:
        with conn, conn.cursor() as cur:
            cur.execute("UPDATE diary.diary_media SET status = 'failed' WHERE id = %s", (str(media_id),))
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Chưa lưu được file, vui lòng thử lại") from None
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            UPDATE diary.diary_media SET status = 'ready', size_bytes = %s
            WHERE id = %s
            RETURNING id, media_type, storage_key, size_bytes
            """,
            (size, str(media_id)),
        )
        row = cur.fetchone()
    if row is None:  # nhật ký vừa bỏ file này trong lúc tải
        storage.remove(key)
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Nhật ký không còn file này")
    return _media_item(row, base_url)


def media_url(
    conn: Connection, child_id: UUID, entry_id: str, media_id: UUID, base_url: str
) -> dict:
    """Link tải mới (link cũ hết hạn sau media_url_ttl_minutes)."""
    with conn.cursor() as cur:
        pk = _entry_pk(cur, child_id, entry_id)
        cur.execute(
            """
            SELECT storage_key FROM diary.diary_media
            WHERE id = %s AND entry_id = %s AND status = 'ready' AND storage_key IS NOT NULL
            """,
            (str(media_id), pk),
        )
        row = cur.fetchone()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy file")
    url, expires_at = storage.presign(row["storage_key"], base_url)
    return {"url": url, "expires_at": expires_at}


def delete_entry(conn: Connection, child_id: UUID, user_id: UUID, entry_id: str) -> None:
    """Xóa mềm (F07.3) và xóa ảnh / video trên MinIO. Gọi lại vẫn thành công."""
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            UPDATE diary.diary_entries
            SET deleted_at = now(), deleted_by = %s
            WHERE child_id = %s AND client_ref = %s AND deleted_at IS NULL
            RETURNING id
            """,
            (str(user_id), str(child_id), entry_id),
        )
        row = cur.fetchone()
        keys = []
        if row is not None:
            cur.execute(
                """
                UPDATE diary.diary_media SET status = 'deleted'
                WHERE entry_id = %s AND storage_key IS NOT NULL
                RETURNING storage_key
                """,
                (row["id"],),
            )
            keys = [r["storage_key"] for r in cur.fetchall()]
    for key in keys:
        storage.remove(key)
