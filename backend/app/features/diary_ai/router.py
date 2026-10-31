from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.features.diary_ai import service
from app.features.diary_ai.schema import VideoInsight
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
    conn.rollback()  # trả kết nối về pool sạch trước khi upload lâu
    return service.create_insight(child, user_id, video, activity, consent, note)


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
