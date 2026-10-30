"""Growth v1 contract against a dedicated PostgreSQL database and installed R."""

from datetime import date
import json
import os
from pathlib import Path
from uuid import uuid4

from fastapi.testclient import TestClient
import psycopg
import pytest
from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

from app.main import app
from app.core.config import settings
from app.features.auth.dependencies import current_user_id
from app.features.growth import service, anthro_client, evaluation

ROOT = Path(__file__).resolve().parents[2]
SPEC = json.loads(
    (ROOT / "docs/api/mobile-growth.openapi.json").read_text(encoding="utf-8")
)
REGISTRY = Registry().with_resource(
    "urn:growth", Resource(contents=SPEC, specification=DRAFT202012)
)


def valid(schema, value):
    Draft202012Validator(
        {"$ref": "urn:growth#/components/schemas/" + schema},
        registry=REGISTRY,
        format_checker=FormatChecker(),
    ).validate(value)


@pytest.fixture(scope="module")
def database():
    url = os.environ.get("GROWTH_TEST_DATABASE_URL")
    if not url:
        pytest.skip("GROWTH_TEST_DATABASE_URL required for real PostgreSQL tests")
    assert psycopg.conninfo.conninfo_to_dict(url)["dbname"].endswith("_growth_test")
    with psycopg.connect(url, autocommit=True) as db:
        db.execute(
            "CREATE TABLE IF NOT EXISTS public.schema_migrations(version text PRIMARY KEY)"
        )
        for path in sorted((ROOT / "backend/migrations").glob("*.sql")):
            if not db.execute(
                "SELECT 1 FROM public.schema_migrations WHERE version=%s", (path.stem,)
            ).fetchone():
                with db.transaction():
                    db.execute(path.read_text(encoding="utf-8"), prepare=False)
                    db.execute(
                        "INSERT INTO public.schema_migrations VALUES (%s)", (path.stem,)
                    )
    return url


@pytest.fixture
def env(database, monkeypatch):
    monkeypatch.setattr(settings, "database_url", database)
    monkeypatch.setattr(service, "today", lambda: date(2026, 10, 29))
    owner, viewer, child = uuid4(), uuid4(), uuid4()
    with psycopg.connect(database) as db:
        for uid in (owner, viewer):
            db.execute(
                "INSERT INTO account.users(id,display_name,email,password_hash,status) VALUES (%s,'Growth Test',%s,'test','active')",
                (uid, str(uid) + "@example.test"),
            )
        db.execute(
            "INSERT INTO child.children(id,owner_user_id,full_name,date_of_birth,gender) VALUES (%s,%s,'Growth Test','2025-01-01','female')",
            (child, owner),
        )
        member = uuid4()
        db.execute(
            "INSERT INTO child.child_members(id,child_id,user_id,status) VALUES (%s,%s,%s,'active')",
            (member, child, viewer),
        )
        db.execute(
            "INSERT INTO child.child_member_permissions(member_id,data_scope,access_level) VALUES (%s,'growth','view')",
            (member,),
        )
    app.dependency_overrides[current_user_id] = lambda: owner
    with TestClient(app) as client:
        yield client, f"/api/v1/children/{child}/growth", database, child, viewer
    app.dependency_overrides.pop(current_user_id, None)


def test_contract_crud_and_real_anthro(env):
    client, base, url, child, viewer = env
    empty = client.get(base).json()
    valid("OverviewResponse", empty)
    assert all(c["latest"] is None for c in empty["cards"])
    response = client.put(
        base + "/days/2026-01-01",
        json={
            "weightKg": 9.5,
            "height": {"value": 75, "measurePosition": "lying"},
            "headCircumferenceCm": 46,
        },
    )
    assert response.status_code == 200, response.text
    data = response.json()
    valid("SaveDayResponse", data)
    scores = {a["indicator"]: a for a in data["day"]["assessments"]}
    assert (
        scores["wfa"]["zScore"] == 0.49
        and scores["lhfa"]["zScore"] == 0.39
        and scores["hcfa"]["zScore"] == 0.81
    )
    assert scores["bmifa"]["zScore"] == 0.36 and scores["wfl"]["zScore"] == 0.42
    ids = {m["metric"]: m["id"] for m in data["day"]["measurements"]}
    again = client.put(base + "/days/2026-01-01", json={"weightKg": 9.5}).json()
    assert again["changedMetrics"] == []
    assert {m["metric"]: m["id"] for m in again["day"]["measurements"]} == ids
    for metric in ("weight", "height", "head_circumference", "bmi"):
        response = client.get(base + "/metrics/" + metric)
        assert response.status_code == 200, response.text
        valid("MetricDetailResponse", response.json())
    assert client.delete(base + "/measurements/" + ids["height"]).status_code == 204
    assert client.delete(base + "/measurements/" + ids["height"]).status_code == 204
    day = client.get(base + "/days/2026-01-01").json()
    valid("DayResponse", day)
    assert day["bmi"] is None
    assert (
        next(a for a in day["assessments"] if a["indicator"] == "bmifa")["reason"]
        == "MISSING_PAIRED_MEASUREMENT"
    )
    with psycopg.connect(url) as db:
        assert (
            db.execute(
                "SELECT count(*) FROM growth.measurements WHERE child_id=%s AND deleted_at IS NULL",
                (child,),
            ).fetchone()[0]
            == 2
        )


