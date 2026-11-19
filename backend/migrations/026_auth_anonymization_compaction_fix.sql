-- Corrective migration after 025. Preserve existing child/account safeguards.
DO $$
DECLARE original text; revised text;
BEGIN
    IF current_setting('app.auth_026_approved',true) IS DISTINCT FROM 'true' THEN
        RAISE EXCEPTION '026 requires explicit migration approval';
    END IF;
    IF to_regclass('account.auth_codes') IS NOT NULL OR
       to_regclass('account.auth_transactions') IS NULL THEN
        RAISE EXCEPTION '026 requires completed migration 025';
    END IF;
    original := pg_get_functiondef('account.anonymize_user(uuid)'::regprocedure);
    revised := regexp_replace(original,
        'DELETE\s+FROM\s+account\.auth_codes\s+WHERE\s+user_id\s*=\s*p_user_id\s*;',
        'DELETE FROM account.auth_transactions WHERE user_id = p_user_id;', 'i');
    IF revised=original OR revised ~* 'account\.auth_codes' THEN
        RAISE EXCEPTION 'Unexpected anonymize_user definition; review instead of overwriting';
    END IF;
    EXECUTE revised;
END $$;
