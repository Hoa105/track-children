"""API nội bộ — chỉ backend gọi (header X-Internal-Token), mobile không gọi trực tiếp."""

import hmac
import uuid
from pathlib import Path
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Request, Response, UploadFile, status
from pydantic import ValidationError

from app.core.config import settings
from app.insights import service
from app.insights.repository import InsightStore
from app.schemas.insight import Insight, NewInsight

VIDEO_SUFFIXES = {".mp4", ".mov", ".m4v", ".3gp", ".webm", ".mkv"}


def require_internal(x_internal_token: Annotated[str | None, Header()] = None) -> None:
    if not settings.internal_token:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "INTERNAL_TOKEN chưa cấu hình")
    if not x_internal_token or not hmac.compare_digest(x_internal_token, settings.internal_token):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Sai X-Internal-Token")


def get_store(request: Request) -> InsightStore:
    return request.app.state.insight_store


router = APIRouter(prefix="/internal", tags=["internal: video insights"],
                   dependencies=[Depends(require_internal)])


def _save_upload(video: UploadFile) -> Path:
    suffix = Path(video.filename or "").suffix.lower()
    if suffix not in VIDEO_SUFFIXES:
        suffix = ".mp4"
    directory = Path(settings.video_dir)
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f"{uuid.uuid4()}{suffix}"
    written = 0
    try:
        with path.open("wb") as out:
            while chunk := video.file.read(1024 * 1024):
                written += len(chunk)
                if written > settings.max_video_bytes:
                    raise HTTPException(413, "Video quá lớn")
                out.write(chunk)
    except BaseException:
        path.unlink(missing_ok=True)
        raise
    if written == 0:
        path.unlink(missing_ok=True)
        raise HTTPException(422, "Video rỗng")
    return path


@router.post("/video-insights", response_model=Insight, status_code=status.HTTP_202_ACCEPTED)
def create_insight(
    video: Annotated[UploadFile, File()],
    meta: Annotated[str, Form(description="NewInsight dạng JSON")],
    store: InsightStore = Depends(get_store),
):
    """Nhận video + context, xếp hàng phân tích. Kết quả lấy bằng GET."""
    try:
        new = NewInsight.model_validate_json(meta)
    except ValidationError as e:
        raise HTTPException(422, e.errors(include_url=False)) from None
    path = _save_upload(video)
    try:
        row = store.create(new, str(path))
    except BaseException:
        path.unlink(missing_ok=True)
        raise
    return service.to_insight(row)


@router.get("/video-insights/{insight_id}", response_model=Insight)
def get_insight(insight_id: UUID, store: InsightStore = Depends(get_store)):
    row = store.get(insight_id)
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy")
    return service.to_insight(row)


@router.delete("/children/{child_id}/video-insights", status_code=status.HTTP_204_NO_CONTENT)
def delete_child_insights(child_id: UUID, store: InsightStore = Depends(get_store)):
    """Xóa hết video tạm + nhận xét của một bé (xóa hồ sơ trẻ / phụ huynh yêu cầu)."""
    for path in store.delete_for_child(child_id):
        Path(path).unlink(missing_ok=True)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
