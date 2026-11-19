"""Exercise the shared runner against disposable PostgreSQL databases only."""
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import subprocess
import sys
from uuid import uuid4

import psycopg
from psycopg import sql
from psycopg.conninfo import conninfo_to_dict, make_conninfo
import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from scripts.migrate_system import Database, DATABASES, build_batch, execute_batch, managed_sql


@pytest.fixture
def database():
    source = os.environ.get('AUTH_MIGRATION_TEST_DATABASE_URL') or os.environ.get('AUTH_TEST_DATABASE_URL')
    if not source:
        pytest.skip('Dedicated migration test DB required')
    assert conninfo_to_dict(source)['dbname'].endswith('_test')
    name = 'shared_runner_' + uuid4().hex + '_test'
    url = make_conninfo(source, dbname=name)
    with psycopg.connect(source, autocommit=True, connect_timeout=5) as owner:
        owner.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
        try:
            yield name, url
        finally:
            assert name.startswith('shared_runner_') and name.endswith('_test')
            owner.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(name)))


def plan(name, directory):
    return Database('backend', os.environ.get('MIGRATION_TEST_CONTAINER', 'track-children-postgres'),
                    name, directory, 'account.users')


def run_powershell(name, *options):
    return subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', str(ROOT/'scripts/migrate.ps1'), '-Target', 'backend', '-Database', name,
        '-Container', os.environ.get('MIGRATION_TEST_CONTAINER', 'track-children-postgres'), *options],
        cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=180)


def test_main_entrypoint_fresh_chain_approval_and_idempotence(database):
    name, url = database
    denied = run_powershell(name)
    assert denied.returncode != 0
    assert b'ApproveAuthCompaction' in denied.stdout + denied.stderr
    with psycopg.connect(url) as db:
        assert db.execute("SELECT to_regclass('account.users'),to_regclass('public.schema_migrations')").fetchone() == (None, None)
    first = run_powershell(name, '-ApproveAuthCompaction')
    assert first.returncode == 0, (first.stdout + first.stderr).decode('utf-8', errors='replace')
    expected = {p.stem for p in (ROOT/'backend/migrations').glob('*.sql')}
    with psycopg.connect(url) as db:
        before = db.execute('SELECT version,applied_at FROM public.schema_migrations ORDER BY version').fetchall()
        assert {r[0] for r in before} == expected
        assert db.execute("SELECT count(*) FROM pg_tables WHERE schemaname='account'").fetchone()[0] == 10
        assert db.execute("SELECT to_regclass('account.auth_codes')").fetchone()[0] is None
        assert 'account.auth_codes' not in db.execute("SELECT pg_get_functiondef('account.anonymize_user(uuid)'::regprocedure)").fetchone()[0]
    # Approval is required only when protected migrations are still pending.
    second = run_powershell(name)
    assert second.returncode == 0, (second.stdout + second.stderr).decode('utf-8', errors='replace')
    with psycopg.connect(url) as db:
        assert db.execute('SELECT version,applied_at FROM public.schema_migrations ORDER BY version').fetchall() == before


def test_atomic_failure_rolls_back_schema_ledger_and_auth_pair(database, tmp_path):
    name, url = database
    (tmp_path/'001_initial_schema.sql').write_text("BEGIN; CREATE TABLE marker(value text); INSERT INTO marker VALUES ('Nguyễn Thị Ánh'); COMMIT;", encoding='utf-8')
    (tmp_path/'025_auth_compact_codes.sql').write_text("DO $$ BEGIN IF current_setting('app.auth_025_approved')<>'true' THEN RAISE EXCEPTION 'approval missing'; END IF; END $$; INSERT INTO marker VALUES ('025');", encoding='utf-8')
    failed = tmp_path/'026_auth_anonymization_compaction_fix.sql'
    failed.write_text("DO $$ BEGIN RAISE EXCEPTION 'intentional rollback probe'; END $$;", encoding='utf-8')
    database_plan = plan(name, tmp_path)
    result = execute_batch(database_plan, build_batch(database_plan, approve_auth=True))
    assert result.returncode != 0 and b'intentional rollback probe' in result.stderr
    with psycopg.connect(url) as db:
        assert db.execute("SELECT to_regclass('marker'),to_regclass('public.schema_migrations')").fetchone() == (None, None)
    failed.write_text("INSERT INTO marker VALUES ('026');", encoding='utf-8')
    result = execute_batch(database_plan, build_batch(database_plan, approve_auth=True))
    assert result.returncode == 0, result.stderr.decode('utf-8', errors='replace')
    with psycopg.connect(url) as db:
        assert db.execute('SELECT value FROM marker ORDER BY value').fetchall() == [('025',), ('026',), ('Nguyễn Thị Ánh',)]
        assert db.execute('SELECT count(*) FROM public.schema_migrations').fetchone()[0] == 3


