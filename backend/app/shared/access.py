"""Mobile JWTs are checked against live PostgreSQL sessions on every request."""
import os
from uuid import UUID
import jwt
from fastapi import Request
from app.core.database import transaction
from app.shared.errors import ApiError


def secret():
    value = os.environ.get('AUTH_SECRET', '')
    if len(value) < 32:
        raise ApiError(503, 'AUTH_NOT_CONFIGURED')
    return value


def require_user(request: Request):
    key = secret()
    header = request.headers.get('authorization', '')
    try:
        if not header.startswith('Bearer '):
            raise ValueError()
        claims = jwt.decode(header[7:], key, algorithms=['HS256'],
                            issuer='track-children-mobile', audience='mobile',
                            options={'require': ['sub', 'sid', 'exp', 'iat']})
        uid, sid = UUID(claims['sub']), UUID(claims['sid'])
    except jwt.ExpiredSignatureError:
        raise ApiError(401, 'ACCESS_TOKEN_EXPIRED')
    except (jwt.InvalidTokenError, ValueError, TypeError, KeyError):
        raise ApiError(401, 'ACCESS_TOKEN_INVALID')
    with transaction() as db:
        row = db.execute('''SELECT u.id,u.full_name,u.email,u.status,
            s.expires_at,s.revoked_at,s.expires_at<=now() AS expired FROM account.user_sessions s
            JOIN account.users u ON u.id=s.user_id WHERE s.id=%s AND u.id=%s''',
            (sid, uid)).fetchone()
    if not row or row['revoked_at']:
        raise ApiError(401, 'SESSION_REVOKED')
    if row['expired']:
        raise ApiError(401, 'SESSION_EXPIRED')
    if row['status'] != 'active':
        raise ApiError(403, 'ACCOUNT_UNAVAILABLE')
    return row


def child_access(db, child_id, user_id, write=False, lock=False):
    # Serialize changes per child, including profile/DOB changes and measurements.
    child = db.execute('SELECT * FROM child.children WHERE id=%s AND deleted_at IS NULL' +
                       (' FOR UPDATE' if write or lock else ''),
                       (child_id,)).fetchone()
    if not child:
        raise ApiError(404, 'CHILD_NOT_FOUND')
    level = 'edit' if child['owner_user_id'] == user_id else None
    if level is None:
        member = db.execute('''SELECT p.access_level FROM child.child_members m
            JOIN child.child_member_permissions p ON p.member_id=m.id
            WHERE m.child_id=%s AND m.user_id=%s AND m.status='active'
            AND p.data_scope='growth' ''', (child_id, user_id)).fetchone()
        level = member['access_level'] if member else 'none'
    if level not in ('view', 'edit'):
        raise ApiError(404, 'CHILD_NOT_FOUND')
    if write and level != 'edit':
        raise ApiError(403, 'GROWTH_WRITE_FORBIDDEN')
    child['growthAccess'] = level
    return child
