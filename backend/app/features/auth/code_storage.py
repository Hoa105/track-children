"""Legacy OTP compatibility during the 025 cutover; never cache schema state."""
import secrets
from app.core import security as sec


def storage(db):
    compact = db.execute("""SELECT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema='account' AND table_name='auth_transactions'
        AND column_name='admin_user_id') AS compact""").fetchone()['compact']
    return ('account.auth_transactions', 'legacy_verify_contact') if compact else ('account.auth_codes', 'verify_contact')


def insert(db, user_id, channel, target, code_id, code_hash, expires_at):
    table, purpose = storage(db)
    if table == 'account.auth_transactions':
        return db.execute('''INSERT INTO account.auth_transactions
            (id,user_id,purpose,channel,target,code_hash,expires_at,secret_hash,metadata)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'{"legacyCode":true}'::jsonb) RETURNING *''',
            (code_id,user_id,purpose,channel,target,code_hash,expires_at,
             sec.secret_hash(secrets.token_urlsafe(48)))).fetchone()
    return db.execute('''INSERT INTO account.auth_codes
        (id,user_id,purpose,channel,target,code_hash,expires_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING *''',
        (code_id,user_id,purpose,channel,target,code_hash,expires_at)).fetchone()
