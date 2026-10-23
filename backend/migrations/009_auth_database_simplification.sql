-- Consolidated auth reset: replaces former 009 + 010 (development baseline).
-- Apply after 001-008 in one transaction. Deletes old AUTH data only.
-- Abort if any business row references an old identity. Back up before use.
-- Already-upgraded databases must reconcile the ledger, never replay this reset.
DO $$
DECLARE ref record; linked boolean;
BEGIN
    FOR ref IN
        SELECT n.nspname, c.relname, a.attname
        FROM pg_constraint k
        JOIN pg_class c ON c.oid = k.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = ANY(k.conkey)
        WHERE k.contype = 'f'
          AND k.confrelid IN ('account.users'::regclass, 'admin.admin_users'::regclass)
          AND n.nspname <> 'auth_legacy'
          AND NOT (n.nspname = 'account' AND c.relname IN
              ('user_sessions','verification_codes','user_consents','registration_challenges'))
          AND NOT (n.nspname = 'admin' AND c.relname IN ('admin_sessions','admin_password_resets','admin_invitations','admin_user_roles'))
    LOOP
        -- Block concurrent business inserts while resetting the referenced identities.
        EXECUTE format('LOCK TABLE %I.%I IN SHARE ROW EXCLUSIVE MODE', ref.nspname, ref.relname);
        EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I.%I WHERE %I IS NOT NULL)',
            ref.nspname, ref.relname, ref.attname) INTO linked;
        IF linked THEN
            RAISE EXCEPTION 'Auth reset refused: %.%.% still references an account',
                ref.nspname, ref.relname, ref.attname;
        END IF;
    END LOOP;
END $$;


LOCK TABLE account.users, admin.admin_users IN ACCESS EXCLUSIVE MODE;
DROP TRIGGER trg_users_auth_challenges ON account.users;
DROP FUNCTION account.revoke_registration_challenges();
DROP TRIGGER trg_admin_users_keep_super_admin ON admin.admin_users;
DROP TRIGGER trg_admin_user_roles_keep_super_admin ON admin.admin_user_roles;
DROP FUNCTION admin.ensure_active_super_admin();
DROP TABLE account.user_consents;
DROP TABLE account.legal_documents;
DROP TABLE account.verification_codes;
DROP TABLE admin.admin_password_resets;
DROP TABLE admin.admin_invitations;
DROP TABLE admin.admin_user_roles;
DROP TABLE admin.role_permissions;
DROP TABLE admin.permissions;
DROP TABLE admin.roles;
DROP TABLE account.registration_challenges;
DROP TABLE account.refresh_token_history;
DROP TABLE account.auth_rate_limits;
DELETE FROM account.user_sessions;
DELETE FROM admin.admin_sessions;
DELETE FROM account.users;
DELETE FROM admin.admin_users;

ALTER TABLE account.users RENAME COLUMN full_name TO display_name;
ALTER TABLE account.users RENAME COLUMN relationship TO default_relationship;
ALTER TABLE account.users
    DROP CONSTRAINT users_deleted_at_check,
    DROP CONSTRAINT users_status_check,
    DROP COLUMN username,
    DROP COLUMN avatar_url,
    DROP COLUMN gender,
    DROP COLUMN date_of_birth,
    DROP COLUMN deleted_at,
    ADD COLUMN consented_at timestamptz NOT NULL,
    ALTER COLUMN display_name SET DEFAULT 'Phụ huynh',
    ALTER COLUMN default_relationship SET DEFAULT 'mother',
    ALTER COLUMN default_relationship SET NOT NULL,
    ADD CONSTRAINT users_default_relationship_check CHECK
        (default_relationship IN ('mother','father','grandfather','grandmother','other_guardian')),
    ADD CONSTRAINT users_failed_login_attempts_check CHECK (failed_login_attempts >= 0),
    ADD CONSTRAINT users_nonempty_contact_check CHECK
        ((email IS NULL OR btrim(email::text) <> '') AND (phone IS NULL OR btrim(phone) <> '')),
    ADD CONSTRAINT users_status_check CHECK (status IN ('pending','active','locked','deleted'));
ALTER TABLE account.user_sessions
    ADD COLUMN remember_me boolean NOT NULL DEFAULT true,
    ALTER COLUMN platform SET NOT NULL,
    DROP COLUMN device_id,
    DROP COLUMN device_name,
    DROP COLUMN ip_address,
    DROP COLUMN last_used_at;
ALTER TABLE admin.admin_users
    ADD COLUMN is_active boolean NOT NULL DEFAULT true,
    DROP COLUMN status,
    DROP COLUMN failed_login_attempts,
    DROP COLUMN locked_until,
    DROP COLUMN password_changed_at;
ALTER TABLE admin.admin_sessions
    DROP COLUMN ip_address,
    DROP COLUMN user_agent,
    DROP COLUMN last_used_at;
DROP INDEX admin.admin_sessions_admin_user_id_idx;
CREATE INDEX admin_sessions_admin_user_id_idx ON admin.admin_sessions(admin_user_id);

CREATE TABLE account.auth_codes (
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
    CONSTRAINT auth_codes_exactly_one_subject CHECK
        ((user_id IS NOT NULL) <> (admin_user_id IS NOT NULL))
);
CREATE INDEX auth_codes_user_purpose_created_idx ON account.auth_codes (user_id, purpose, created_at)
    WHERE user_id IS NOT NULL;
