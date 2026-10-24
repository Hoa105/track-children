"""JWT boundary regression tests without an external database."""

from contextlib import nullcontext
from datetime import timedelta
from uuid import uuid4

import jwt
import pytest
from fastapi.testclient import TestClient

from app.core import security
from app.core.config import settings
from app.core.database import get_db
from app.features.auth import dependencies, repository
from app.features.vaccination import router as vaccination
from app.main import app


@pytest.fixture
def boundary(monkeypatch):
    uid, sid, child = uuid4(), uuid4(), uuid4()
    identity = {
        "id": uid,
        "status": "active",
        "session_revoked": None,
        "session_expiry": security.now() + timedelta(hours=1),
    }
    monkeypatch.setattr(
        settings, "auth_secret", "jwt-boundary-secret-with-at-least-32-characters"
    )
    monkeypatch.setattr(settings, "dev_auth", True)
    monkeypatch.setattr(dependencies, "transaction", lambda: nullcontext(object()))
    lookups = []

    def find(db, ids):
        lookups.append(ids)
        return identity if ids == (uid, sid) else None

    monkeypatch.setattr(repository, "find_access_identity", find)
    monkeypatch.setattr(repository, "find_admin_access_identity", find)
    monkeypatch.setattr(
        repository,
        "find_admin_permission",
        lambda db, params: {"code": "content_manager"},
    )
    monkeypatch.setattr(vaccination, "require_child_access", lambda *args: None)
    monkeypatch.setattr(
        vaccination.service, "list_child_vaccinations", lambda *args: []
    )
    monkeypatch.setattr(vaccination.service, "admin_list_vaccines", lambda *args: [])
    previous = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = lambda: object()

    def headers(admin=False, **updates):
        claims = {
            "sub": str(uid),
            "sid": str(sid),
            "iat": security.now(),
            "exp": security.now() + timedelta(minutes=15),
            "iss": settings.auth_issuer,
            "aud": settings.auth_admin_audience if admin else settings.auth_audience,
        }
        claims.update(updates)
        return {
            "Authorization": "Bearer "
            + jwt.encode(claims, settings.auth_secret, algorithm="HS256")
        }

    yield TestClient(app), f"/children/{child}/vaccinations", headers, identity, lookups
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous)


def test_mobile_jwt_works_without_dev_auth(boundary, monkeypatch):
    client, url, headers, _, lookups = boundary
    monkeypatch.setattr(settings, "dev_auth", False)
    assert client.get(url, headers=headers()).status_code == 200
    assert len(lookups) == 1


@pytest.mark.parametrize(
    "headers",
    [
        {},
        {"X-User-Id": str(uuid4())},
        {"X-Admin-Role": "super_admin"},
        {"Authorization": "Bearer invalid"},
    ],
)
def test_legacy_headers_cannot_authenticate(boundary, headers):
    client, url, _, _, lookups = boundary
    for path in (url, "/admin/vaccines"):
        response = client.get(path, headers=headers)
        assert response.status_code == 401
        assert response.headers["WWW-Authenticate"] == "Bearer"
    assert lookups == []


@pytest.mark.parametrize(
    "updates",
    [
        {"exp": security.now() - timedelta(seconds=1)},
        {"aud": "other"},
        {"iss": "other"},
        {"sid": str(uuid4())},
        {"sub": "invalid"},
    ],
)
def test_invalid_or_unbound_jwt(boundary, updates):
    client, url, headers, _, _ = boundary
    assert client.get(url, headers=headers(**updates)).status_code == 401


@pytest.mark.parametrize("admin", [False, True])
@pytest.mark.parametrize(
    "field,value,status",
    [
        ("session_revoked", security.now(), 401),
        ("session_expiry", security.now() - timedelta(seconds=1), 401),
        ("status", "locked", 403),
    ],
)
def test_live_session_and_account_state(boundary, admin, field, value, status):
    client, url, headers, identity, _ = boundary
    identity[field] = value
    assert (
        client.get(
            "/admin/vaccines" if admin else url, headers=headers(admin)
        ).status_code
        == status
    )


def test_admin_requires_admin_audience_and_database_permission(boundary, monkeypatch):
    client, url, headers, _, _ = boundary
    assert client.get("/admin/vaccines", headers=headers()).status_code == 401
    assert client.get(url, headers=headers(True)).status_code == 401
    assert client.get("/admin/vaccines", headers=headers(True)).status_code == 200
    monkeypatch.setattr(repository, "find_admin_permission", lambda *args: None)
    spoofed = {**headers(True), "X-Admin-Role": "super_admin"}
    assert client.get("/admin/vaccines", headers=spoofed).status_code == 403


def test_dev_profile_requires_jwt_and_matching_parent(boundary, monkeypatch):
    client, _, headers, _, _ = boundary
    monkeypatch.setattr(settings, "app_env", "local")
    body = {
        "parent": {
            "id": str(uuid4()),
            "email": "parent@example.test",
            "fullName": "Parent",
        },
        "child": {
            "id": str(uuid4()),
            "fullName": "Child",
            "dateOfBirth": "2026-01-01",
            "gender": "female",
        },
    }
    assert client.put("/dev/profiles", json=body).status_code == 401
    assert client.put("/dev/profiles", json=body, headers=headers()).status_code == 403
    monkeypatch.setattr(settings, "app_env", "production")
    assert client.put("/dev/profiles", json=body, headers=headers()).status_code == 404
