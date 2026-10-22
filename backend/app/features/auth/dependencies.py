"""Reusable identity dependencies, independent of router registration."""

from ipaddress import ip_address
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core import security
from app.core.config import settings
from app.core.database import transaction
from app.features.auth import repository
from app.features.auth.errors import AuthFailure, failure
from app.features.auth.presenters import output

bearer_scheme = HTTPBearer(auto_error=False)


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


def token_identity(request, audience):
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
            audience=audience,
            options={"require": ["sub", "sid", "exp", "iat", "iss", "aud"]},
        )
        uid, sid = UUID(claims["sub"]), UUID(claims["sid"])
    except jwt.ExpiredSignatureError:
        return failure(401, "ACCESS_TOKEN_EXPIRED")
    except (jwt.PyJWTError, ValueError, KeyError, TypeError):
        return failure(401, "ACCESS_TOKEN_INVALID")
    return uid, sid


def current_user(request, db, *, admin=False, identity=None):
    identity = identity or token_identity(
        request, settings.auth_admin_audience if admin else settings.auth_audience
    )
    if isinstance(identity, AuthFailure):
        return identity
    finder = (
        repository.find_admin_access_identity
        if admin
        else repository.find_access_identity
    )
    row = finder(db, identity)
    if not row or row["session_revoked"]:
        return failure(401, "SESSION_REVOKED")
    if row["session_expiry"] <= security.now():
        return failure(401, "SESSION_EXPIRED")
    if row["status"] != "active":
        return failure(403, "ACCOUNT_UNAVAILABLE")
    return row


def require_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> dict:
    error = ready()
    if error:
        raise AuthenticationRequired(output(error))
    identity = token_identity(request, settings.auth_audience)
    if isinstance(identity, AuthFailure):
        response = output(identity)
        response.headers["WWW-Authenticate"] = "Bearer"
        raise AuthenticationRequired(response)
    with transaction() as db:
        user = current_user(request, db, identity=identity)
    if isinstance(user, AuthFailure):
        response = output(user)
        if response.status_code == 401:
            response.headers["WWW-Authenticate"] = "Bearer"
        raise AuthenticationRequired(response)
    return user


def current_user_id(user: dict = Depends(require_user)) -> UUID:
    """Identity for child APIs, from the validated JWT and live session only."""
    return UUID(str(user["id"]))


def require_admin(permission: str):
    """Validate the admin JWT/session and resolve assigned permissions in the DB."""

    def dependency(
        request: Request,
        credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    ) -> str:
        error = ready()
        if error:
            raise AuthenticationRequired(output(error))
        identity = token_identity(request, settings.auth_admin_audience)
        if isinstance(identity, AuthFailure):
            response = output(identity)
            response.headers["WWW-Authenticate"] = "Bearer"
            raise AuthenticationRequired(response)
        with transaction() as db:
            user = current_user(request, db, admin=True, identity=identity)
            if not isinstance(user, AuthFailure):
                role = repository.find_admin_permission(db, (user["id"], permission))
        if isinstance(user, AuthFailure):
            response = output(user)
            if response.status_code == 401:
                response.headers["WWW-Authenticate"] = "Bearer"
            raise AuthenticationRequired(response)
        if not role:
            raise HTTPException(403, f"Missing permission: {permission}")
        return role["code"]

    return dependency
