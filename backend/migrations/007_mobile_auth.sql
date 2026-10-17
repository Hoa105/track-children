-- Mobile auth: registration challenges, refresh rotation and shared throttling.
ALTER TABLE account.users
 ADD COLUMN failed_login_attempts smallint NOT NULL DEFAULT 0,
 ADD COLUMN locked_until timestamptz,
 ADD COLUMN password_changed_at timestamptz;
ALTER TABLE account.user_sessions ADD COLUMN last_used_at timestamptz NOT NULL DEFAULT now();
CREATE TABLE account.registration_challenges (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
 target varchar(255) NOT NULL,
 token_hash text NOT NULL UNIQUE,
 expires_at timestamptz NOT NULL,
 revoked_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON account.registration_challenges(user_id);
CREATE TABLE account.refresh_token_history (
 token_hash text PRIMARY KEY,
 session_id uuid NOT NULL REFERENCES account.user_sessions(id) ON DELETE CASCADE,
 used_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE account.auth_rate_limits (
 key text PRIMARY KEY,
 attempts integer NOT NULL,
 resets_at timestamptz NOT NULL
);
ALTER TABLE account.device_tokens ADD COLUMN session_id uuid
 REFERENCES account.user_sessions(id) ON DELETE CASCADE;
CREATE INDEX ON account.device_tokens(session_id);
-- Registration challenges must also be invalidated by existing lifecycle jobs.
CREATE FUNCTION account.revoke_registration_challenges() RETURNS trigger AS $$
BEGIN
 IF NEW.status = 'deleted' THEN
  DELETE FROM account.registration_challenges WHERE user_id = NEW.id;
  RETURN NEW;
 END IF;
 IF NEW.status <> 'pending' OR NEW.email IS DISTINCT FROM OLD.email OR NEW.phone IS DISTINCT FROM OLD.phone THEN
  UPDATE account.registration_challenges SET revoked_at = now()
    WHERE user_id = NEW.id AND revoked_at IS NULL;
 END IF;
 RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_users_auth_challenges AFTER UPDATE ON account.users
 FOR EACH ROW EXECUTE FUNCTION account.revoke_registration_challenges();
