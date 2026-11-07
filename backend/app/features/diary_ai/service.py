"""Nhận xét AI cho video nhật ký theo hoạt động.

Backend xác định nhóm hoạt động, lấy tiêu chí quan sát + số đo cần tính (giai
đoạn 2) rồi chuyển video sang ai-service. ai-service xếp hàng, gọi AI và giữ kết
quả; video bị xóa ngay sau khi phân tích.
"""

import datetime as dt
import json
from pathlib import Path
from uuid import UUID

from fastapi import HTTPException, UploadFile, status
from psycopg2.extensions import connection as Connection
from pydantic import ValidationError

from app.core.config import settings
from app.features.diary_ai import criteria
from app.features.diary_ai.schema import ActivityInfo
from app.shared.clients import ai_service

SCOPE = "diary"
VIDEO_SUFFIXES = {".mp4", ".mov", ".m4v", ".3gp", ".webm", ".mkv"}


def age_in_months(date_of_birth: dt.date, today: dt.date) -> int:
    months = (today.year - date_of_birth.year) * 12 + today.month - date_of_birth.month
    if today.day < date_of_birth.day:
        months -= 1
    return max(0, months)


def parse_activity(raw: str) -> ActivityInfo:
    try:
        return ActivityInfo.model_validate_json(raw)
    except ValidationError as e:
        raise HTTPException(422, e.errors(include_url=False)) from None


def check_video(video: UploadFile) -> None:
    suffix = Path(video.filename or "").suffix.lower()
    content_type = (video.content_type or "").lower()
    # Android image_picker đôi khi gửi application/octet-stream → xét cả đuôi file
    if not content_type.startswith("video/") and suffix not in VIDEO_SUFFIXES:
        raise HTTPException(415, "Chỉ nhận file video (mp4, mov…)")
    if video.size is not None and video.size > settings.ai_video_max_mb * 1024 * 1024:
        raise HTTPException(413, f"Video vượt quá {settings.ai_video_max_mb} MB")


def kdst_item_for(conn: Connection, activity_id: str) -> str | None:
    """Bài K-DST gắn với hoạt động (activity.activities.kdst_item). Hoạt động có sẵn trên
    mobile (id dạng g0-9) không nằm trong DB → None."""
    try:
        activity_uuid = UUID(activity_id)
    except ValueError:
        return None
    with conn.cursor() as cur:
        cur.execute("SELECT kdst_item FROM activity.activities WHERE id = %s", (str(activity_uuid),))
        row = cur.fetchone()
    return row["kdst_item"] if row else None


def build_meta(
    child_id: UUID,
    user_id: UUID,
    date_of_birth: dt.date,
    activity: ActivityInfo,
    note: str,
    kdst_item: str | None = None,
) -> dict:
    group = criteria.GROUPS[activity.group]
    now = dt.datetime.now(dt.timezone.utc)
    return {
        "childId": str(child_id),
        "requestedBy": str(user_id),
        "consentedAt": now.isoformat(),
        "context": {
            # kdstItem: ai-service chấm bằng model tự train thay vì gọi LLM
            "activity": {**activity.model_dump(mode="json", by_alias=True), "kdstItem": kdst_item},
            "criteria": {"name": group["name"], "focus": group["focus"], "avoid": group["avoid"]},
            "childAgeMonths": age_in_months(date_of_birth, now.date()),
            "parentNote": note.strip(),
            "metrics": criteria.metrics_for(activity.id, activity.group),
        },
    }


def _ai_call(call):
    try:
        return call()
    except ai_service.AiServiceError as e:
        raise HTTPException(e.status_code, e.detail) from None


def create_insight(
    child: dict,
    user_id: UUID,
    video: UploadFile,
    activity: ActivityInfo,
    consent: bool,
    note: str,
    kdst_item: str | None = None,
) -> dict:
    if not consent:
        raise HTTPException(422, "Cần ba mẹ đồng ý gửi video cho dịch vụ AI trước khi phân tích")
    check_video(video)
    meta = build_meta(child["id"], user_id, child["date_of_birth"], activity, note, kdst_item)
    return _ai_call(
        lambda: ai_service.create_video_insight(
            video.file,
            video.filename or "video.mp4",
            video.content_type or "application/octet-stream",
            json.dumps(meta, ensure_ascii=False),
        )
    )


def get_insight(child_id: UUID, insight_id: UUID) -> dict:
    insight = _ai_call(lambda: ai_service.get_video_insight(insight_id))
    # Không lộ nhận xét của bé khác dù đoán được id
    if insight is None or insight.get("childId") != str(child_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy nhận xét")
    return insight


def create_progress_review(child_id: UUID, user_id: UUID, insight_ids: list[UUID]) -> dict:
    """ai-service kiểm tra các video thuộc bé này và đã nhận xét xong."""
    body = {"childId": str(child_id), "requestedBy": str(user_id),
            "insightIds": [str(i) for i in insight_ids]}
    return _ai_call(lambda: ai_service.create_progress_review(body))


def list_progress_reviews(child_id: UUID, activity_ref: str | None) -> list[dict]:
    return _ai_call(lambda: ai_service.list_progress_reviews(child_id, activity_ref))


def get_progress_review(child_id: UUID, review_id: UUID) -> dict:
    review = _ai_call(lambda: ai_service.get_progress_review(child_id, review_id))
    if review is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy đánh giá")
    return review
