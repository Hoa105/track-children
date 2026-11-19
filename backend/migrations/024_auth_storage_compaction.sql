-- Requires approval before application. Historical 023 stays unchanged.
-- Compact a bounded risk signal into the owning user; it is NOT an auth factor.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM account.auth_device_history GROUP BY user_id HAVING count(*) > 16) THEN
        RAISE EXCEPTION 'More than 16 device entries: review preservation before compaction';
    END IF;
    IF EXISTS (SELECT 1 FROM account.mobile_login_limits) THEN
        RAISE EXCEPTION 'Legacy limiter is not empty: review active consumers before removal';
    END IF;
END $$;

ALTER TABLE account.users ADD COLUMN auth_known_devices jsonb NOT NULL DEFAULT '[]'::jsonb
    CHECK (jsonb_typeof(auth_known_devices)='array' AND jsonb_array_length(auth_known_devices)<=16);

UPDATE account.users u SET auth_known_devices=d.entries
FROM (
    SELECT user_id,jsonb_agg(jsonb_build_object(
        'hash',device_hash,'lastAuthenticatedAt',last_authenticated_at)
        ORDER BY last_authenticated_at DESC,device_hash) AS entries
    FROM account.auth_device_history GROUP BY user_id
) d WHERE u.id=d.user_id;

-- No CASCADE: unexpected external dependencies must stop the migration.
DROP TABLE account.auth_device_history;
DROP TABLE account.mobile_login_limits;
