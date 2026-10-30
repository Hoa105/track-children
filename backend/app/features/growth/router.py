from datetime import date, timedelta
from uuid import UUID
from fastapi import APIRouter, Depends, Query, Response
from app.features.auth.dependencies import current_user_id
from . import service, velocity
from .errors import GrowthError
from .schemas import SaveDay

router = APIRouter(prefix="/api/v1/children/{childId}/growth", tags=["Mobile Growth"])


@router.get("")
def overview(
    childId: UUID,
    startOn: date | None = None,
    endBefore: date | None = None,
    user=Depends(current_user_id),
):
    return service.overview(service.read(childId, user, startOn, endBefore))


@router.get("/metrics/{metric}")
def detail(
    childId: UUID,
    metric: str,
    startOn: date | None = None,
    endBefore: date | None = None,
    selectedMeasurementId: UUID | None = None,
    weightForSizeIndicator: str | None = None,
    statureView: str = "radius5",
    user=Depends(current_user_id),
):
    if metric not in service.METRICS:
        raise GrowthError(422, "INVALID_METRIC")
    if (
        weightForSizeIndicator not in (None, "wfl", "wfh")
        or statureView not in ("radius5", "radius10", "all")
        or (metric != "weight" and (weightForSizeIndicator or statureView != "radius5"))
    ):
        raise GrowthError(422, "INVALID_VALUE")
    return service.detail(
        service.read(childId, user, startOn, endBefore, selectedMeasurementId),
        metric,
        selectedMeasurementId,
        weightForSizeIndicator,
        statureView,
    )


@router.get("/metrics/{metric}/velocity")
def get_velocity(
    childId: UUID,
    metric: str,
    startOn: date | None = None,
    endBefore: date | None = None,
    mode: str = "actual",
    intervalMonths: int | None = None,
    user=Depends(current_user_id),
):
    return velocity.build(
        service.read(childId, user, startOn, endBefore), metric, mode, intervalMonths
    )


@router.get("/days/{measuredOn}")
def get_day(childId: UUID, measuredOn: date, user=Depends(current_user_id)):
    return service.day_result(
        service.read(childId, user, measuredOn, measuredOn + timedelta(days=1)),
        measuredOn,
    )


@router.put("/days/{measuredOn}")
def put_day(
    childId: UUID, measuredOn: date, body: SaveDay, user=Depends(current_user_id)
):
    return service.save(childId, user, measuredOn, body)


@router.delete("/measurements/{measurementId}", status_code=204)
def delete(childId: UUID, measurementId: UUID, user=Depends(current_user_id)):
    service.delete(childId, user, measurementId)
    return Response(status_code=204, headers={"Cache-Control": "no-store"})
