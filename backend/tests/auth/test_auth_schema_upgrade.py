"""Real PostgreSQL upgrade tests, isolated from API fixtures and the live database.

AUTH_TEST_DATABASE_URL must reference a dedicated *_test DB whose owner can
CREATE DATABASE. Each case creates and drops its own randomly named test DB.
"""
import os
from pathlib import Path
from uuid import uuid4

import psycopg
from psycopg import sql
from psycopg.conninfo import conninfo_to_dict, make_conninfo
import pytest

MIGRATIONS = Path(__file__).resolve().parents[2] / "migrations"
UPGRADE = MIGRATIONS / "009_auth_database_simplification.sql"


@pytest.fixture
def old_db():
    url = os.environ.get("AUTH_TEST_DATABASE_URL")
    if not url:
        pytest.skip("AUTH_TEST_DATABASE_URL required; no live DB fallback")
    options = conninfo_to_dict(url)
    if not options.get("dbname", "").endswith("_test"):
        pytest.fail("AUTH_TEST_DATABASE_URL database must end with _test")
    name = "auth_schema_" + uuid4().hex + "_test"
    with psycopg.connect(url, autocommit=True) as owner:
        owner.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(name)))
        try:
            with psycopg.connect(make_conninfo(url, dbname=name), autocommit=True) as db:
                for path in sorted(MIGRATIONS.glob("*.sql")):
                    if path.name < UPGRADE.name:
                        with db.transaction():
                            db.execute(path.read_text(encoding="utf-8"))
                yield db
        finally:
            owner.execute(sql.SQL("DROP DATABASE {} WITH (FORCE)").format(sql.Identifier(name)))


def upgrade(db):
    with db.transaction():
        db.execute(UPGRADE.read_text(encoding="utf-8"))


def add_user(db, email="parent@example.com", relationship="mother"):
    return db.execute(
        """INSERT INTO account.users(email,password_hash,full_name,relationship,status)
        VALUES (%s,'retained-hash','Existing Parent',%s,'active') RETURNING id""",
        (email, relationship),
    ).fetchone()[0]


def business_fks(db):
    return db.execute("""
        SELECT n.nspname,c.relname,k.conname,pg_get_constraintdef(k.oid)
        FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid
        JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE k.contype='f' AND k.confrelid IN
            ('account.users'::regclass,'admin.admin_users'::regclass)
          AND n.nspname <> 'auth_legacy'
          AND c.relname NOT IN ('verification_codes','auth_codes','user_consents','registration_challenges','admin_password_resets',
                               'admin_invitations','admin_user_roles')
        ORDER BY 1,2,3
    """).fetchall()


def test_fresh_install_enforces_defaults_and_contact_uniqueness(old_db):
    db = old_db
    upgrade(db)
    uid = db.execute("""INSERT INTO account.users(email,password_hash,consented_at)
        VALUES ('Parent@Example.com','hash',now()) RETURNING id,display_name,default_relationship,status""").fetchone()
    assert uid[1:] == ("Phụ huynh", "mother", "pending")
    assert db.execute("""SELECT is_nullable FROM information_schema.columns
        WHERE table_schema='account' AND table_name='users' AND column_name='consented_at'""").fetchone() == ("YES",)
    with pytest.raises(psycopg.errors.UniqueViolation):
        with db.transaction():
            db.execute("""INSERT INTO account.users(email,password_hash,consented_at)
                VALUES ('parent@example.com','hash',now())""")
    session = db.execute("""INSERT INTO account.user_sessions(user_id,refresh_token_hash,platform,expires_at)
        VALUES (%s,'new-refresh','ios',now()+interval '1 day') RETURNING remember_me,revoked_at""", (uid[0],)).fetchone()
    assert session == (True, None)
    code = db.execute("""INSERT INTO account.auth_codes(user_id,purpose,channel,target,code_hash,expires_at)
        VALUES (%s,'verify_contact','email','parent@example.com','hash',now()+interval '5 minutes')
        RETURNING attempt_count,verified_at,consumed_at""", (uid[0],)).fetchone()
    assert code == (0, None, None)
    # The optional seed is available from 009, never automatically populated.
    assert db.execute("SELECT count(*) FROM account.users").fetchone() == (1,)
    for _ in range(2):
        db.execute("SELECT account.seed_local_auth_samples(%s)", ("$argon2id$synthetic-test-hash",))
    assert db.execute("SELECT count(*) FROM account.users").fetchone() == (11,)
    assert db.execute("SELECT count(*) FROM account.users WHERE phone LIKE '+849900000%' AND consented_at IS NOT NULL AND status='active'").fetchone() == (10,)
    assert db.execute("SELECT display_name,default_relationship FROM account.users WHERE email='ngoc.anh@example.com'").fetchone() == ("Nguyễn Ngọc Anh", "mother")
    assert db.execute("SELECT count(DISTINCT default_relationship) FROM account.users WHERE phone LIKE '+849900000%'").fetchone() == (5,)


