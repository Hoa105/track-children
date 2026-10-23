-- Additive social identities; never merge accounts by matching email alone.
CREATE TABLE account.social_identities (
    provider varchar(10) NOT NULL CHECK (provider IN ('google','apple')),
    subject varchar(255) NOT NULL CHECK (btrim(subject) <> ''),
    user_id uuid NOT NULL REFERENCES account.users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (provider, subject),
    UNIQUE (user_id, provider)
);
CREATE TABLE account.social_challenge_uses (
    token_hash text PRIMARY KEY,
    expires_at timestamptz NOT NULL
);
CREATE INDEX social_challenge_uses_expiry_idx ON account.social_challenge_uses(expires_at);
