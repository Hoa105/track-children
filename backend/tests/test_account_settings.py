from datetime import datetime, timezone

from types import SimpleNamespace

import pytest

from app.features.auth import account_service
from app.features.auth.schemas import PasswordChange, ProfileUpdate


def test_profile_update_normalizes_display_name():
    data = ProfileUpdate(displayName="  Nguyễn   An  ", defaultRelationship="mother")
    assert data.displayName == "Nguyễn An"


def test_password_change_rejects_same_password():
    with pytest.raises(ValueError):
        PasswordChange(currentPassword="same-pass", newPassword="same-pass")


class FakeDb:
    def __init__(self, user, updated=None):
        self.user = user
        self.updated = updated or user
        self.calls = []

    def execute(self, sql, params=()):
        self.calls.append((sql, params))
        if sql.lstrip().startswith("SELECT * FROM account.users"):
            return self
        if sql.lstrip().startswith("UPDATE account.users"):
            return self
        return self

    def fetchone(self):
        return self.updated if len(self.calls) > 1 else self.user


def _user():
    return {
        "id": "00000000-0000-0000-0000-000000000001",
        "display_name": "Cũ",
        "default_relationship": "mother",
        "email": "user@example.com",
        "phone": None,
        "status": "active",
        "email_verified_at": None,
        "phone_verified_at": None,
        "password_hash": "old-hash",
    }


def test_update_profile_writes_new_profile(monkeypatch):
    user = _user()
    db = FakeDb(user, {**user, "display_name": "Mới", "default_relationship": "father"})
    monkeypatch.setattr(account_service, "current_user", lambda request, db: user)
    result = account_service.update_profile(
        db,
        object(),
        ProfileUpdate(displayName="Mới", defaultRelationship="father"),
    )
    assert result["displayName"] == "Mới"
    assert result["defaultRelationship"] == "father"
    assert any("UPDATE account.users" in sql for sql, _ in db.calls)


def test_change_password_updates_hash_and_revokes_sessions(monkeypatch):
    user = _user()
    db = FakeDb(user)
    monkeypatch.setattr(account_service, "current_user", lambda request, db: user)
    monkeypatch.setattr(account_service.sec, "verify_password", lambda password, hashed: password == "old")
    monkeypatch.setattr(account_service.sec, "password_hasher", SimpleNamespace(hash=lambda password: "new-hash"))
    monkeypatch.setattr(account_service.sec, "now", lambda: datetime.now(timezone.utc))
    result = account_service.change_password(
        db,
        object(),
        PasswordChange(currentPassword="old", newPassword="new-password"),
    )
    assert result is None
    assert any("SET password_hash" in sql for sql, _ in db.calls)
    assert any("account.user_sessions" in sql for sql, _ in db.calls)


@pytest.mark.parametrize("hashed", ["old-hash", None])
def test_wrong_password_does_not_write_or_revoke(monkeypatch, hashed):
    user = {**_user(), "password_hash": hashed}
    db = FakeDb(user)
    monkeypatch.setattr(account_service, "current_user", lambda request, db: user)
    monkeypatch.setattr(account_service.sec, "verify_password", lambda *args: False)
    result = account_service.change_password(
        db, object(), PasswordChange(currentPassword="wrong", newPassword="new-password")
    )
    assert result.code == "INVALID_CREDENTIALS"
    assert not any(sql.lstrip().startswith("UPDATE") for sql, _ in db.calls)