def test_permissions_and_errors(env):
    client, base, _, _, viewer = env
    for body in (
        {},
        {"weightKg": None},
        {"weightKg": True},
        {"height": {"value": 75}},
        {"weightKg": -1},
    ):
        r = client.put(base + "/days/2026-01-01", json=body)
        assert r.status_code == 422, r.text
        valid("ErrorResponse", r.json())
    assert (
        client.put(base + "/days/2024-12-31", json={"weightKg": 9}).status_code == 422
    )
    app.dependency_overrides[current_user_id] = lambda: viewer
    r = client.get(base)
    assert r.status_code == 200
    assert r.json()["child"]["growthAccess"] == "view"
    assert (
        client.put(base + "/days/2026-01-01", json={"weightKg": 9}).status_code == 403
    )
    app.dependency_overrides[current_user_id] = lambda: uuid4()
    assert client.get(base).status_code == 404


def test_save_survives_engine_failure_and_velocity(env, monkeypatch):
    client, base, _, _, _ = env

    def fail(*args, **kwargs):
        raise anthro_client.EngineUnavailable("R_TIMEOUT")

    monkeypatch.setattr(anthro_client, "calculate", fail)
    for day, value in [("2026-08-01", 9), ("2026-08-31", 9.3)]:
        r = client.put(base + "/days/" + day, json={"weightKg": value})
        assert r.status_code == 200, r.text
        valid("SaveDayResponse", r.json())
        assert (
            next(a for a in r.json()["day"]["assessments"] if a["indicator"] == "wfa")[
                "reason"
            ]
            == "R_TIMEOUT"
        )
    for query in ("", "?mode=who&intervalMonths=2"):
        response = client.get(base + "/metrics/weight/velocity" + query)
        assert response.status_code == 200, response.text
        data = response.json()
        valid("VelocityResponse", data)
        assert data["actualIntervals"][-1]["deltaValue"] == pytest.approx(300)
        assert data["actualIntervals"][-1]["ratePerMonth"] == pytest.approx(304.375)
    assert client.get(base + "/metrics/bmi/velocity").status_code == 422


def test_under9_position_blocks_only_height_indices(env):
    client, base, _, _, _ = env
    r = client.put(
        base + "/days/2025-04-11",
        json={
            "weightKg": 6,
            "height": {"value": 60, "measurePosition": "standing"},
            "headCircumferenceCm": 40,
        },
    )
    assert r.status_code == 200, r.text
    data = r.json()
    valid("SaveDayResponse", data)
    assessments = {a["indicator"]: a for a in data["day"]["assessments"]}
    assert assessments["lhfa"]["reason"] == "INVALID_MEASURE_POSITION"
    assert assessments["bmifa"]["zScore"] is None
    assert assessments["wfa"]["status"] == "READY"


def test_cache_hit_and_late_publish_race(env, monkeypatch):
    client, base, url, child, _ = env
    r = client.put(base + "/days/2026-01-01", json={"weightKg": 9.5})
    assert r.status_code == 200
    assert (
        next(a for a in r.json()["day"]["assessments"] if a["indicator"] == "wfa")[
            "classificationCode"
        ]
        == "WITHIN_RANGE"
    )
    real = anthro_client.calculate
    calls = []

    def spy(*args, **kwargs):
        calls.append(1)
        return real(*args, **kwargs)

    monkeypatch.setattr(anthro_client, "calculate", spy)
    evaluation.MEMO.clear()
    assert client.get(base).status_code == 200
    assert calls == [], "A persistent valid cache hit must not spawn R"
    response = client.put(
        base + "/days/2026-01-01", json={"weightKg": 9.5, "note": "note-only change"}
    )
    assert response.status_code == 200
    assert calls == [], "Notes must not invalidate the numeric cache"
    with psycopg.connect(url) as db:
        db.execute("DELETE FROM growth.evaluations WHERE child_id=%s", (child,))

    def race(*args, **kwargs):
        result = real(*args, **kwargs)
        if not calls:
            with psycopg.connect(url) as db:
                db.execute(
                    "SELECT id FROM child.children WHERE id=%s FOR UPDATE", (child,)
                )
                db.execute(
                    "UPDATE growth.measurements SET value=9.6 WHERE child_id=%s AND metric='weight' AND deleted_at IS NULL",
                    (child,),
                )
        calls.append(1)
        return result

    monkeypatch.setattr(anthro_client, "calculate", race)
    evaluation.MEMO.clear()
    response = client.get(base)
    assert response.status_code == 200, response.text
    assert response.json()["cards"][0]["latest"]["value"] == 9.6
    assert (
        len(calls) == 2
    ), "Stale computation must be discarded and retried against new input"


