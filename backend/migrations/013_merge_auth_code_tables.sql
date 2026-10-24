-- Merge legacy verification/reset tables into account.auth_codes.
-- Safe to run after 009/012: the legacy tables may already be absent.

CREATE TABLE IF NOT EXISTS account.auth_codes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES account.users(id) ON DELETE CASCADE,
    admin_user_id uuid REFERENCES admin.admin_users(id) ON DELETE CASCADE,
    purpose varchar(30) NOT NULL CHECK (purpose IN ('verify_contact','reset_password')),
    channel varchar(10) NOT NULL CHECK (channel IN ('email','sms')),
    target varchar(255) NOT NULL CHECK (btrim(target) <> ''),
    code_hash text NOT NULL,
    attempt_count smallint NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    expires_at timestamptz NOT NULL,
    verified_at timestamptz,
    consumed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT auth_codes_exactly_one_subject
        CHECK ((user_id IS NOT NULL) <> (admin_user_id IS NOT NULL))
);

DO $$
BEGIN
    IF to_regclass('account.verification_codes') IS NOT NULL THEN
        INSERT INTO account.auth_codes
            (id,user_id,purpose,channel,target,code_hash,attempt_count,
             expires_at,consumed_at,created_at)
        SELECT CASE WHEN EXISTS (
                   SELECT 1 FROM account.auth_codes c WHERE c.id = v.id
               ) THEN gen_random_uuid() ELSE v.id END,
               v.user_id,
               CASE WHEN v.purpose = 'reset_password'
                    THEN 'reset_password' ELSE 'verify_contact' END,
               CASE WHEN v.target LIKE '%@%' THEN 'email' ELSE 'sms' END,
               v.target, v.code_hash, v.attempts, v.expires_at,
               v.used_at, v.created_at
        FROM account.verification_codes v
        WHERE v.user_id IS NOT NULL;
    END IF;

    IF to_regclass('admin.admin_password_resets') IS NOT NULL THEN
        INSERT INTO account.auth_codes
            (id,admin_user_id,purpose,channel,target,code_hash,
             expires_at,consumed_at,created_at)
        SELECT CASE WHEN EXISTS (
                   SELECT 1 FROM account.auth_codes c WHERE c.id = r.id
               ) THEN gen_random_uuid() ELSE r.id END,
               r.admin_user_id, 'reset_password', 'email', a.email::text,
               r.token_hash, r.expires_at, r.used_at, r.created_at
        FROM admin.admin_password_resets r
        JOIN admin.admin_users a ON a.id = r.admin_user_id;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS auth_codes_user_purpose_created_idx
    ON account.auth_codes (user_id, purpose, created_at)
    WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS auth_codes_admin_purpose_created_idx
    ON account.auth_codes (admin_user_id, purpose, created_at)
    WHERE admin_user_id IS NOT NULL;

DROP TABLE IF EXISTS account.verification_codes;
DROP TABLE IF EXISTS admin.admin_password_resets;
