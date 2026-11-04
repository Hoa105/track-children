import datetime as dt
from uuid import uuid4

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

from app.features.teething.schema import ToothRecord, ToothUpsert
from app.features.teething.router import router
from app.features.teething.service import upsert_record, user_today


def test_teething_routes_are_in_runtime_openapi():
    paths = {route.path: route.methods for route in router.routes}
    collection = "/api/v1/children/{child_id}/teeth"
    item = "/api/v1/children/{child_id}/teeth/{tooth_code}"
    assert paths[collection] == {"GET"}
    assert paths[item] in ({"PUT"}, {"DELETE"})
    assert {
        next(iter(route.methods)) for route in router.routes if route.path == item
    } == {
        "PUT",
        "DELETE",
    }


def test_primary_fdi_contract_and_date_validation():
    assert (
        ToothRecord(toothCode="71", eruptedOn="2026-08-12", version=uuid4()).tooth_code
        == "71"
    )
    with pytest.raises(ValidationError):
        ToothRecord(toothCode="11", eruptedOn="2026-08-12", version=uuid4())

    child = {
        "id": "00000000-0000-4000-8000-000000000101",
        "date_of_birth": dt.date(2026, 1, 1),
    }
    with pytest.raises(HTTPException) as error:
        upsert_record(
            None,
            child,
            "00000000-0000-4000-8000-000000000001",
            "71",
            dt.date(2025, 12, 31),
            today=dt.date(2026, 11, 4),
        )
    assert error.value.status_code == 422


def test_user_system_timezone_defines_today():
    utc = dt.datetime(2026, 11, 3, 18, 30, tzinfo=dt.timezone.utc)
    assert user_today(0, utc) == dt.date(2026, 11, 3)
    assert user_today(420, utc) == dt.date(2026, 11, 4)
    assert (
        ToothUpsert(
            eruptedOn="2026-11-04", timezoneOffsetMinutes=420, expectedVersion=None
        ).timezone_offset_minutes
        == 420
    )
    with pytest.raises(ValidationError):
        ToothUpsert(
            eruptedOn="2026-11-04", timezoneOffsetMinutes=900, expectedVersion=None
        )


@pytest.mark.parametrize(
    "offset, expected", [(-720, "2026-11-03"), (840, "2026-11-05"), (345, "2026-11-04")]
)
def test_timezone_boundaries(offset, expected):
    now = dt.datetime(2026, 11, 4, 10, 30, tzinfo=dt.timezone.utc)
    assert user_today(offset, now).isoformat() == expected


@pytest.mark.parametrize(
    "changes",
    [
        {"unexpected": True},
        {"timezoneOffsetMinutes": True},
        {"timezoneOffsetMinutes": "420"},
        {"timezoneOffsetMinutes": -721},
        {"expectedVersion": "bad-version"},
        {"eruptedOn": "2026-02-30"},
    ],
)
def test_reject_invalid_payload(changes):
    body = {
        "eruptedOn": "2026-11-04",
        "timezoneOffsetMinutes": 420,
        "expectedVersion": None,
    }
    with pytest.raises(ValidationError):
        ToothUpsert(**(body | changes))


def test_expected_version_is_required():
    with pytest.raises(ValidationError):
        ToothUpsert(eruptedOn="2026-11-04", timezoneOffsetMinutes=420)


def test_note_validation_and_normalization():
    body = {
        "eruptedOn": "2026-11-04",
        "timezoneOffsetMinutes": 420,
        "expectedVersion": None,
    }
    assert ToothUpsert(**body, note="  Răng đầu tiên  ").note == "Răng đầu tiên"
    assert ToothUpsert(**body, note="  ").note is None
    with pytest.raises(ValidationError):
        ToothUpsert(**body, note="x" * 1001)
    with pytest.raises(ValidationError):
        ToothUpsert(**body, note="Ghi chú\x00không hợp lệ")


def test_future_date_rejected_before_database_access():
    with pytest.raises(HTTPException) as error:
        upsert_record(
            None,
            {"date_of_birth": dt.date(2026, 1, 1)},
            uuid4(),
            "71",
            dt.date(2026, 11, 5),
            today=dt.date(2026, 11, 4),
        )
    assert error.value.status_code == 422


@pytest.mark.parametrize("code", ["11", "50", "86", "71x", "", "７１"])
def test_invalid_code_rejected_by_service(code):
    from app.features.teething.service import delete_record

    with pytest.raises(HTTPException) as error:
        delete_record(None, uuid4(), uuid4(), code)
    assert error.value.status_code == 422
