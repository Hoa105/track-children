"""PostgreSQL auth operations. Lock order: user -> challenge/OTP/session.

Expected failures are returned, not raised, so attempts, throttles and revocations
commit before a route sends an error response.
"""

import hmac
import secrets
from datetime import timedelta
from uuid import uuid4

from app.features.auth.errors import AuthFailure, failure
from app.features.auth import repository

from app.core import security as sec
from app.core.config import settings


def quota(db, key, limit, seconds, code="RATE_LIMITED"):
    t = sec.now()
    row = repository.increment_rate_limit(
        db, (key, t + timedelta(seconds=seconds), t, t)
    )
    if row["attempts"] > limit:
        return failure(429, code, retry=int((row["resets_at"] - t).total_seconds()) + 1)


def legal(db):
    rows = repository.list_effective_legal_documents(db, (sec.now(),))
    if {r["doc_type"] for r in rows} != {"terms", "privacy", "data_policy"}:
        return failure(503, "LEGAL_DOCUMENTS_UNAVAILABLE")
    return rows


def public_user(u):
    names = {
        "id": "id",
        "email": "email",
        "phone": "phone",
        "username": "username",
        "fullName": "full_name",
        "relationship": "relationship",
        "avatarUrl": "avatar_url",
        "status": "status",
        "emailVerifiedAt": "email_verified_at",
        "phoneVerifiedAt": "phone_verified_at",
    }
    return {k: u[v] for k, v in names.items()}


