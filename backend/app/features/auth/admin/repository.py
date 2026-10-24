"""Parameterized SQL; callers own transactions. Lock order: user, then session."""
from psycopg.types.json import Jsonb


def lock_by_email(db, email):
    return db.execute('SELECT * FROM admin.admin_users WHERE email=%s FOR UPDATE', (email,)).fetchone()


def lock_user(db, uid):
    return db.execute('SELECT * FROM admin.admin_users WHERE id=%s FOR UPDATE', (uid,)).fetchone()


def verify_legacy_password(db, password, hashed):
    # pgcrypto truncates bcrypt inputs at 72 bytes; refuse ambiguous long inputs.
    if '\x00' in password or len(password.encode('utf-8')) > 72:
        return False
    return db.execute('SELECT crypt(%s,%s)=%s AS valid', (password, hashed, hashed)).fetchone()['valid']


def set_password(db, uid, hashed):
    db.execute('UPDATE admin.admin_users SET password_hash=%s,updated_at=now() WHERE id=%s', (hashed, uid))


def update_profile(db, uid, full_name):
    return db.execute('''UPDATE admin.admin_users SET full_name=%s,updated_at=now()
        WHERE id=%s RETURNING *''', (full_name, uid)).fetchone()


def audit_account_change(db, uid, action, before=None, after=None):
    # Callers pass only non-secret profile fields, never credential/session data.
    db.execute('''INSERT INTO admin.admin_audit_logs
        (admin_user_id,action,entity_type,entity_id,before_data,after_data)
        VALUES (%s,%s,'admin_user',%s,%s,%s)''',
        (uid, action, str(uid), Jsonb(before) if before is not None else None,
         Jsonb(after) if after is not None else None))


def create_session(db, uid, hashed, expires):
    session = db.execute('''INSERT INTO admin.admin_sessions(admin_user_id,refresh_token_hash,expires_at)
        VALUES (%s,%s,%s) RETURNING *''', (uid, hashed, expires)).fetchone()
    db.execute('UPDATE admin.admin_users SET last_login_at=now() WHERE id=%s', (uid,))
    return session


def lock_refresh_user(db, hashed):
    return db.execute('''SELECT u.* FROM admin.admin_users u WHERE u.id=(SELECT admin_user_id
        FROM admin.admin_sessions WHERE refresh_token_hash=%s) FOR UPDATE''', (hashed,)).fetchone()


def lock_refresh_session(db, hashed):
    return db.execute('SELECT * FROM admin.admin_sessions WHERE refresh_token_hash=%s FOR UPDATE', (hashed,)).fetchone()


def rotate_session(db, sid, hashed):
    db.execute('UPDATE admin.admin_sessions SET refresh_token_hash=%s WHERE id=%s', (hashed, sid))


def revoke_cookie(db, hashed):
    db.execute('''UPDATE admin.admin_sessions SET revoked_at=COALESCE(revoked_at,now())
        WHERE refresh_token_hash=%s''', (hashed,))


def revoke_all(db, uid):
    db.execute('UPDATE admin.admin_sessions SET revoked_at=COALESCE(revoked_at,now()) WHERE admin_user_id=%s', (uid,))


def profile(db, user):
    # All active admins have the same authorization class. Authorization is
    # enforced by the backend and is not persisted as role/permission rows.
    return dict(id=str(user['id']), email=str(user['email']), fullName=user['full_name'],
                role='admin', roles=['admin'], permissions=[])


def find_access_identity(db, parameters):
    return db.execute('''SELECT u.*, CASE WHEN u.is_active THEN 'active' ELSE 'locked' END AS status,
        s.expires_at AS session_expiry,s.revoked_at AS session_revoked
        FROM admin.admin_users u JOIN admin.admin_sessions s ON s.admin_user_id=u.id
        WHERE u.id=%s AND s.id=%s''', parameters).fetchone()


def find_permission(db, parameters):
    return db.execute('''SELECT %s AS code
        FROM admin.admin_users
        WHERE id=%s AND is_active=true''', (parameters[1], parameters[0])).fetchone()
