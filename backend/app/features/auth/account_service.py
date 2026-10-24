"""Authenticated app-account profile and password operations."""

from fastapi import Request

from app.core import security as sec
from app.features.auth import service
from app.features.auth.dependencies import current_user
from app.features.auth.errors import AuthFailure, failure


def _lock_user(db, request: Request):
    user = current_user(request, db)
    if isinstance(user, AuthFailure):
        return user
    return db.execute(
        "SELECT * FROM account.users WHERE id=%s FOR UPDATE",
        (user["id"],),
    ).fetchone()


def update_profile(db, request: Request, data):
    user = _lock_user(db, request)
    if isinstance(user, AuthFailure):
        return user
    updated = db.execute(
        """UPDATE account.users
              SET display_name=%s, default_relationship=%s
            WHERE id=%s
        RETURNING *""",
        (data.displayName, data.defaultRelationship, user["id"]),
    ).fetchone()
    return service.public_user(updated)


def change_password(db, request: Request, data):
    user = _lock_user(db, request)
    if isinstance(user, AuthFailure):
        return user
    if not user["password_hash"] or not sec.verify_password(data.currentPassword, user["password_hash"]):
        return failure(401, "INVALID_CREDENTIALS")
    db.execute(
        "UPDATE account.users SET password_hash=%s WHERE id=%s",
        (sec.password_hasher.hash(data.newPassword), user["id"]),
    )
    # A password change invalidates every refresh session, including the one
    # used by this request. The client must sign in again afterwards.
    db.execute(
        """UPDATE account.user_sessions
              SET revoked_at=COALESCE(revoked_at, %s)
            WHERE user_id=%s""",
        (sec.now(), user["id"]),
    )
    return None
