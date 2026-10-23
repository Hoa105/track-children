"""Run periodically: python -m app.features.auth.maintenance.

Only expired auth artifacts are removed. Pending accounts are not deleted here.
"""

from app.core.database import transaction
from app.features.auth import rate_limit


def main():
    statements = [
        "DELETE FROM account.user_sessions WHERE expires_at <= now()",
        "DELETE FROM account.auth_codes WHERE expires_at < now() - interval '1 day'",
        "DELETE FROM account.social_challenge_uses WHERE expires_at <= now()",
    ]
    with transaction() as db:
        for statement in statements:
            db.execute(statement)
    rate_limit.purge()
    print("Expired auth artifacts removed.")


if __name__ == "__main__":
    main()
