"""Authenticated API for the mobile teething screen."""

from uuid import UUID
from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query, Response, status
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.features.teething import service
from app.features.teething.schemas import ToothRecord, ToothRecords, ToothUpsert
from app.shared.access import require_child_access

router = APIRouter(prefix="/api/v1", tags=["mobile: teething"])
ToothCode = Annotated[str, Path(pattern=r"^[5-8][1-5]$")]


@router.get("/children/{child_id}/teeth", response_model=ToothRecords)
def get_teeth(
    child_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "view")
    return {"records": service.list_records(conn, child_id)}


@router.put("/children/{child_id}/teeth/{tooth_code}", response_model=ToothRecord)
def put_tooth(
    child_id: UUID,
    tooth_code: ToothCode,
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
        expected_version=body.expected_version,
        note=body.note,
        note_provided="note" in body.model_fields_set,
    )


@router.delete(
    "/children/{child_id}/teeth/{tooth_code}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_tooth(
    child_id: UUID,
    tooth_code: ToothCode,
    expected_version: Annotated[UUID | None, Query(alias="expectedVersion")] = None,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    require_child_access(conn, child_id, user_id, service.SCOPE, "edit")
    service.delete_record(conn, child_id, user_id, tooth_code, expected_version)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
