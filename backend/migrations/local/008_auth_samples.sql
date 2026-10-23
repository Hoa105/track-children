-- Optional LOCAL data migration, excluded from normal schema migrations.
-- Run via python -m app.seed.local_auth (supplies an Argon2 password hash).
INSERT INTO account.users
    (email, phone, username, password_hash, full_name, relationship, status)
SELECT 'parent' || lpad(n::text, 2, '0') || '@example.com',
       '+849900000' || lpad(n::text, 2, '0'),
       'sample_parent_' || lpad(n::text, 2, '0'),
       current_setting('app.sample_password_hash'),
       'Local Test Parent ' || n,
       CASE WHEN n % 3 = 0 THEN 'guardian' WHEN n % 2 = 0 THEN 'father' ELSE 'mother' END,
       'active'
FROM generate_series(1, 10) AS n
ON CONFLICT DO NOTHING;
