"""Reusable identity dependencies, independent of router registration."""

from ipaddress import ip_address
from uuid import UUID

import jwt
from fastapi import Request

from app.core import security
from app.core.config import settings
from app.core.database import transaction
from app.features.auth import repository
from app.features.auth.errors import AuthFailure, failure
from app.features.auth.presenters import output


class AuthenticationRequired(Exception):
    def __init__(self, response):
        self.response = response


def ready():
    if len(settings.auth_secret) < 32:
        return failure(503, "AUTH_NOT_CONFIGURED")


def client_ip(request: Request):
    try:
        return str(ip_address(request.client.host)) if request.client else "127.0.0.1"
    except ValueError:
        return "127.0.0.1"


def current_user(request, db):
    header = request.headers.get("authorization", "")
    try:
        scheme, raw = header.split(" ", 1)
        if scheme.lower() != "bearer":
            raise ValueError()
        claims = jwt.decode(
            raw,
            settings.auth_secret,
            algorithms=["HS256"],
            issuer=settings.auth_issuer,
            audience=settings.auth_audience,
            options={"require": ["sub", "sid", "exp", "iat", "iss", "aud"]},
        )
        uid, sid = UUID(claims["sub"]), UUID(claims["sid"])
    except jwt.ExpiredSignatureError:
        return failure(401, "ACCESS_TOKEN_EXPIRED")
    except (jwt.PyJWTError, ValueError, KeyError, TypeError):
        return failure(401, "ACCESS_TOKEN_INVALID")
    row = repository.find_access_identity(db, (uid, sid))
    if not row or row["session_revoked"]:
        return failure(401, "SESSION_REVOKED")
    if row["session_expiry"] <= security.now():
        return failure(401, "SESSION_EXPIRED")
    if row["status"] != "active":
        return failure(403, "ACCOUNT_UNAVAILABLE")
    return row


def require_user(request: Request) -> dict:
    error = ready()
    if error:
        raise AuthenticationRequired(output(error))
    with transaction() as db:
        user = current_user(request, db)
    if isinstance(user, AuthFailure):
        response = output(user)
        if response.status_code == 401:
            response.headers["WWW-Authenticate"] = "Bearer"
        raise AuthenticationRequired(response)
    return user