CREATE INDEX auth_codes_admin_purpose_created_idx ON account.auth_codes (admin_user_id, purpose, created_at)
    WHERE admin_user_id IS NOT NULL;

-- Preserve business deletion cleanup without references to removed auth columns.
-- Contact NULL remains permitted only for an anonymized (deleted) account.
CREATE OR REPLACE FUNCTION account.anonymize_user(p_user_id uuid) RETURNS void AS $$
BEGIN
    PERFORM 1 FROM account.users WHERE id = p_user_id AND status <> 'deleted' FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User % not found or already deleted', p_user_id;
    END IF;
    IF EXISTS (SELECT 1 FROM child.children WHERE owner_user_id = p_user_id AND deleted_at IS NULL) THEN
        RAISE EXCEPTION 'User % still owns child profiles: transfer or delete them first', p_user_id;
    END IF;
    DELETE FROM account.user_sessions WHERE user_id = p_user_id;
    DELETE FROM account.device_tokens WHERE user_id = p_user_id;
    DELETE FROM account.auth_codes WHERE user_id = p_user_id;
    DELETE FROM child.child_members WHERE user_id = p_user_id;
    UPDATE child.child_invitations SET status = 'cancelled', responded_at = now()
      WHERE status = 'pending' AND (inviter_id = p_user_id OR invitee_user_id = p_user_id);
    UPDATE child.ownership_transfers SET status = 'cancelled', responded_at = now()
      WHERE status = 'pending' AND (from_user_id = p_user_id OR to_user_id = p_user_id);
    DELETE FROM activity.activity_favorites WHERE user_id = p_user_id;
    DELETE FROM notification.user_notification_settings WHERE user_id = p_user_id;
    DELETE FROM notification.notifications WHERE user_id = p_user_id;
    DELETE FROM notification.reminders WHERE user_id = p_user_id;
    DELETE FROM community.post_likes WHERE user_id = p_user_id;
    DELETE FROM community.post_saves WHERE user_id = p_user_id;
    UPDATE community.posts SET status = 'removed' WHERE author_id = p_user_id;
    UPDATE community.post_comments SET status = 'removed' WHERE author_id = p_user_id;
    UPDATE account.users SET email = NULL, phone = NULL, password_hash = '!deleted',
        display_name = 'Người dùng đã xóa', default_relationship = 'mother',
        email_verified_at = NULL, phone_verified_at = NULL,
        failed_login_attempts = 0, locked_until = NULL, status = 'deleted'
      WHERE id = p_user_id;
    UPDATE account.data_deletion_requests SET status = 'completed', completed_at = now()
      WHERE user_id = p_user_id AND status IN ('pending','processing');
END; $$ LANGUAGE plpgsql;

-- Deletion requests now track the grace period themselves; no pending_deletion
-- account status exists in the exact design. Cancelling leaves the account status intact.
CREATE OR REPLACE FUNCTION account.admin_cancel_deletion(p_request_id uuid, p_admin_id uuid, p_note text)
RETURNS void AS $$
BEGIN
    UPDATE account.data_deletion_requests
      SET status = 'cancelled', cancelled_at = now(), cancelled_by_admin = p_admin_id, cancel_note = p_note
      WHERE id = p_request_id AND status = 'pending';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Deletion request % is not pending', p_request_id;
    END IF;
END; $$ LANGUAGE plpgsql;

-- Optional local fixture seed; not invoked automatically by schema migration.
CREATE OR REPLACE FUNCTION account.seed_local_auth_samples(p_password_hash text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
    IF p_password_hash IS NULL OR p_password_hash NOT LIKE '$argon2%' THEN
        RAISE EXCEPTION 'Local auth samples require an Argon2 password hash';
    END IF;
    INSERT INTO account.users
        (email, phone, password_hash, display_name, default_relationship, status, consented_at,
         email_verified_at)
    SELECT sample.email,
           sample.phone,
           p_password_hash,
           sample.display_name,
           sample.relationship,
           'active',
           now(), -- Synthetic fixtures only, never used to backfill real consent.
           now() -- Simulated email verification for active local fixture accounts.
    -- Fictional Vietnamese caregivers; example.com email addresses are for examples.
    -- Phone values are fixtures, not verified contacts; never send real SMS to them.
    FROM (VALUES
        ('ngoc.anh@example.com',   '+84990000001', 'Nguyễn Ngọc Anh',  'mother'),
        ('minh.duc@example.com',   '+84990000002', 'Trần Minh Đức',    'father'),
        ('thu.ha@example.com',     '+84990000003', 'Lê Thu Hà',        'mother'),
        ('quang.huy@example.com',  '+84990000004', 'Phạm Quang Huy',   'father'),
        ('thanh.mai@example.com',  '+84990000005', 'Hoàng Thanh Mai',  'mother'),
        ('van.hung@example.com',   '+84990000006', 'Nguyễn Văn Hùng',  'grandfather'),
        ('thi.lan@example.com',    '+84990000007', 'Trần Thị Lan',     'grandmother'),
        ('bao.tran@example.com',   '+84990000008', 'Đỗ Bảo Trân',      'other_guardian'),
        ('tuan.kiet@example.com',  '+84990000009', 'Vũ Tuấn Kiệt',     'father'),
        ('phuong.linh@example.com','+84990000010', 'Bùi Phương Linh',  'mother')
    ) AS sample(email, phone, display_name, relationship)
    ON CONFLICT DO NOTHING;
END;
$$;
REVOKE ALL ON FUNCTION account.seed_local_auth_samples(text) FROM PUBLIC;
