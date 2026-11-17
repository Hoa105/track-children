"""PostgreSQL auth operations. Lock order: user -> challenge/OTP/session.

Expected failures are returned, not raised, so attempts, throttles and revocations
commit before a route sends an error response.
"""

import secrets
import sqlite3
from datetime import timedelta

from fastapi import Request

from app.features.auth.dependencies import current_user
from app.features.auth.errors import AuthFailure, failure
from app.features.auth import repository
from app.features.auth import rate_limit
from app.features.auth.registration import register, verify, resend

from app.core import security as sec
from app.core.config import settings


def quota(db, key, limit, seconds, code="RATE_LIMITED"):
    try:
        retry = rate_limit.consume(key, limit, seconds)
    except (sqlite3.Error, OSError):
        return failure(503, "RATE_LIMIT_UNAVAILABLE")
    if retry:
        return failure(429, code, retry=retry)


def legal(db):
    from app.features.auth.registration import legal as documents
    return documents()


def public_user(u):
    return {"id": u["id"], "email": u["email"], "phone": u["phone"],
            "displayName": u["display_name"], "fullName": u["display_name"],
            "defaultRelationship": u["default_relationship"], "relationship": u["default_relationship"],
            "status": u["status"], "emailVerifiedAt": u["email_verified_at"],
            "phoneVerifiedAt": u["phone_verified_at"]}



def new_session(db, user, device, remember, ip=None):
    t = sec.now()
    raw = secrets.token_urlsafe(48)
    row = repository.create_session(
        db,
        (
            user["id"],
            sec.secret_hash(raw),
            device.platform,
            t + timedelta(days=30 if remember else 1),
            t,
            remember,
        ),
    )
    repository.record_successful_login(db, (t, user["id"]))
    return token_result(row, raw)


def token_result(session, raw):
    t = sec.now()
    exp = min(session["expires_at"], t + timedelta(minutes=15))
    return {
        "tokenType": "Bearer",
        "accessToken": sec.access_token(session["user_id"], session["id"], exp),
        "expiresIn": max(1, int((exp - t).total_seconds())),
        "refreshToken": raw,
        "sessionExpiresAt": session["expires_at"],
    }


def revoke(db, sid):
    repository.revoke_session(db, (sec.now(), sid))
    repository.disable_session_devices(db, (sid,))


# Password login uses the consolidated schema and a shared operational limiter.
def login(db, data, ip):
    err = quota(db, "login-ip:" + ip, 30, 60)
    if err:
        return err, None
    err = quota(
        db,
        "login-id:" + sec.secret_hash(data.identifier),
        5,
        900,
        "LOGIN_TEMPORARILY_LOCKED",
    )
    u = (
        repository.lock_user_by_email(db, (str(data.email),))
        if data.email is not None
        else repository.lock_user_by_phone(db, (data.phone,))
    )
    t = sec.now()
    if err:
        return err, None
    if u and u["locked_until"] and u["locked_until"] > t:
        return (
            failure(
                429,
                "LOGIN_TEMPORARILY_LOCKED",
                retry=int((u["locked_until"] - t).total_seconds()) + 1,
            ),
            None,
        )
    valid = sec.verify_password(
        data.password, u["password_hash"] if u else sec.dummy_hash
    )
    if not valid:
        if u:
            attempts = (
                u["failed_login_attempts"]
                if not u["locked_until"] or u["locked_until"] > t
                else 0
            ) + 1
            repository.record_failed_login(
                db,
                (
                    attempts,
                    t + timedelta(minutes=15) if attempts >= 5 else None,
                    u["id"],
                ),
            )
        return failure(401, "INVALID_CREDENTIALS"), None
    # Reset identifier throttle on successful password verification, but never SMS quota.
    try:
        rate_limit.clear("login-id:" + sec.secret_hash(data.identifier))
    except (sqlite3.Error, OSError):
        return failure(503, "RATE_LIMIT_UNAVAILABLE"), None
    repository.reset_login_attempts(db, (u["id"],))
    if (
        u["status"] == "pending"
        and settings.auth_skip_otp
        and settings.app_env == "local"
    ):
        u = repository.activate_user(db, (u["id"],))
    if u["status"] == "pending":
        from app.features.auth.registration import issue
        result, delivery = issue(db, u)
        if isinstance(result, AuthFailure):
            return result, None
        return failure(403, "VERIFICATION_REQUIRED", details={"registration": result}), delivery
    if u["status"] == "locked":
        return failure(403, "ACCOUNT_LOCKED"), None
    cancelled = False
    if u["status"] == "pending_deletion":
        r = repository.lock_deletion_request(db, (u["id"],))
        if (
            not r
            or r["status"] != "pending"
            or not r["scheduled_at"]
            or r["scheduled_at"] <= t
        ):
            return failure(403, "ACCOUNT_DELETION_IN_PROGRESS"), None
        repository.cancel_deletion_request(db, (t, r["id"]))
        u = repository.activate_user(db, (u["id"],))
        cancelled = True
    if u["status"] != "active":
        return failure(403, "ACCOUNT_UNAVAILABLE"), None
    return {
        **new_session(db, u, data.device, data.rememberMe, ip),
        "user": public_user(u),
        "deletionRequestCancelled": cancelled,
    }, None


def session_by_token(db, raw):
    hashed = sec.secret_hash(raw)
    found = repository.find_session_reference(db, (hashed,))
    if not found:
        return None
    u = repository.lock_user(db, (found["user_id"],))
    s = repository.lock_session(db, (found["id"],))
    return (u, s) if s else None


def refresh(db, raw):
    pair = session_by_token(db, raw)
    if not pair:
        return failure(401, "REFRESH_TOKEN_INVALID")
    u, s = pair
    if s["revoked_at"]:
        return failure(401, "SESSION_REVOKED")
    if s["expires_at"] <= sec.now():
        return failure(401, "SESSION_EXPIRED")
    if s["refresh_token_hash"] != sec.secret_hash(raw):
        revoke(db, s["id"])
        return failure(401, "REFRESH_TOKEN_REUSED")
    if u["status"] != "active":
        return failure(403, "ACCOUNT_UNAVAILABLE")
    # 009 stores one hash per session and has no replay-history table. Keep the
    # opaque refresh secret stable until its fixed session expiry or revocation.
    return token_result(s, raw)


def logout(db, raw):
    pair = session_by_token(db, raw)
    if pair:
        revoke(db, pair[1]["id"])


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
    return public_user(updated)


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
