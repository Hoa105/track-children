import hashlib
import hmac
import secrets
from datetime import datetime, timezone
from typing import Annotated
from uuid import UUID

from fastapi import Depends, Header, HTTPException, status
from psycopg2.extensions import connection as Connection
from app.core.database import get_db

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from app.core.config import settings

password_hasher = PasswordHasher()
dummy_hash = password_hasher.hash(secrets.token_urlsafe(32))


def now():
    return datetime.now(timezone.utc)


def secret_hash(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def otp_hash(value: str, verification_id: str) -> str:
    return hmac.new(
        settings.auth_secret.encode(),
        f"{verification_id}:{value}".encode(),
        hashlib.sha256,
    ).hexdigest()


def verify_password(value: str, hashed: str) -> bool:
    try:
        return password_hasher.verify(hashed, value)
    except (VerificationError, InvalidHashError):
        return False


def access_token(user_id, session_id, expires):
    return jwt.encode(
        {
            "sub": str(user_id),
            "sid": str(session_id),
            "iat": now(),
            "exp": expires,
            "iss": settings.auth_issuer,
            "aud": settings.auth_audience,
        },
        settings.auth_secret,
        algorithm="HS256",
    )


def _require_dev_auth() -> None:
    if not settings.dev_auth:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Chưa hỗ trợ đăng nhập")


def current_user_id(
    x_user_id: Annotated[str | None, Header()] = None,
) -> UUID:
    _require_dev_auth()
    try:
        return UUID(x_user_id or "")
    except ValueError:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Thiếu hoặc sai X-User-Id"
        ) from None


def require_admin(permission: str):
    """Dependency: admin có `permission` (theo admin.role_permissions)."""

    def dependency(
        x_admin_role: Annotated[str | None, Header()] = None,
        conn: Connection = Depends(get_db),
    ) -> str:
        _require_dev_auth()
        if not x_admin_role:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Thiếu X-Admin-Role")
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1 FROM admin.roles r
                JOIN admin.role_permissions rp ON rp.role_id = r.id
                JOIN admin.permissions p ON p.id = rp.permission_id
                WHERE r.code = %s AND p.code = %s
                """,
                (x_admin_role, permission),
            )
            if cur.fetchone() is None:
                raise HTTPException(
                    status.HTTP_403_FORBIDDEN, f"Cần quyền {permission}"
                )
        return x_admin_role

    return dependency
