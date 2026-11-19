-- REVIEW REQUIRED. Run during an auth/worker maintenance window in one transaction.
-- Preserves legacy IDs, OTP hashes and deadlines; no user/child data is copied.
DO $$ BEGIN
    IF current_setting('app.auth_025_approved',true) IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION '025 requires explicit review; SET LOCAL app.auth_025_approved=true after approval';
    END IF;
END $$;
LOCK TABLE account.auth_codes, account.auth_transactions, account.user_sessions,
    account.device_tokens, account.users, account.auth_consent_receipts
    IN SHARE ROW EXCLUSIVE MODE;

CREATE FUNCTION account.valid_auth_devices(value jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE item jsonb; seen text[] := '{}'; hash text;
BEGIN
    IF value IS NULL OR jsonb_typeof(value)<>'array' THEN RETURN false; END IF;
    IF jsonb_array_length(value)>16 THEN RETURN false; END IF;
    FOR item IN SELECT * FROM jsonb_array_elements(value) LOOP
        IF jsonb_typeof(item)<>'object' OR jsonb_typeof(item->'hash') IS DISTINCT FROM 'string'
           OR jsonb_typeof(item->'lastAuthenticatedAt') IS DISTINCT FROM 'string' THEN RETURN false; END IF;
        hash := item->>'hash';
        IF hash !~ '^[0-9a-f]{64}$' OR hash=ANY(seen)
           OR (item->>'lastAuthenticatedAt') !~ '(Z|[+-][0-9]{2}:[0-9]{2})$' THEN RETURN false; END IF;
        PERFORM (item->>'lastAuthenticatedAt')::timestamptz;
        seen := array_append(seen,hash);
    END LOOP;
    RETURN true;
EXCEPTION WHEN OTHERS THEN RETURN false;
END $$;

CREATE FUNCTION account.valid_auth_consent_documents(value jsonb) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE item jsonb; seen text[] := '{}'; kind text;
BEGIN
    IF value IS NULL OR jsonb_typeof(value)<>'array' THEN RETURN false; END IF;
    IF jsonb_array_length(value)=0 THEN RETURN false; END IF;
    FOR item IN SELECT * FROM jsonb_array_elements(value) LOOP
        IF jsonb_typeof(item)<>'object' OR jsonb_typeof(item->'type') IS DISTINCT FROM 'string'
           OR jsonb_typeof(item->'version') IS DISTINCT FROM 'string'
           OR jsonb_typeof(item->'sha256') IS DISTINCT FROM 'string' THEN RETURN false; END IF;
        kind := item->>'type';
        IF kind NOT IN ('terms','privacy','data_policy') OR kind=ANY(seen)
           OR length(btrim(item->>'version')) NOT BETWEEN 1 AND 20
           OR (item->>'sha256') !~ '^[0-9a-f]{64}$' THEN RETURN false; END IF;
        seen := array_append(seen,kind);
    END LOOP;
    RETURN true;
END $$;

-- Validate existing rows too. Any malformed JSON or owner mismatch aborts;
-- never silently rewrite historical consent or drop device signals.
ALTER TABLE account.users ADD CONSTRAINT users_auth_devices_shape
    CHECK (account.valid_auth_devices(auth_known_devices));
ALTER TABLE account.auth_consent_receipts ADD CONSTRAINT auth_consent_documents_shape
    CHECK (account.valid_auth_consent_documents(documents));
ALTER TABLE account.user_sessions ADD CONSTRAINT user_sessions_id_user_unique UNIQUE(id,user_id);
ALTER TABLE account.auth_transactions ADD CONSTRAINT auth_transactions_session_owner_required
    CHECK (session_id IS NULL OR user_id IS NOT NULL);
ALTER TABLE account.auth_transactions ADD CONSTRAINT auth_transactions_session_owner
    FOREIGN KEY(session_id,user_id) REFERENCES account.user_sessions(id,user_id) ON DELETE CASCADE;
ALTER TABLE account.device_tokens ADD CONSTRAINT device_tokens_session_owner
    FOREIGN KEY(session_id,user_id) REFERENCES account.user_sessions(id,user_id) ON DELETE CASCADE;
ALTER TABLE account.auth_transactions ADD CONSTRAINT auth_transactions_metadata_object
    CHECK (jsonb_typeof(metadata)='object');
ALTER TABLE account.auth_transactions ADD CONSTRAINT auth_transactions_system_kind
    CHECK ((CASE WHEN metadata ? 'limiter' THEN 1 ELSE 0 END
          + CASE WHEN metadata ? 'notice' THEN 1 ELSE 0 END
          + CASE WHEN metadata ? 'appleEvent' THEN 1 ELSE 0 END)<=1
          AND (NOT (metadata ? 'limiter' OR metadata ? 'notice' OR metadata ? 'appleEvent')
               OR purpose='reauth'));

ALTER TABLE account.auth_transactions ADD COLUMN admin_user_id uuid
    REFERENCES admin.admin_users(id) ON DELETE CASCADE;
ALTER TABLE account.auth_transactions DROP CONSTRAINT auth_transactions_purpose_check;
ALTER TABLE account.auth_transactions ADD CONSTRAINT auth_transactions_purpose_check CHECK (purpose IN
    ('phone_signup','social_signup','password_reset','reauth','change_email','change_phone',
     'legacy_verify_contact','legacy_reset_password'));
ALTER TABLE account.auth_transactions ADD CONSTRAINT auth_transactions_legacy_subject CHECK (
    (purpose IN ('legacy_verify_contact','legacy_reset_password')
       AND ((user_id IS NOT NULL)<>(admin_user_id IS NOT NULL)) AND session_id IS NULL
       AND channel IS NOT NULL AND target IS NOT NULL AND btrim(target)<>'' AND code_hash IS NOT NULL
       AND metadata @> '{"legacyCode":true}'::jsonb)
    OR (purpose NOT IN ('legacy_verify_contact','legacy_reset_password') AND admin_user_id IS NULL
        AND NOT metadata ? 'legacyCode'));

-- Collision must abort, including expired legacy codes; no ON CONFLICT loss.
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM account.auth_codes c JOIN account.auth_transactions t USING(id)) THEN
        RAISE EXCEPTION 'Legacy OTP ID collision: review before migration';
    END IF;
END $$;
INSERT INTO account.auth_transactions
    (id,user_id,admin_user_id,purpose,channel,target,secret_hash,code_hash,attempt_count,
     expires_at,verified_at,consumed_at,metadata,created_at)
SELECT id,user_id,admin_user_id,
    CASE purpose WHEN 'verify_contact' THEN 'legacy_verify_contact' ELSE 'legacy_reset_password' END,
    channel,target,encode(gen_random_bytes(32),'hex'),code_hash,attempt_count,
    expires_at,verified_at,consumed_at,'{"legacyCode":true}'::jsonb,created_at
FROM account.auth_codes;
DO $$ BEGIN
    IF (SELECT count(*) FROM account.auth_codes)<>(SELECT count(*) FROM account.auth_transactions
        WHERE purpose IN ('legacy_verify_contact','legacy_reset_password')) THEN
        RAISE EXCEPTION 'Legacy OTP preservation count mismatch';
    END IF;
END $$;
CREATE INDEX auth_transactions_admin_legacy_idx ON account.auth_transactions(admin_user_id,purpose,created_at)
    WHERE admin_user_id IS NOT NULL;
DROP TABLE account.auth_codes; -- No CASCADE: unknown dependencies abort.