def test_who_interval_gains_match_verified_sources(env):
    client, base, _, _, _ = env
    for day, weight, height in [("2025-01-01", 3.2, 49), ("2025-03-01", 5.1, 56.9)]:
        assert (
            client.put(
                base + "/days/" + day,
                json={
                    "weightKg": weight,
                    "height": {"value": height, "measurePosition": "lying"},
                },
            ).status_code
            == 200
        )
    for metric in ("weight", "height"):
        r = client.get(
            base + "/metrics/" + metric + "/velocity?mode=who&intervalMonths=2"
        )
        assert r.status_code == 200, r.text
        value = r.json()
        valid("VelocityResponse", value)
        assert value["referenceStatus"] == "REFERENCE_MATCHED"
        interval = value["whoIntervals"][0]
        assert interval["zScoreStatus"] == "READY"
        assert interval["matchedReference"]["sdValues"][3]["value"] == (
            1897 if metric == "weight" else 7.9
        )
        assert abs(interval["zScore"]) < 0.02


def test_exported_attained_tables_match_public_engine():
    from app.features.growth import reference

    data, _ = reference.datasets()["attained"]
    requests = []
    expected = []
    for indicator, rows in data["tables"].items():
        for sex in (1, 2):
            chosen = [
                r
                for r in rows
                if r["sex"] == sex
                and (
                    r.get("age") == 365
                    if "age" in r
                    else r.get("length", r.get("height")) == 80
                )
            ][0]
            for sd in (-2, 0, 2):
                value = reference.quantile(chosen, sd)
                payload = {
                    "row_id": str(len(requests)),
                    "sex": "m" if sex == 1 else "f",
                    "age_days": 365 if indicator != "wfh" else 900,
                }
                if indicator in ("wfa", "wfl", "wfh"):
                    payload["weight_kg"] = value
                if indicator in ("lhfa", "hcfa"):
                    payload["lenhei_cm" if indicator == "lhfa" else "headc_cm"] = value
                if indicator == "lhfa":
                    payload["measure"] = "l"
                if indicator == "bmifa":
                    payload.update(lenhei_cm=75, measure="l", weight_kg=value * 0.75**2)
                if indicator in ("wfl", "wfh"):
                    payload.update(
                        lenhei_cm=80, measure="l" if indicator == "wfl" else "h"
                    )
                requests.append(payload)
                expected.append((evaluation.MAPPING[indicator][1], sd))
    result = anthro_client.calculate(requests)
    for row, (column, sd) in zip(result, expected):
        assert row[column] == pytest.approx(sd, abs=0.01)


def test_database_rejects_nan_even_outside_api(env):
    _, _, url, child, _ = env
    with psycopg.connect(url) as db:
        with pytest.raises(psycopg.errors.CheckViolation):
            with db.transaction():
                db.execute(
                    "INSERT INTO growth.measurements(child_id,metric,value,measured_on,measured_at) VALUES (%s,'weight','NaN','2026-01-01','2026-01-01T00:00:00+07:00')",
                    (child,),
                )


def test_child_selection_respects_current_permissions(env):
    client, _, url, child, viewer = env
    result = client.get("/api/v1/children")
    assert result.status_code == 200
    assert result.headers["cache-control"] == "no-store"
    assert [(c["id"], c["growthAccess"]) for c in result.json()["children"]] == [
        (str(child), "edit")
    ]
    app.dependency_overrides[current_user_id] = lambda: viewer
    assert [
        (c["id"], c["growthAccess"])
        for c in client.get("/api/v1/children").json()["children"]
    ] == [(str(child), "view")]
    with psycopg.connect(url) as db:
        db.execute(
            "UPDATE child.child_member_permissions SET access_level='none' WHERE member_id IN (SELECT id FROM child.child_members WHERE child_id=%s AND user_id=%s)",
            (child, viewer),
        )
    assert (
        client.get("/api/v1/children").json()["children"][0]["growthAccess"] == "none"
    )
    with psycopg.connect(url) as db:
        db.execute(
            "UPDATE child.child_members SET status='revoked' WHERE child_id=%s AND user_id=%s",
            (child, viewer),
        )
    assert client.get("/api/v1/children").json()["children"] == []
