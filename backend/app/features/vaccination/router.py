from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id, require_admin
from app.features.vaccination import service
from app.features.vaccination.schema import (
    AdminProduct,
    AdminProductCreate,
    AdminProductUpdate,
    AdminSchedule,
    AdminScheduleCreate,
    AdminScheduleUpdate,
    AdminVaccine,
    AdminVaccineCreate,
    AdminVaccineUpdate,
    CustomDoseReport,
    Schedule,
    VaccinationBatch,
    VaccinationRecord,
    VaccinePlans,
)
from app.shared.access import require_child_access

router = APIRouter(tags=["vaccination"])
admin_router = APIRouter(prefix="/admin", tags=["admin: vaccination"])


# ---------------------------------------------------------------------
# Mobile
# ---------------------------------------------------------------------
@router.get("/vaccines/schedule", response_model=Schedule)
def get_schedule(conn: Connection = Depends(get_db)):
    """Danh mục + lịch tiêm đang áp dụng. Không cần đăng nhập (dữ liệu tham chiếu công khai)."""
    return service.get_schedule(conn)


@router.get("/children/{child_id}/vaccinations", response_model=list[VaccinationRecord])
def get_child_vaccinations(
    child_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return service.list_child_vaccinations(conn, child_id)


@router.put("/children/{child_id}/vaccinations", response_model=list[VaccinationRecord])
def put_child_vaccinations(
    child_id: UUID,
    body: VaccinationBatch,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    """Thêm hoặc cập nhật nhiều mũi cùng lúc (1 transaction)."""
    child = require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    return service.save_child_vaccinations(conn, child, user_id, body.records)


@router.delete(
    "/children/{child_id}/vaccinations/{dose_id}", status_code=status.HTTP_204_NO_CONTENT
)
def delete_child_vaccination(
    child_id: UUID,
    dose_id: str,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    service.delete_child_vaccination(conn, child_id, user_id, dose_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/children/{child_id}/vaccine-plans", response_model=dict[str, bool])
def get_child_plans(
    child_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    """Vắc xin bé theo dõi / không tiêm (chỉ các mục khác mặc định)."""
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return service.get_child_plans(conn, child_id)


@router.put("/children/{child_id}/vaccine-plans", response_model=dict[str, bool])
def put_child_plans(
    child_id: UUID,
    body: VaccinePlans,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    return service.save_child_plans(conn, child_id, user_id, body.plans)


# ---------------------------------------------------------------------
# Web admin (quyền health.write)
# ---------------------------------------------------------------------
admin = require_admin("health.write")


@admin_router.get("/vaccines", response_model=list[AdminVaccine])
def admin_list_vaccines(_: str = Depends(admin), conn: Connection = Depends(get_db)):
    return service.admin_list_vaccines(conn)


@admin_router.post("/vaccines", response_model=AdminVaccine, status_code=status.HTTP_201_CREATED)
def admin_create_vaccine(
    body: AdminVaccineCreate, role: str = Depends(admin), conn: Connection = Depends(get_db)
):
    return service.admin_create_vaccine(conn, role, body)


@admin_router.patch("/vaccines/{vaccine_id}", response_model=AdminVaccine)
def admin_update_vaccine(
    vaccine_id: int,
    body: AdminVaccineUpdate,
    role: str = Depends(admin),
    conn: Connection = Depends(get_db),
):
    return service.admin_update_vaccine(conn, role, vaccine_id, body)


@admin_router.get("/vaccine-products", response_model=list[AdminProduct])
def admin_list_products(_: str = Depends(admin), conn: Connection = Depends(get_db)):
    return service.admin_list_products(conn)


@admin_router.post(
    "/vaccine-products", response_model=AdminProduct, status_code=status.HTTP_201_CREATED
)
def admin_create_product(
    body: AdminProductCreate, role: str = Depends(admin), conn: Connection = Depends(get_db)
):
    return service.admin_create_product(conn, role, body)


@admin_router.patch("/vaccine-products/{product_id}", response_model=AdminProduct)
def admin_update_product(
    product_id: int,
    body: AdminProductUpdate,
    role: str = Depends(admin),
    conn: Connection = Depends(get_db),
):
    return service.admin_update_product(conn, role, product_id, body)


@admin_router.get("/vaccine-schedules", response_model=list[AdminSchedule])
def admin_list_schedules(_: str = Depends(admin), conn: Connection = Depends(get_db)):
    return service.admin_list_schedules(conn)


@admin_router.post(
    "/vaccine-schedules", response_model=AdminSchedule, status_code=status.HTTP_201_CREATED
)
def admin_create_schedule(
    body: AdminScheduleCreate, role: str = Depends(admin), conn: Connection = Depends(get_db)
):
    return service.admin_create_schedule(conn, role, body)


@admin_router.patch("/vaccine-schedules/{schedule_id}", response_model=AdminSchedule)
def admin_update_schedule(
    schedule_id: int,
    body: AdminScheduleUpdate,
    role: str = Depends(admin),
    conn: Connection = Depends(get_db),
):
    return service.admin_update_schedule(conn, role, schedule_id, body)


@admin_router.delete("/vaccine-schedules/{schedule_id}", status_code=status.HTTP_204_NO_CONTENT)
def admin_delete_schedule(
    schedule_id: int, role: str = Depends(admin), conn: Connection = Depends(get_db)
):
    service.admin_delete_schedule(conn, role, schedule_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@admin_router.get("/vaccinations/custom-summary", response_model=CustomDoseReport)
def admin_custom_dose_report(_: str = Depends(admin), conn: Connection = Depends(get_db)):
    """Mũi tiêm ngoài lịch phụ huynh tự thêm, gộp theo tên — ẩn danh."""
    return service.admin_custom_dose_report(conn)