def new_session(db, user, device, remember, ip=None):
    t = sec.now()
    raw = secrets.token_urlsafe(48)
    row = repository.create_session(
        db,
        (
            user["id"],
            sec.secret_hash(raw),
            device.deviceId,
            device.deviceName,
            device.platform,
            t + timedelta(days=30 if remember else 1),
            ip,
            t,
            t,
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


def otp_delivery(db, user, ip, *, allow_deferred=False):
    t = sec.now()
    last = repository.find_latest_registration_code(db, (user["id"],))
    if last and last["created_at"] + timedelta(seconds=60) > t:
        if allow_deferred:
            return last, "deferred", None
        return failure(
            429,
            "RATE_LIMITED",
            retry=int((last["created_at"] + timedelta(seconds=60) - t).total_seconds())
            + 1,
        )
    for key, limit in [("sms-phone:" + user["phone"], 5), ("sms-ip:" + ip, 20)]:
        err = quota(db, key, limit, 3600)
        if err:
            return err
    vid = uuid4()
    code = f"{secrets.randbelow(1000000):06d}"
    repository.expire_registration_codes(db, (t, user["id"]))
    row = repository.create_registration_code(
        db,
        (
            vid,
            user["id"],
            user["phone"],
            sec.otp_hash(code, str(vid)),
            t + timedelta(minutes=5),
            t,
        ),
    )
    return row, "sent", (user["phone"], code)


def challenge(db, user, otp, delivery, *, raw=None):
    raw = raw or secrets.token_urlsafe(48)
    if not repository.find_challenge_id_by_hash(db, (sec.secret_hash(raw),)):
        repository.revoke_user_challenges(db, (sec.now(), user["id"]))
        repository.create_challenge(
            db,
            (
                user["id"],
                user["phone"],
                sec.secret_hash(raw),
                sec.now() + timedelta(minutes=30),
            ),
        )
    return {
        "verificationId": str(otp["id"]),
        "registrationToken": raw,
        "targetMasked": user["phone"][:3] + "******" + user["phone"][-3:],
        "expiresAt": otp["expires_at"],
        "resendAvailableAt": otp["created_at"] + timedelta(seconds=60),
        "deliveryStatus": delivery,
    }


def register(db, data, ip):
    docs = legal(db)
    if isinstance(docs, AuthFailure):
        return docs, None
    accepted = {c.documentId for c in data.consents if c.isAccepted}
    if not {d["id"] for d in docs if d["is_required"]} <= accepted or any(
        c.documentId not in {d["id"] for d in docs} for c in data.consents
    ):
        return failure(409, "LEGAL_CONSENT_REQUIRED"), None
    err = quota(db, "register-ip:" + ip, 20, 3600)
    if err:
        return err, None
    # A savepoint converts unique-constraint races without aborting the outer transaction.
    import psycopg

    try:
        with db.transaction():
            u = repository.create_user(
                db,
                (
                    str(data.email),
                    data.phone,
                    data.username,
                    sec.password_hasher.hash(data.password),
                    data.fullName,
                    data.relationship,
                ),
            )
    except psycopg.errors.UniqueViolation:
        return failure(409, "ACCOUNT_CONFLICT"), None
    for c in data.consents:
        repository.create_consent(db, (u["id"], c.documentId, c.isAccepted, ip))
    if settings.auth_skip_otp and settings.app_env == "local":
        u = repository.activate_user(db, (u["id"],))
        return {"requiresOtp": False, "user": public_user(u)}, None
    delivery = otp_delivery(db, u, ip)
    if isinstance(delivery, AuthFailure):
        # Preserve quota counters but do not strand a newly created pending user.
        repository.delete_user(db, (u["id"],))
        return delivery, None
    otp, status, sms = delivery
    return challenge(db, u, otp, status), sms


def get_challenge(db, data):
    c = repository.find_challenge_by_hash(
        db, (sec.secret_hash(data.registrationToken),)
    )
    if not c:
        return failure(401, "REGISTRATION_CHALLENGE_INVALID")
    u = repository.lock_user(db, (c["user_id"],))
    c = repository.find_challenge(db, (c["id"],))
    if (
        not u
        or c["revoked_at"]
        or c["expires_at"] <= sec.now()
        or c["target"] != u["phone"]
    ):
        return failure(401, "REGISTRATION_CHALLENGE_INVALID")
    if u["status"] != "pending":
        return failure(403, "ACCOUNT_UNAVAILABLE")
    otp = repository.lock_registration_code(
        db, (data.verificationId, u["id"], u["phone"])
    )
    if not otp:
        return failure(401, "REGISTRATION_CHALLENGE_INVALID")
    return u, otp


def verify(db, data, ip=None):
    pair = get_challenge(db, data)
    if isinstance(pair, AuthFailure):
        return pair
    u, otp = pair
    if otp["used_at"]:
        return failure(409, "OTP_ALREADY_USED")
    if otp["expires_at"] <= sec.now():
        return failure(410, "OTP_EXPIRED")
    if otp["attempts"] >= 5:
        return failure(429, "OTP_ATTEMPTS_EXCEEDED", retry=60)
    if not hmac.compare_digest(
        otp["code_hash"], sec.otp_hash(data.code, str(otp["id"]))
    ):
        repository.increment_code_attempts(db, (otp["id"],))
        return failure(
            400, "OTP_INVALID", details={"attemptsRemaining": 4 - otp["attempts"]}
        )
    t = sec.now()
    repository.consume_registration_code(db, (t, otp["id"]))
    u = repository.activate_verified_user(db, (t, u["id"]))
    return {
        **new_session(db, u, data.device, data.rememberMe, ip),
        "user": public_user(u),
        "deletionRequestCancelled": False,
    }


def resend(db, data, ip):
    pair = get_challenge(db, data)
    if isinstance(pair, AuthFailure):
        return pair, None
    u, _ = pair
    delivery = otp_delivery(db, u, ip)
    if isinstance(delivery, AuthFailure):
        return delivery, None
    otp, status, sms = delivery
    return challenge(db, u, otp, status, raw=data.registrationToken), sms


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
    repository.clear_identifier_throttle(
        db, ("login-id:" + sec.secret_hash(data.identifier),)
    )
    repository.reset_login_attempts(db, (u["id"],))
    if (
        u["status"] == "pending"
        and settings.auth_skip_otp
        and settings.app_env == "local"
    ):
        u = repository.activate_user(db, (u["id"],))
    if u["status"] == "pending":
        delivery = otp_delivery(db, u, ip, allow_deferred=True)
        if isinstance(delivery, AuthFailure):
            return delivery, None
        otp, status, sms = delivery
        return (
            failure(
                403,
                "VERIFICATION_REQUIRED",
                details={"registration": challenge(db, u, otp, status)},
            ),
            sms,
        )
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
    found = repository.find_session_reference(db, (hashed, hashed))
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
    new = secrets.token_urlsafe(48)
    repository.save_refresh_history(db, (s["refresh_token_hash"], s["id"], sec.now()))
    repository.rotate_refresh_token(db, (sec.secret_hash(new), sec.now(), s["id"]))
    return token_result(s, new)


def logout(db, raw):
    pair = session_by_token(db, raw)
    if pair:
        revoke(db, pair[1]["id"])
