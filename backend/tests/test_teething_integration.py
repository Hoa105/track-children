"""Real PostgreSQL tests. Use a dedicated database ending in _teething_test."""

import datetime as dt
import os
import re
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from uuid import uuid4

import psycopg2
from psycopg2.extras import RealDictCursor
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.features.teething import service
from app.features.teething.router import router


@pytest.fixture(scope="module")
def database():
    url = os.environ.get("TEETHING_TEST_DATABASE_URL")
    if not url:
        pytest.skip("TEETHING_TEST_DATABASE_URL is required")
    params = psycopg2.extensions.parse_dsn(url)
    assert params.get("dbname", "").endswith(
        "_teething_test"
    ), "Dedicated test database required"
    with psycopg2.connect(url) as conn, conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS public.schema_migrations (version text PRIMARY KEY)"
        )
        for path in sorted((Path(__file__).parents[1] / "migrations").glob("*.sql")):
            cur.execute(
                "SELECT 1 FROM public.schema_migrations WHERE version = %s",
                (path.stem,),
            )
            if cur.fetchone() is None:
                sql = path.read_text(encoding="utf-8-sig")
                executable = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
                if any(
                    line.strip() and not line.lstrip().startswith("--")
                    for line in executable.splitlines()
                ):
                    cur.execute(sql)
                cur.execute(
                    "INSERT INTO public.schema_migrations VALUES (%s)", (path.stem,)
                )
    return url


@pytest.fixture
def env(database):
    conn = psycopg2.connect(database, cursor_factory=RealDictCursor)
    owner, viewer, editor, outsider, child_id = [uuid4() for _ in range(5)]
    with conn, conn.cursor() as cur:
        for user in (owner, viewer, editor, outsider):
            cur.execute(
                """INSERT INTO account.users (id,email,password_hash,display_name,status)
                VALUES (%s,%s,'test','Teething test','active')""",
                (str(user), f"{user}@example.test"),
            )
        cur.execute(
            """INSERT INTO child.children (id,owner_user_id,full_name,date_of_birth,gender)
            VALUES (%s,%s,'Teething test','2026-01-01','male')""",
            (str(child_id), str(owner)),
        )
        for user, level in ((viewer, "view"), (editor, "edit")):
            member = str(uuid4())
            cur.execute(
                "INSERT INTO child.child_members (id,child_id,user_id,status) VALUES (%s,%s,%s,'active')",
                (member, str(child_id), str(user)),
            )
            cur.execute(
                "INSERT INTO child.child_member_permissions VALUES (%s,'teething',%s)",
                (member, level),
            )
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_db] = lambda: conn
    app.dependency_overrides[current_user_id] = lambda: owner
    client = TestClient(app)
    yield {
        "conn": conn,
        "app": app,
        "client": client,
        "owner": owner,
        "viewer": viewer,
        "editor": editor,
        "outsider": outsider,
        "child": {"id": child_id, "date_of_birth": dt.date(2026, 1, 1)},
        "path": f"/api/v1/children/{child_id}/teeth",
        "url": database,
    }
    conn.rollback()
    with conn, conn.cursor() as cur:
        cur.execute("DELETE FROM child.children WHERE id = %s", (str(child_id),))
        for user in (owner, viewer, editor, outsider):
            cur.execute("DELETE FROM account.users WHERE id = %s", (str(user),))
    conn.close()


def payload(version=None):
    return {
        "eruptedOn": "2026-08-12",
        "timezoneOffsetMinutes": 420,
        "expectedVersion": version,
    }


def test_crud_conflicts_and_audit(env):
    client, path = env["client"], env["path"]
    assert client.get(path).json() == {"records": []}
    created = client.put(path + "/71", json=payload())
    assert created.status_code == 200
    version = created.json()["version"]
    assert client.get(path).json()["records"][0] == created.json()
    assert client.put(path + "/71", json=payload()).status_code == 409
    updated = client.put(path + "/71", json=payload(version))
    assert updated.status_code == 200
    assert updated.json()["version"] != version
    assert client.put(path + "/71", json=payload(version)).status_code == 409
    assert client.delete(path + "/71").status_code == 409
    assert client.delete(path + f"/71?expectedVersion={version}").status_code == 409
    query = f"?expectedVersion={updated.json()['version']}"
    assert client.delete(path + "/71" + query).status_code == 204
    assert client.delete(path + "/71" + query).status_code == 204
    assert client.put(path + "/71", json=payload(version)).status_code == 409
    recreated = client.put(path + "/71", json=payload()).json()
    assert recreated["version"] not in (version, updated.json()["version"])
    assert client.delete(path + "/71" + query).status_code == 409
    with env["conn"].cursor() as cur:
        cur.execute(
            "SELECT action FROM child.child_data_change_logs WHERE child_id=%s ORDER BY created_at,id",
            (str(env["child"]["id"]),),
        )
        actions = [row["action"] for row in cur.fetchall()]
    assert sorted(actions) == ["create", "create", "delete", "update"]


