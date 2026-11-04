"""Authenticated API for the mobile teething screen."""

from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.features.teething import service
from app.features.teething.schema import ToothRecord, ToothRecords, ToothUpsert
from app.shared.access import require_child_access

router = APIRouter(prefix="/api/v1", tags=["mobile: teething"])


@router.get("/children/{child_id}/teeth", response_model=ToothRecords)
def get_teeth(
    child_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return {"records": service.list_records(conn, child_id)}


@router.put(
    "/children/{child_id}/teeth/{tooth_code}", response_model=ToothRecord
)
def put_tooth(
    child_id: UUID,
    tooth_code: str,
    body: ToothUpsert,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    child = require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    return service.upsert_record(
        conn,
        child,
        user_id,
        tooth_code,
        body.erupted_on,
        body.timezone_offset_minutes,
    )


@router.delete(
    "/children/{child_id}/teeth/{tooth_code}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_tooth(
    child_id: UUID,
    tooth_code: str,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    service.delete_record(conn, child_id, user_id, tooth_code)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
