from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.core.security import current_user_id, require_admin
from app.features.activities import admin_service, service
from app.features.activities.schema import (
    ActivityDetail,
    ActivityGroup,
    ActivityProgress,
    ActivityProgressUpdate,
    ActivitySummary,
    AdminActivity,
    AdminActivityCreate,
    AdminActivityRow,
    AdminActivityUpdate,
    AdminGroup,
    AdminGroupCreate,
    AdminGroupUpdate,
    AdminMediaUpdate,
    AdminStepsUpdate,
)
from app.shared.access import require_child_access

router = APIRouter(tags=["activities"])


# ---------------------------------------------------------------------
# Nội dung: không cần đăng nhập (dùng chung cho mọi phụ huynh)
# ---------------------------------------------------------------------
@router.get("/activity-groups", response_model=list[ActivityGroup])
def get_groups(conn: Connection = Depends(get_db)):
    return service.list_groups(conn)


@router.get("/activities", response_model=list[ActivitySummary])
def get_activities(
    group: str | None = Query(None, description="activity_groups.code, vd gross_motor"),
    age_months: int | None = Query(None, alias="ageMonths", ge=0, le=72),
    conn: Connection = Depends(get_db),
):
    return service.list_activities(conn, group, age_months)


@router.get("/activities/{activity_id}", response_model=ActivityDetail)
def get_activity(activity_id: UUID, conn: Connection = Depends(get_db)):
    return service.get_activity(conn, activity_id)


# ---------------------------------------------------------------------
# "Đã làm" theo từng bé (theo quyền chia sẻ 'activities')
# ---------------------------------------------------------------------
@router.get("/children/{child_id}/activity-progress", response_model=list[ActivityProgress])
def get_progress(
    child_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return service.list_progress(conn, child_id)


@router.put(
    "/children/{child_id}/activity-progress/{activity_id}", response_model=list[ActivityProgress]
)
def put_progress(
    child_id: UUID,
    activity_id: UUID,
    body: ActivityProgressUpdate,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    """done=false xóa đánh dấu. Trả về toàn bộ trạng thái của bé."""
    require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    return service.set_progress(conn, child_id, activity_id, user_id, body.done)


# ---------------------------------------------------------------------
# "Yêu thích" theo phụ huynh (không theo bé, không chia sẻ)
# ---------------------------------------------------------------------
@router.get("/me/activity-favorites", response_model=list[UUID])
def get_favorites(user_id: UUID = Depends(current_user_id), conn: Connection = Depends(get_db)):
    return service.list_favorites(conn, user_id)


@router.put("/me/activity-favorites/{activity_id}", response_model=list[UUID])
def put_favorite(
    activity_id: UUID, user_id: UUID = Depends(current_user_id), conn: Connection = Depends(get_db)
):
    return service.set_favorite(conn, user_id, activity_id, True)


@router.delete("/me/activity-favorites/{activity_id}", response_model=list[UUID])
def delete_favorite(
    activity_id: UUID, user_id: UUID = Depends(current_user_id), conn: Connection = Depends(get_db)
):
    return service.set_favorite(conn, user_id, activity_id, False)


# ---------------------------------------------------------------------
# Web admin (quyền activity.write)
# ---------------------------------------------------------------------
admin_router = APIRouter(prefix="/admin", tags=["admin: activities"])
admin = require_admin("activity.write")


@admin_router.get("/activity-groups", response_model=list[AdminGroup])
def admin_list_groups(_: str = Depends(admin), conn: Connection = Depends(get_db)):
    return admin_service.list_groups(conn)


@admin_router.post("/activity-groups", response_model=AdminGroup, status_code=status.HTTP_201_CREATED)
def admin_create_group(body: AdminGroupCreate, role: str = Depends(admin), conn: Connection = Depends(get_db)):
    return admin_service.create_group(conn, role, body)


@admin_router.patch("/activity-groups/{group_id}", response_model=AdminGroup)
def admin_update_group(
    group_id: int, body: AdminGroupUpdate, role: str = Depends(admin), conn: Connection = Depends(get_db)
):
    return admin_service.update_group(conn, role, group_id, body)


@admin_router.get("/activities", response_model=list[AdminActivityRow])
def admin_list_activities(_: str = Depends(admin), conn: Connection = Depends(get_db)):
    return admin_service.list_activities(conn)


@admin_router.post("/activities", response_model=AdminActivity, status_code=status.HTTP_201_CREATED)
def admin_create_activity(
    body: AdminActivityCreate, role: str = Depends(admin), conn: Connection = Depends(get_db)
):
    """Tạo bản nháp (status = draft)."""
    return admin_service.create_activity(conn, role, body)


@admin_router.get("/activities/{activity_id}", response_model=AdminActivity)
def admin_get_activity(activity_id: UUID, _: str = Depends(admin), conn: Connection = Depends(get_db)):
    return admin_service.get_activity(conn, activity_id)


@admin_router.patch("/activities/{activity_id}", response_model=AdminActivity)
def admin_update_activity(
    activity_id: UUID, body: AdminActivityUpdate, role: str = Depends(admin), conn: Connection = Depends(get_db)
):
    """Sửa nội dung và trạng thái (draft → published → hidden). Không xóa: nhật ký của bé có thể đang gắn."""
    return admin_service.update_activity(conn, role, activity_id, body)


@admin_router.put("/activities/{activity_id}/steps", response_model=AdminActivity)
def admin_replace_steps(
    activity_id: UUID, body: AdminStepsUpdate, role: str = Depends(admin), conn: Connection = Depends(get_db)
):
    return admin_service.replace_steps(conn, role, activity_id, body.steps)


@admin_router.post("/activities/{activity_id}/media", response_model=AdminActivity,
                   status_code=status.HTTP_201_CREATED)
async def admin_upload_image(
    activity_id: UUID,
    file: Annotated[UploadFile, File(description="JPG / PNG / WebP ≤ 5 MB")],
    caption: Annotated[str | None, Form(max_length=300)] = None,
    role: str = Depends(admin),
    conn: Connection = Depends(get_db),
):
    return await admin_service.upload_image(conn, role, activity_id, file, caption)


@admin_router.patch("/activity-media/{media_id}", response_model=AdminActivity)
def admin_update_media(
    media_id: UUID, body: AdminMediaUpdate, role: str = Depends(admin), conn: Connection = Depends(get_db)
):
    return admin_service.update_media(conn, role, media_id, body)


@admin_router.delete("/activity-media/{media_id}", response_model=AdminActivity)
def admin_delete_media(media_id: UUID, role: str = Depends(admin), conn: Connection = Depends(get_db)):
    return admin_service.delete_media(conn, role, media_id)
