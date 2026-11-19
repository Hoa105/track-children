"""Run periodically: python -m app.features.auth.maintenance.

Only expired auth artifacts are removed. Pending accounts are not deleted here.
"""

from app.core.database import transaction
from app.core.config import settings
from app.features.auth import rate_limit
from app.core import security
from datetime import timedelta
from app.features.auth import code_storage


def main():
    if settings.auth_v2_enabled:
        from app.features.auth.recovery import process_pending
        process_pending(limit=5)
        from app.features.auth.notices import process_pending as send_notices
        send_notices(limit=5)
    statements = [
        "DELETE FROM account.user_sessions WHERE expires_at <= now()",
        "DELETE FROM account.social_challenge_uses WHERE expires_at <= now()",
    ]
    if settings.auth_v2_enabled:
        statements += [
            "DELETE FROM account.auth_refresh_history WHERE expires_at <= now()",
        ]
    with transaction() as db:
        table, purpose = code_storage.storage(db)
        if table == 'account.auth_codes':
            db.execute("DELETE FROM account.auth_codes WHERE expires_at < now() - interval '1 day'")
        else:
            db.execute("DELETE FROM account.auth_transactions WHERE purpose IN ('legacy_verify_contact','legacy_reset_password') AND expires_at < now() - interval '1 day'")
        for statement in statements:
            db.execute(statement)
        if settings.auth_v2_enabled:
            # Approved policy: keep device signals <=90 days and consent receipts
            # <=3 calendar years after account deletion. No child data purge here.
            db.execute("""UPDATE account.users SET auth_known_devices=COALESCE((
                SELECT jsonb_agg(item ORDER BY (item->>'lastAuthenticatedAt')::timestamptz DESC)
                FROM jsonb_array_elements(auth_known_devices) item
                WHERE (item->>'lastAuthenticatedAt')::timestamptz>%s),'[]'::jsonb)
                WHERE auth_known_devices<>'[]'::jsonb AND EXISTS (
                    SELECT 1 FROM jsonb_array_elements(auth_known_devices) old
                    WHERE (old->>'lastAuthenticatedAt')::timestamptz<=%s)""",
                       (security.now()-timedelta(days=90),security.now()-timedelta(days=90)))
            db.execute("""DELETE FROM account.auth_consent_receipts r USING account.users u
                WHERE r.user_id=u.id AND u.status='deleted' AND u.deleted_at IS NOT NULL
                AND u.deleted_at<=%s::timestamptz-interval '3 years'""",(security.now(),))
            # Account anonymization may leave the row in place. Do not retain
            # the device cache for identities already marked deleted.
            db.execute("UPDATE account.users SET auth_known_devices='[]'::jsonb WHERE status='deleted' AND auth_known_devices<>'[]'::jsonb")
            db.execute('DELETE FROM account.auth_transactions WHERE expires_at < %s',
                       (security.now()-timedelta(hours=max(24,settings.auth_recovery_security_hours)),))
            db.execute("DELETE FROM account.auth_transactions WHERE (metadata ? 'notice' OR metadata ? 'appleEvent') AND created_at<=%s",
                       (security.now()-timedelta(days=8),))
    rate_limit.purge()
    print("Expired auth artifacts removed.")


if __name__ == "__main__":
    main()
