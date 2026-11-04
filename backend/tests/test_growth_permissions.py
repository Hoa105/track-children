"""Regression tests for shared-child growth access levels."""

import pytest

from app.features.growth import repository
from app.features.growth.errors import GrowthError


class _Result:
    def __init__(self, row):
        self._row = row

    def fetchone(self):
        return self._row


class _Database:
    def __init__(self, access: str):
        self.access = access
        self.queries = []

    def execute(self, query, parameters):
        self.queries.append((query, parameters))
        return _Result({"id": "child-1", "growth_access": self.access})


def test_growth_none_cannot_view_shared_child():
    db = _Database("none")

    with pytest.raises(GrowthError) as error:
        repository.child(db, "child-1", "caregiver-1")

    assert error.value.status_code == 404
    assert error.value.code == "RESOURCE_NOT_FOUND"
    assert "p.data_scope='growth'" in db.queries[0][0]


def test_growth_view_can_read_but_cannot_edit_shared_child():
    db = _Database("view")

    profile = repository.child(db, "child-1", "caregiver-1")
    assert profile["growth_access"] == "view"

    with pytest.raises(GrowthError) as error:
        repository.child(db, "child-1", "caregiver-1", edit=True)

    assert error.value.status_code == 403
    assert error.value.code == "UNAUTHORIZED_CAREGIVER"


def test_growth_edit_can_read_and_write_shared_child():
    db = _Database("edit")

    profile = repository.child(
        db, "child-1", "caregiver-1", edit=True, lock=True,
    )

    assert profile["growth_access"] == "edit"
    assert "FOR UPDATE OF c" in db.queries[0][0]
