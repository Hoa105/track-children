from datetime import date
from uuid import UUID
from fastapi import APIRouter, Depends, Response
from app.features.auth.dependencies import current_user_id
from . import service, tracking
from .errors import GrowthError
from .schemas import SaveDay, MeasurementCreate, MeasurementWrite

router = APIRouter(prefix="/api/v1/children/{childId}/growth", tags=["Mobile Growth"])


@router.get("/tracking")
def tracking_overview(childId: UUID, user=Depends(current_user_id)):
    return tracking.snapshot(childId, user)


@router.post("/measurements", status_code=201)
def create_measurement(childId: UUID, body: MeasurementCreate, user=Depends(current_user_id)):
    return tracking.write(childId, user, body)


@router.patch("/measurements/{measurementId}")
def edit_measurement(childId: UUID, measurementId: UUID, body: MeasurementWrite, user=Depends(current_user_id)):
    return tracking.write(childId, user, body, measurementId)


@router.get("/assessment/{kind}")
def parent_assessment(childId: UUID, kind: str, selectedMeasurementId: UUID | None = None, user=Depends(current_user_id)):
    if kind not in ("bmi", "head"):
        raise GrowthError(422, "INVALID_METRIC")
    return tracking.read_assessment(childId, user, kind, selectedMeasurementId)


@router.put("/days/{measuredOn}")
def put_day(
    childId: UUID, measuredOn: date, body: SaveDay, user=Depends(current_user_id)
):
    return service.save(childId, user, measuredOn, body)


@router.delete("/measurements/{measurementId}", status_code=204)
def delete(childId: UUID, measurementId: UUID, user=Depends(current_user_id)):
    service.delete(childId, user, measurementId)
    return Response(status_code=204, headers={"Cache-Control": "no-store"})
