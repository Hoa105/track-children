import hashlib
import hmac
import secrets
from datetime import datetime, timezone


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
