-- Additive only. Requires explicit migration approval before applying.
-- No user/child backfill, deletion, auto-verification or identity merging.
CREATE TABLE account.auth_transactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    purpose varchar(40) NOT NULL CHECK (purpose IN
      ('phone_signup','social_signup','password_reset','reauth','change_email','change_phone')),
    user_id uuid REFERENCES account.users(id) ON DELETE CASCADE,
    session_id uuid REFERENCES account.user_sessions(id) ON DELETE CASCADE,
    target varchar(255),
    channel varchar(10) CHECK (channel IN ('sms','email')),
    secret_hash text NOT NULL UNIQUE,
    code_hash text,
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    expires_at timestamptz NOT NULL,
    resend_at timestamptz,
    verified_at timestamptz,
    consumed_at timestamptz,
    invalidated_at timestamptz,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX auth_transactions_expiry_idx ON account.auth_transactions(expires_at);
CREATE INDEX auth_transactions_target_idx ON account.auth_transactions(purpose,target,created_at);
CREATE INDEX auth_transactions_user_idx ON account.auth_transactions(user_id,purpose,created_at);

CREATE TABLE account.auth_consent_receipts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    transaction_id uuid REFERENCES account.auth_transactions(id) ON DELETE SET NULL,
    documents jsonb NOT NULL,
    purpose varchar(40) NOT NULL DEFAULT 'account_registration',
    accepted_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX auth_consent_receipts_user_idx ON account.auth_consent_receipts(user_id,accepted_at);

CREATE TABLE account.auth_device_history (
    user_id uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    device_hash text NOT NULL,
    last_authenticated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY(user_id,device_hash)
);

CREATE TABLE account.auth_refresh_history (
    token_hash text PRIMARY KEY,
    session_id uuid NOT NULL REFERENCES account.user_sessions(id) ON DELETE CASCADE,
    used_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL
);
CREATE INDEX auth_refresh_history_expiry_idx ON account.auth_refresh_history(expires_at);
