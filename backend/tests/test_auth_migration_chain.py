"""Run the complete migration chain in disposable PostgreSQL databases."""

import os
from pathlib import Path
from uuid import uuid4

import psycopg
from psycopg import sql
import pytest


@pytest.mark.parametrize("legacy", [False, True])
def test_full_chain_and_legacy_role_reconciliation(legacy):
    url = os.environ.get("AUTH_MIGRATION_TEST_DATABASE_URL")
    if not url:
        pytest.skip("AUTH_MIGRATION_TEST_DATABASE_URL required")
    info = psycopg.conninfo.conninfo_to_dict(url)
    assert info["dbname"].endswith("_test")
    name = "auth_migration_" + uuid4().hex + "_test"
    target = psycopg.conninfo.make_conninfo(url, dbname=name)
    files = sorted((Path(__file__).parents[1] / "migrations").glob("*.sql"))
    with psycopg.connect(url, autocommit=True) as admin:
        admin.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
        try:
            with psycopg.connect(target) as db:
                for file in files:
                    if legacy and file.name == "009_auth_database_simplification.sql":
                        role = db.execute(
                            "SELECT id FROM admin.roles LIMIT 1"
                        ).fetchone()[0]
                        invitation = db.execute(
                            "INSERT INTO admin.admin_invitations"
                            "(email,role_id,token_hash,expires_at) "
                            "VALUES ('legacy@example.com',%s,'legacy-chain-token',now()+interval '1 day') RETURNING id",
                            (role,),
                        ).fetchone()[0]
                    if legacy and file.name.startswith("012_"):
                        # Simulate an older applied 011 restoring roles and the FK.
                        db.execute("CREATE TABLE admin.roles(id integer PRIMARY KEY)")
                        db.execute("INSERT INTO admin.roles VALUES (%s)", (role,))
                        db.execute(
                            "ALTER TABLE admin.admin_invitations ADD CONSTRAINT "
                            "admin_invitations_role_id_fkey FOREIGN KEY(role_id) REFERENCES admin.roles(id)"
                        )
                    with db.transaction():
                        db.execute(file.read_text(encoding="utf-8"), prepare=False)
                        if file.name.startswith('012_'):
                            db.execute(file.read_text(encoding='utf-8'),prepare=False)
                    db.commit()
                assert (
                    db.execute("SELECT to_regclass('admin.roles')").fetchone()[0]
                    is None
                )
                # Auth cutover must keep capabilities/consent/replay history and
                # retire the old code table, regardless of unrelated growth tables.
                assert db.execute("""SELECT to_regclass('account.auth_codes'),
                    to_regclass('account.auth_transactions') IS NOT NULL,
                    to_regclass('account.auth_consent_receipts') IS NOT NULL,
                    to_regclass('account.auth_refresh_history') IS NOT NULL""").fetchone()==(None,True,True,True)
                if legacy:
                    assert db.execute(
                        "SELECT email::text,role_id,token_hash FROM admin.admin_invitations WHERE id=%s",
                        (invitation,),
                    ).fetchone() == ("legacy@example.com", role, "legacy-chain-token")
        finally:
            admin.execute(sql.SQL("DROP DATABASE {}").format(sql.Identifier(name)))
