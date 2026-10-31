from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Path, Request, Response, UploadFile, status
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.features.diary import service
from app.features.diary.schema import DiaryEntry, DiaryEntryIn, DiaryMedia, MediaUrl
from app.shared import storage
from app.shared.access import require_child_access

router = APIRouter(tags=["diary"])

EntryId = Path(min_length=1, max_length=80, description="id nhật ký do mobile sinh")


def media_base(request: Request) -> str:
    """Gốc URL link tải: cùng host mobile dùng để gọi backend (xem storage.public_base)."""
    return storage.public_base(request.headers.get("host"))


@router.get("/children/{child_id}/diary/entries", response_model=list[DiaryEntry])
def get_entries(
    child_id: UUID,
    user_id: UUID = Depends(current_user_id),
    base_url: str = Depends(media_base),
    conn: Connection = Depends(get_db),
):
    """Nhật ký của bé, mới nhất trước (không gồm nhật ký đã xóa)."""
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return service.list_entries(conn, child_id, base_url)


@router.put("/children/{child_id}/diary/entries/{entry_id}", response_model=DiaryEntry)
def put_entry(
    child_id: UUID,
    body: DiaryEntryIn,
    entry_id: str = EntryId,
    user_id: UUID = Depends(current_user_id),
    base_url: str = Depends(media_base),
    conn: Connection = Depends(get_db),
):
    """Thêm hoặc sửa một nhật ký. 410 nếu nhật ký đã bị xóa.

    File đã tải lên mà không còn trong `media` bị xóa khỏi MinIO.
    """
    require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    return service.save_entry(conn, child_id, user_id, entry_id, body, base_url)


@router.delete(
    "/children/{child_id}/diary/entries/{entry_id}", status_code=status.HTTP_204_NO_CONTENT
)
def delete_entry(
    child_id: UUID,
    entry_id: str = EntryId,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    service.delete_entry(conn, child_id, user_id, entry_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.put(
    "/children/{child_id}/diary/entries/{entry_id}/media/{media_id}", response_model=DiaryMedia
)
def put_media(
    child_id: UUID,
    media_id: UUID,
    file: Annotated[UploadFile, File(description="Ảnh hoặc video")],
    entry_id: str = EntryId,
    user_id: UUID = Depends(current_user_id),
    base_url: str = Depends(media_base),
    conn: Connection = Depends(get_db),
):
    """Tải ảnh / video của nhật ký lên MinIO (lưu nhật ký trước). Gửi lại cùng id thì ghi đè."""
    require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    return service.upload_media(conn, child_id, entry_id, media_id, file, base_url)


@router.get(
    "/children/{child_id}/diary/entries/{entry_id}/media/{media_id}/url", response_model=MediaUrl
)
def get_media_url(
    child_id: UUID,
    media_id: UUID,
    entry_id: str = EntryId,
    user_id: UUID = Depends(current_user_id),
    base_url: str = Depends(media_base),
    conn: Connection = Depends(get_db),
):
    """Link tải mới cho file (link trong danh sách nhật ký hết hạn sau MEDIA_URL_TTL_MINUTES)."""
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return service.media_url(conn, child_id, entry_id, media_id, base_url)
