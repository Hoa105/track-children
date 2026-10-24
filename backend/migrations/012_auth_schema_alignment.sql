-- Reconcile databases that already applied the old 011 admin role migration.
-- No account identity or business data is deleted here.

DROP TABLE IF EXISTS admin.admin_user_roles;
DROP TABLE IF EXISTS admin.role_permissions;
DROP TABLE IF EXISTS admin.permissions;
DROP TABLE IF EXISTS admin.roles;

ALTER TABLE account.user_sessions
    ADD COLUMN IF NOT EXISTS remember_me boolean NOT NULL DEFAULT true;

ALTER TABLE admin.admin_users
    ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS auth_codes_user_purpose_created_idx
    ON account.auth_codes (user_id, purpose, created_at)
    WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS auth_codes_admin_purpose_created_idx
    ON account.auth_codes (admin_user_id, purpose, created_at)
    WHERE admin_user_id IS NOT NULL;