@pytest.mark.parametrize("empty_note", [None, "", " "])
def test_note_create_preserve_edit_and_clear(env, empty_note):
    client, path = env["client"], env["path"] + "/71"
    created = client.put(path, json=payload() | {"note": "  Răng đầu tiên  "})
    assert created.status_code == 200
    assert created.json()["note"] == "Răng đầu tiên"
    preserved = client.put(path, json=payload(created.json()["version"]))
    assert preserved.json()["note"] == "Răng đầu tiên"
    updated = client.put(
        path, json=payload(preserved.json()["version"]) | {"note": "Ghi chú mới"}
    )
    assert updated.status_code == 200
    assert client.get(env["path"]).json()["records"][0]["note"] == "Ghi chú mới"
    # A separate connection verifies the write committed beyond the API session.
    with psycopg2.connect(env["url"]) as db, db.cursor() as cur:
        cur.execute(
            "SELECT note FROM health.child_teeth WHERE child_id = %s AND tooth_code = '71'",
            (str(env["child"]["id"]),),
        )
        assert cur.fetchone()[0] == "Ghi chú mới"
    assert (
        client.put(
            path, json=payload(created.json()["version"]) | {"note": "Cũ"}
        ).status_code
        == 409
    )
    assert (
        client.put(
            path, json=payload(updated.json()["version"]) | {"note": "x" * 1001}
        ).status_code
        == 422
    )
    cleared = client.put(
        path, json=payload(updated.json()["version"]) | {"note": empty_note}
    )
    assert cleared.status_code == 200
    assert cleared.json()["note"] is None


@pytest.mark.parametrize(
    "role,status", [("viewer", 403), ("outsider", 404), ("editor", 200)]
)
def test_access(env, role, status):
    env["app"].dependency_overrides[current_user_id] = lambda: env[role]
    assert (
        env["client"].put(
            env["path"] + "/71", json=payload() | {"note": "Ghi chú"}
        ).status_code == status
    )
    assert env["client"].get(env["path"]).status_code == (
        404 if role == "outsider" else 200
    )
    assert env["client"].delete(env["path"] + "/72").status_code == (
        204 if role == "editor" else status
    )


@pytest.mark.parametrize("method", ["put", "delete"])
def test_invalid_path_code(env, method):
    kwargs = {"json": payload()} if method == "put" else {}
    assert (
        getattr(env["client"], method)(env["path"] + "/11", **kwargs).status_code == 422
    )


def test_audit_failure_rolls_back_write(env, monkeypatch):
    def fail(*args, **kwargs):
        raise RuntimeError("audit unavailable")

    monkeypatch.setattr(service, "_audit", fail)
    with pytest.raises(RuntimeError):
        service.upsert_record(
            env["conn"], env["child"], env["owner"], "71", dt.date(2026, 8, 12)
        )
    assert service.list_records(env["conn"], env["child"]["id"]) == []


def test_note_update_audit_failure_preserves_saved_note(env, monkeypatch):
    path = env["path"] + "/71"
    note = "Răng đầu tiên\nBé vui 🦷"
    created = env["client"].put(path, json=payload() | {"note": note})
    assert created.status_code == 200

    def fail(*args, **kwargs):
        raise RuntimeError("audit unavailable")

    monkeypatch.setattr(service, "_audit", fail)
    with pytest.raises(RuntimeError):
        env["client"].put(
            path, json=payload(created.json()["version"]) | {"note": "Thay đổi"}
        )
    saved = env["client"].get(env["path"]).json()["records"][0]
    assert saved["note"] == note
    assert saved["version"] == created.json()["version"]


def test_simultaneous_update_has_one_winner(env):
    from threading import Barrier

    row = service.upsert_record(
        env["conn"], env["child"], env["owner"], "71", dt.date(2026, 8, 12)
    )
    barrier = Barrier(2)

    def save(day):
        conn = psycopg2.connect(env["url"], cursor_factory=RealDictCursor)
        try:
            barrier.wait(timeout=10)
            service.upsert_record(
                conn,
                env["child"],
                env["owner"],
                "71",
                day,
                expected_version=row["version"],
            )
            return 200
        except HTTPException as error:
            return error.status_code
        finally:
            conn.close()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(save, [dt.date(2026, 8, 13), dt.date(2026, 8, 14)]))
    assert sorted(results) == [200, 409]
