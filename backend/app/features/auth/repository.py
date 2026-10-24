"""SQL persistence for auth. Callers own transactions and lock ordering."""


from app.features.auth.admin.repository import (
    find_access_identity as find_admin_access_identity,
    find_permission as find_admin_permission,
)


def find_access_identity(db, parameters):
    return db.execute(
        """SELECT u.*,s.expires_at AS session_expiry,s.revoked_at AS session_revoked
        FROM account.users u JOIN account.user_sessions s ON s.user_id=u.id
        WHERE u.id=%s AND s.id=%s""",
        parameters,
    ).fetchone()


def create_session(db, parameters):
    return db.execute(
        """INSERT INTO account.user_sessions
        (user_id,refresh_token_hash,platform,expires_at,created_at,remember_me)
        VALUES (%s,%s,%s,%s,%s,%s) RETURNING *""",
        parameters,
    ).fetchone()


def record_successful_login(db, parameters):
    return db.execute(
        "UPDATE account.users SET last_login_at=%s,failed_login_attempts=0,locked_until=NULL WHERE id=%s",
        parameters,
    )


def revoke_session(db, parameters):
    return db.execute(
        "UPDATE account.user_sessions SET revoked_at=COALESCE(revoked_at,%s) WHERE id=%s",
        parameters,
    )


def disable_session_devices(db, parameters):
    return db.execute(
        "UPDATE account.device_tokens SET is_active=false WHERE session_id=%s",
        parameters,
    )


def lock_user(db, parameters):
    return db.execute(
        "SELECT * FROM account.users WHERE id=%s FOR UPDATE", parameters
    ).fetchone()


def lock_user_by_email(db, parameters):
    return db.execute(
        "SELECT * FROM account.users WHERE email=%s FOR UPDATE", parameters
    ).fetchone()


def reset_login_attempts(db, parameters):
    return db.execute(
        "UPDATE account.users SET failed_login_attempts=0,locked_until=NULL WHERE id=%s",
        parameters,
    )


def find_session_reference(db, parameters):
    return db.execute(
        "SELECT user_id,id FROM account.user_sessions WHERE refresh_token_hash=%s",
        parameters,
    ).fetchone()


def lock_session_user(db, parameters):
    return db.execute(
        "SELECT * FROM account.users WHERE id=%s FOR UPDATE", parameters
    ).fetchone()


def lock_session(db, parameters):
    return db.execute(
        "SELECT * FROM account.user_sessions WHERE id=%s FOR UPDATE", parameters
    ).fetchone()


def activate_user(db, parameters):
    return db.execute(
        "UPDATE account.users SET status='active' WHERE id=%s RETURNING *", parameters
    ).fetchone()


def lock_deletion_request(db, parameters):
    return db.execute(
        "SELECT * FROM account.data_deletion_requests WHERE user_id=%s AND status IN ('pending','processing') FOR UPDATE",
        parameters,
    ).fetchone()


def cancel_deletion_request(db, parameters):
    return db.execute(
        "UPDATE account.data_deletion_requests SET status='cancelled',cancelled_at=%s WHERE id=%s",
        parameters,
    )


def restore_user(db, parameters):
    return db.execute(
        "UPDATE account.users SET status='active' WHERE id=%s RETURNING *", parameters
    ).fetchone()


def record_failed_login(db, parameters):
    return db.execute(
        "UPDATE account.users SET failed_login_attempts=%s,locked_until=%s WHERE id=%s",
        parameters,
    )


def lock_user_by_phone(db, parameters):
    return db.execute(
        "SELECT * FROM account.users WHERE phone=%s FOR UPDATE", parameters
    ).fetchone()