def test_parallel_runners_serialize_and_apply_only_once(database, tmp_path):
    name, url = database
    (tmp_path/'001_initial_schema.sql').write_text('SELECT pg_sleep(0.2); CREATE TABLE once_only(id int PRIMARY KEY); INSERT INTO once_only VALUES (1);', encoding='utf-8')
    database_plan = plan(name, tmp_path)
    batch = build_batch(database_plan)
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: execute_batch(database_plan, batch), range(2)))
    assert [r.returncode for r in results] == [0, 0], [r.stderr for r in results]
    with psycopg.connect(url) as db:
        assert db.execute('SELECT * FROM once_only').fetchall() == [(1,)]
        assert db.execute('SELECT count(*) FROM public.schema_migrations').fetchone()[0] == 1


def test_explicit_bootstrap_preserves_existing_baseline(database, tmp_path):
    name, url = database
    with psycopg.connect(url) as db:
        db.execute('CREATE SCHEMA account; CREATE TABLE account.users(id int PRIMARY KEY); INSERT INTO account.users VALUES (42)')
    (tmp_path/'001_initial_schema.sql').write_text('CREATE SCHEMA account; CREATE TABLE account.users(id int PRIMARY KEY);', encoding='utf-8')
    (tmp_path/'002_next.sql').write_text('CREATE TABLE after_baseline(id int);', encoding='utf-8')
    database_plan = plan(name, tmp_path)
    result = execute_batch(database_plan, build_batch(database_plan, bootstrap=True))
    assert result.returncode == 0, result.stderr.decode('utf-8', errors='replace')
    with psycopg.connect(url) as db:
        assert db.execute('SELECT * FROM account.users').fetchall() == [(42,)]
        assert db.execute('SELECT version FROM public.schema_migrations ORDER BY version').fetchall() == [('001_initial_schema',), ('002_next',)]


def test_wrapper_parser_preserves_functions_literals_and_nested_comments():
    body = "DO $fn$ BEGIN RAISE NOTICE 'COMMIT;'; END $fn$; SELECT 'BEGIN;', \"COMMIT\";"
    transformed = managed_sql('/* outer /* nested */ comment */ BEGIN;\n' + body + '\nCOMMIT;')
    assert body in transformed
    assert transformed.count('Transaction boundary managed') == 2
    assert managed_sql("SELECT E'escaped\\\'COMMIT;';") == "SELECT E'escaped\\\'COMMIT;';"


@pytest.mark.parametrize('text', ['ROLLBACK;', 'COMMIT AND CHAIN;', '\\connect other_database', "SELECT 'unterminated", 'DO $$ missing close'])
def test_wrapper_parser_refuses_unsafe_or_incomplete_input(text):
    with pytest.raises(ValueError):
        managed_sql(text)


def test_ai_plan_has_no_backend_approval_gate(tmp_path):
    (tmp_path/'001_initial_schema.sql').write_text('CREATE SCHEMA ai_kb;', encoding='utf-8')
    batch = build_batch(Database('ai', 'test-container', 'ai_test', tmp_path, 'ai_kb.kb_documents'))
    assert 'ApproveAuthCompaction' not in batch and 'auth_025_approved' not in batch


def test_single_target_required_for_database_override():
    result = subprocess.run([sys.executable, str(ROOT/'scripts/migrate_system.py'), '--target', 'all', '--database', 'wrong'], capture_output=True)
    assert result.returncode != 0 and b'single target' in result.stderr
