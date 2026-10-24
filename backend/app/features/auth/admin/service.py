"""Admin auth policy. Expected failures are values so transaction writes commit."""
from datetime import timedelta
import re
import secrets
import sqlite3

from app.core import security as sec
from app.core.config import settings
from app.features.auth import rate_limit
from app.features.auth.admin import repository as repo
from app.features.auth.dependencies import current_user
from app.features.auth.errors import AuthFailure, failure
from app.features.auth.service import quota


def token_result(db, user, session, raw):
    expires = min(session['expires_at'], sec.now() + timedelta(minutes=15))
    return dict(accessToken=sec.access_token(user['id'], session['id'], expires,
                audience=settings.auth_admin_audience), tokenType='Bearer',
                expiresIn=max(1, int((expires-sec.now()).total_seconds())),
                admin=repo.profile(db, user), refreshToken=raw, sessionExpiresAt=session['expires_at'])


def verify_password(db, password, hashed):
    if hashed.startswith(('$2a$', '$2b$', '$2y$')):
        return repo.verify_legacy_password(db, password, hashed)
    return sec.verify_password(password, hashed)


def login(db, data, ip):
    email = str(data.email).lower()
    identity_key = 'admin-login-email:'+sec.secret_hash(email)
    for key, limit, seconds in [('admin-login-ip:'+ip,30,60), (identity_key,5,900)]:
        if err := quota(None,key,limit,seconds):
            return err
    user = repo.lock_by_email(db,email)
    if not verify_password(db,data.password,user['password_hash'] if user else sec.dummy_hash):
        return failure(401,'INVALID_CREDENTIALS')
    if not user or not user['is_active']:
        return failure(403,'ACCOUNT_UNAVAILABLE')
    try:
        rate_limit.clear(identity_key)
    except (sqlite3.Error,OSError):
        return failure(503,'RATE_LIMIT_UNAVAILABLE')
    if not user['password_hash'].startswith('$argon2'):
        repo.set_password(db,user['id'],sec.password_hasher.hash(data.password))
    raw = secrets.token_urlsafe(48)
    session = repo.create_session(db,user['id'],sec.secret_hash(raw),sec.now()+timedelta(hours=8))
    return token_result(db,user,session,raw)


def refresh(db, raw):
    hashed = sec.secret_hash(raw)
    user = repo.lock_refresh_user(db,hashed)
    session = repo.lock_refresh_session(db,hashed)
    if not user or not user['is_active'] or not session or session['revoked_at'] or session['expires_at'] <= sec.now():
        return failure(401,'SESSION_EXPIRED')
    replacement = secrets.token_urlsafe(48)
    repo.rotate_session(db,session['id'],sec.secret_hash(replacement))
    return token_result(db,user,session,replacement)


def me(db, request):
    user = current_user(request,db,admin=True)
    return user if isinstance(user,AuthFailure) else repo.profile(db,user)


def update_profile(db, request, data):
    user = current_user(request, db, admin=True)
    if isinstance(user, AuthFailure):
        return user
    repo.lock_user(db, user['id'])
    user = current_user(request, db, admin=True)
    if isinstance(user, AuthFailure):
        return user
    if user['full_name'] != data.fullName:
        before = {'fullName': user['full_name']}
        user = repo.update_profile(db, user['id'], data.fullName)
        repo.audit_account_change(db, user['id'], 'profile.update', before,
                                  {'fullName': user['full_name']})
    return repo.profile(db, user)


def change_password(db, request, data):
    if data.newPassword == data.currentPassword or not re.search('[A-Za-z]',data.newPassword) or not re.search('[0-9]',data.newPassword):
        return failure(422,'VALIDATION_ERROR')
    user = current_user(request,db,admin=True)
    if isinstance(user,AuthFailure):
        return user
    repo.lock_user(db,user['id'])
    # Recheck after acquiring lock: concurrent logout/password change must invalidate this request.
    user = current_user(request,db,admin=True)
    if isinstance(user,AuthFailure):
        return user
    if err := quota(None,'admin-password:'+str(user['id']),5,900):
        return err
    if not verify_password(db,data.currentPassword,user['password_hash']):
        return failure(401,'INVALID_CREDENTIALS')
    repo.set_password(db,user['id'],sec.password_hasher.hash(data.newPassword))
    repo.revoke_all(db,user['id'])
    repo.audit_account_change(db,user['id'],'password.change')
