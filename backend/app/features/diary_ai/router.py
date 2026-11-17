from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.features.diary_ai import service
from app.features.diary_ai.schema import NewProgressReview, ProgressReview, VideoInsight
from app.shared.access import require_child_access

router = APIRouter(tags=["diary: video insights"])


@router.post(
    "/children/{child_id}/diary/video-insights",
    response_model=VideoInsight,
    status_code=status.HTTP_202_ACCEPTED,
)
def create_video_insight(
    child_id: UUID,
    video: Annotated[UploadFile, File(description="Video ≤ 90 giây")],
    activity: Annotated[str, Form(description="ActivityInfo dạng JSON")],
    consent: Annotated[bool, Form(description="Ba mẹ đồng ý gửi video cho dịch vụ AI")],
    note: Annotated[str, Form(max_length=1000)] = "",
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    """Gửi video nhật ký của một hoạt động để AI nhận xét. Kết quả lấy bằng GET (polling)."""
    child = require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    info = service.parse_activity(activity)
    kdst_item = service.kdst_item_for(conn, info.id) if info.group == "gross_motor" else None
    conn.rollback()  # trả kết nối về pool sạch trước khi upload lâu
    return service.create_insight(child, user_id, video, info, consent, note, kdst_item)


@router.get(
    "/children/{child_id}/diary/video-insights/{insight_id}", response_model=VideoInsight
)
def get_video_insight(
    child_id: UUID,
    insight_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return service.get_insight(child_id, insight_id)


@router.post(
    "/children/{child_id}/diary/progress-reviews",
    response_model=ProgressReview,
    status_code=status.HTTP_201_CREATED,
)
def create_progress_review(
    child_id: UUID,
    body: NewProgressReview,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    """Đánh giá tổng hợp: AI đọc lại nhận xét + số đo của các video đã phân tích và viết
    về sự thay đổi theo thời gian. Cùng tập video thì trả lại kết quả cũ."""
    require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    conn.rollback()  # trả kết nối về pool sạch trước khi chờ AI
    return service.create_progress_review(child_id, user_id, body.insight_ids)


@router.get("/children/{child_id}/diary/progress-reviews", response_model=list[ProgressReview])
def list_progress_reviews(
    child_id: UUID,
    activity_ref: Annotated[str | None, Query(alias="activityRef", max_length=64)] = None,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return service.list_progress_reviews(child_id, activity_ref)


@router.get(
    "/children/{child_id}/diary/progress-reviews/{review_id}", response_model=ProgressReview
)
def get_progress_review(
    child_id: UUID,
    review_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return service.get_progress_review(child_id, review_id)