def test_exact_reset_matches_spec_and_preserves_business(old_db):
    db = old_db
    add_user(db)
    before = business_fks(db)
    upgrade(db)
    assert business_fks(db) == before
    # Column sets come from the specification, rather than from migration SQL.
    import re
    specification = (MIGRATIONS.parents[1] / 'AUTH-DATABASE-CHANGE-SPEC.md').read_text(encoding='utf-8')
    for schema, table in [('account','users'),('account','user_sessions'),('account','auth_codes'),
                          ('admin','admin_users'),('admin','admin_sessions')]:
        block = re.search(r'### 3\.\d '+re.escape(schema+'.'+table)+r'\n(.*?)(?=\n### |\n## )', specification, re.S)[1]
        expected = set(re.findall(r'^\| ([a-z_]+) \|', block, re.M))
        actual = {r[0] for r in db.execute('''SELECT column_name FROM information_schema.columns
            WHERE table_schema=%s AND table_name=%s''', (schema,table)).fetchall()}
        legacy_profile_columns = {'avatar_url', 'gender', 'date_of_birth', 'deleted_at'} if table == 'users' else set()
        assert actual - legacy_profile_columns == expected, (table, actual-expected-legacy_profile_columns, expected-actual)
    assert db.execute("SELECT count(*) FROM account.users").fetchone() == (1,)
    assert db.execute("SELECT to_regnamespace('auth_legacy'),to_regclass('account.registration_challenges'),to_regclass('account.refresh_token_history'),to_regclass('account.auth_rate_limits')").fetchone() == (None,None,None,None)
    db.execute("SELECT account.seed_local_auth_samples(%s)", ("$argon2id$synthetic-test-hash",))
    db.execute("SELECT account.seed_local_auth_samples(%s)", ("$argon2id$synthetic-test-hash",))
    assert db.execute("SELECT count(*) FROM account.users WHERE consented_at IS NOT NULL AND email_verified_at IS NOT NULL").fetchone() == (10,)
    uid = db.execute('SELECT id FROM account.users LIMIT 1').fetchone()[0]
    db.execute('SELECT account.anonymize_user(%s)', (uid,))
    assert db.execute("SELECT status,email,phone FROM account.users WHERE id=%s", (uid,)).fetchone() == ('deleted',None,None)


def test_upgrade_preserves_business_references(old_db):
    db = old_db
    uid = add_user(db)
    db.execute("""INSERT INTO child.children(owner_user_id,full_name,date_of_birth,gender)
        VALUES (%s,'Preserved child','2024-01-01','female')""", (uid,))
    upgrade(db)
    assert db.execute('SELECT owner_user_id FROM child.children').fetchone() == (uid,)
    assert db.execute('SELECT count(*) FROM account.users').fetchone() == (1,)
    assert db.execute("SELECT display_name,default_relationship FROM account.users WHERE id=%s", (uid,)).fetchone() == ('Existing Parent','mother')


def test_code_subject_xor_and_consent_are_enforced(old_db):
    db = old_db
    upgrade(db)
    uid = db.execute("INSERT INTO account.users(email,password_hash,consented_at) VALUES ('parent@example.com','hash',now()) RETURNING id").fetchone()[0]
    aid = db.execute("INSERT INTO admin.admin_users(email,password_hash,full_name) VALUES ('admin@example.com','hash','Admin') RETURNING id").fetchone()[0]
    for user, admin in ((None,None),(uid,aid)):
        with pytest.raises(psycopg.errors.CheckViolation):
            with db.transaction():
                db.execute("""INSERT INTO account.auth_codes(user_id,admin_user_id,purpose,channel,target,code_hash,expires_at)
                    VALUES (%s,%s,'reset_password','email','parent@example.com','hash',now())""", (user,admin))
    with pytest.raises(psycopg.errors.NotNullViolation):
        with db.transaction():
            db.execute("INSERT INTO account.users(email,password_hash) VALUES ('no-consent@example.com','hash')")
