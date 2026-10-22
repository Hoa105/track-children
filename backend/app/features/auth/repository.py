"""SQL persistence for auth. Callers own transactions and lock ordering."""


def find_access_identity(db, parameters):
    return db.execute(
        """SELECT u.*,s.expires_at AS session_expiry,s.revoked_at AS session_revoked
        FROM account.users u JOIN account.user_sessions s ON s.user_id=u.id
        WHERE u.id=%s AND s.id=%s""",
        parameters,
    ).fetchone()


def increment_rate_limit(db, parameters):
    return db.execute(
        """INSERT INTO account.auth_rate_limits(key,attempts,resets_at)
        VALUES (%s,1,%s) ON CONFLICT(key) DO UPDATE SET
        attempts=CASE WHEN auth_rate_limits.resets_at<=%s THEN 1 ELSE auth_rate_limits.attempts+1 END,
        resets_at=CASE WHEN auth_rate_limits.resets_at<=%s THEN EXCLUDED.resets_at ELSE auth_rate_limits.resets_at END
        RETURNING *""",
        parameters,
    ).fetchone()


def create_session(db, parameters):
    return db.execute(
        """INSERT INTO account.user_sessions
        (user_id,refresh_token_hash,device_id,device_name,platform,expires_at,ip_address,created_at,last_used_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *""",
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


def find_latest_registration_code(db, parameters):
    return db.execute(
        """SELECT * FROM account.verification_codes WHERE user_id=%s AND purpose='register'
        ORDER BY created_at DESC,id DESC LIMIT 1""",
        parameters,
    ).fetchone()


def expire_registration_codes(db, parameters):
    return db.execute(
        "UPDATE account.verification_codes SET expires_at=LEAST(expires_at,%s) WHERE user_id=%s AND purpose='register' AND used_at IS NULL",
        parameters,
    )


def create_registration_code(db, parameters):
    return db.execute(
        """INSERT INTO account.verification_codes(id,user_id,target,purpose,code_hash,expires_at,created_at)
        VALUES (%s,%s,%s,'register',%s,%s,%s) RETURNING *""",
        parameters,
    ).fetchone()


def find_challenge_by_hash(db, parameters):
    return db.execute(
        "SELECT * FROM account.registration_challenges WHERE token_hash=%s", parameters
    ).fetchone()


def lock_user(db, parameters):
    return db.execute(
        "SELECT * FROM account.users WHERE id=%s FOR UPDATE", parameters
    ).fetchone()


def find_challenge(db, parameters):
    return db.execute(
        "SELECT * FROM account.registration_challenges WHERE id=%s", parameters
    ).fetchone()


def lock_registration_code(db, parameters):
    return db.execute(
        "SELECT * FROM account.verification_codes WHERE id=%s AND user_id=%s AND purpose='register' AND target=%s FOR UPDATE",
        parameters,
    ).fetchone()


def consume_registration_code(db, parameters):
    return db.execute(
        "UPDATE account.verification_codes SET used_at=%s WHERE id=%s", parameters
    )


def activate_verified_user(db, parameters):
    return db.execute(
        "UPDATE account.users SET status='active',phone_verified_at=%s WHERE id=%s RETURNING *",
        parameters,
    ).fetchone()


def lock_user_by_email(db, parameters):
    return db.execute(
        "SELECT * FROM account.users WHERE email=%s FOR UPDATE", parameters
    ).fetchone()


def clear_identifier_throttle(db, parameters):
    return db.execute("DELETE FROM account.auth_rate_limits WHERE key=%s", parameters)


def reset_login_attempts(db, parameters):
    return db.execute(
        "UPDATE account.users SET failed_login_attempts=0,locked_until=NULL WHERE id=%s",
        parameters,
    )


def find_session_reference(db, parameters):
    return db.execute(
        """SELECT user_id,id FROM account.user_sessions WHERE refresh_token_hash=%s
        UNION SELECT s.user_id,s.id FROM account.user_sessions s JOIN account.refresh_token_history h ON h.session_id=s.id
        WHERE h.token_hash=%s LIMIT 1""",
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


def save_refresh_history(db, parameters):
    return db.execute(
        "INSERT INTO account.refresh_token_history(token_hash,session_id,used_at) VALUES (%s,%s,%s)",
        parameters,
    )


def rotate_refresh_token(db, parameters):
    return db.execute(
        "UPDATE account.user_sessions SET refresh_token_hash=%s,last_used_at=%s WHERE id=%s",
        parameters,
    )


def find_challenge_id_by_hash(db, parameters):
    return db.execute(
        "SELECT id FROM account.registration_challenges WHERE token_hash=%s", parameters
    ).fetchone()


def revoke_user_challenges(db, parameters):
    return db.execute(
        "UPDATE account.registration_challenges SET revoked_at=%s WHERE user_id=%s AND revoked_at IS NULL",
        parameters,
    )


def create_challenge(db, parameters):
    return db.execute(
        """INSERT INTO account.registration_challenges(user_id,target,token_hash,expires_at)
            VALUES (%s,%s,%s,%s)""",
        parameters,
    )


def create_consent(db, parameters):
    return db.execute(
        "INSERT INTO account.user_consents(user_id,document_id,is_accepted,ip_address) VALUES (%s,%s,%s,%s)",
        parameters,
    )


def activate_user(db, parameters):
    return db.execute(
        "UPDATE account.users SET status='active' WHERE id=%s RETURNING *", parameters
    ).fetchone()


def delete_user(db, parameters):
    return db.execute("DELETE FROM account.users WHERE id=%s", parameters)


def increment_code_attempts(db, parameters):
    return db.execute(
        "UPDATE account.verification_codes SET attempts=attempts+1 WHERE id=%s",
        parameters,
    )


def activate_pending_user(db, parameters):
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


def list_effective_legal_documents(db, parameters):
    return db.execute(
        """SELECT DISTINCT ON(doc_type) * FROM account.legal_documents
        WHERE doc_type IN ('terms','privacy','data_policy') AND effective_at<=%s
        ORDER BY doc_type,effective_at DESC,created_at DESC,id""",
        parameters,
    ).fetchall()


def create_user(db, parameters):
    return db.execute(
        """INSERT INTO account.users(email,phone,username,password_hash,full_name,relationship)
                VALUES (%s,%s,%s,%s,%s,%s) RETURNING *""",
        parameters,
    ).fetchone()


def record_failed_login(db, parameters):
    return db.execute(
        "UPDATE account.users SET failed_login_attempts=%s,locked_until=%s WHERE id=%s",
        parameters,
    )
