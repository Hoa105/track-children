"""Session entry point for existing active accounts; registration is out of scope."""
import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, Response
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError, InvalidHashError
import jwt
from pydantic import Field
from app.core.database import transaction
from app.features.growth.schemas import StrictModel
from app.shared.access import secret, require_user
from app.shared.errors import ApiError

router = APIRouter(prefix='/api/v1/auth', tags=['Mobile Session'])
hasher = PasswordHasher()
dummy_hash = hasher.hash(secrets.token_urlsafe(32))


class Login(StrictModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=1, max_length=1024)


class Refresh(StrictModel):
    refreshToken: str = Field(min_length=32, max_length=256)


def digest(raw):
    return hashlib.sha256(raw.encode()).hexdigest()


def token_result(session, raw):
    now = datetime.now(timezone.utc)
    expiry = min(now + timedelta(minutes=15), session['expires_at'])
    token = jwt.encode({'sub': str(session['user_id']), 'sid': str(session['id']),
                        'iss': 'track-children-mobile', 'aud': 'mobile',
                        'iat': now, 'exp': expiry}, secret(), algorithm='HS256')
    return {'accessToken': token, 'refreshToken': raw, 'tokenType': 'Bearer',
            'expiresIn': max(1, int((expiry-now).total_seconds()))}


@router.post('/login')
def login(data: Login, response: Response):
    secret()
    response.headers['Cache-Control'] = 'no-store'
    with transaction() as db:
        # Durable per-account and per-identifier throttling, shared across workers.
        key = digest(data.email.strip().lower())
        db.execute('''INSERT INTO account.mobile_login_limits (key) VALUES (%s)
            ON CONFLICT DO NOTHING''', (key,))
        limit = db.execute('SELECT * FROM account.mobile_login_limits WHERE key=%s FOR UPDATE', (key,)).fetchone()
        now = datetime.now(timezone.utc)
        if limit['blocked_until'] and limit['blocked_until'] > now:
            error = ApiError(429, 'LOGIN_TEMPORARILY_LOCKED')
        else:
            user = db.execute('SELECT * FROM account.users WHERE email=%s', (data.email.strip(),)).fetchone()
            valid = False
            try:
                valid = hasher.verify(user['password_hash'] if user else dummy_hash, data.password)
            except (VerificationError, InvalidHashError):
                pass
            if not valid:
                attempts = 1 if limit['blocked_until'] else limit['attempts'] + 1
                db.execute('''UPDATE account.mobile_login_limits SET attempts=%s,blocked_until=%s
                    WHERE key=%s''', (attempts, now+timedelta(minutes=15) if attempts >= 5 else None,key))
                error = ApiError(401, 'INVALID_CREDENTIALS')
            elif user['status'] != 'active':
                error = ApiError(403, 'ACCOUNT_UNAVAILABLE')
            else:
                db.execute('DELETE FROM account.mobile_login_limits WHERE key=%s', (key,))
                raw = secrets.token_urlsafe(48)
                session = db.execute('''INSERT INTO account.user_sessions
                    (user_id,refresh_token_hash,expires_at) VALUES (%s,%s,%s) RETURNING *''',
                    (user['id'],digest(raw),now+timedelta(hours=24))).fetchone()
                result = token_result(session, raw)
                result['user'] = {'id': user['id'], 'fullName': user['full_name'], 'email': user['email']}
                return result
    # Commit counters before raising the error.
    raise error


@router.post('/refresh')
def refresh(data: Refresh, response: Response):
    secret()
    response.headers['Cache-Control'] = 'no-store'
    with transaction() as db:
        row = db.execute('''SELECT s.*,u.status,s.expires_at<=now() AS expired FROM account.user_sessions s
            JOIN account.users u ON u.id=s.user_id WHERE refresh_token_hash=%s FOR UPDATE OF s''',
            (digest(data.refreshToken),)).fetchone()
        if not row or row['revoked_at']:
            raise ApiError(401, 'SESSION_REVOKED')
        if row['expired']:
            raise ApiError(401, 'SESSION_EXPIRED')
        if row['status'] != 'active':
            raise ApiError(403, 'ACCOUNT_UNAVAILABLE')
        raw = secrets.token_urlsafe(48)
        db.execute('UPDATE account.user_sessions SET refresh_token_hash=%s WHERE id=%s', (digest(raw),row['id']))
        return token_result(row, raw)


@router.post('/logout', status_code=204)
def logout(data: Refresh):
    with transaction() as db:
        db.execute('UPDATE account.user_sessions SET revoked_at=now() WHERE refresh_token_hash=%s',
                   (digest(data.refreshToken),))
    return Response(status_code=204)


@router.get('/me')
def me(user=Depends(require_user)):
    return {'id': user['id'], 'fullName': user['full_name'], 'email': user['email']}
