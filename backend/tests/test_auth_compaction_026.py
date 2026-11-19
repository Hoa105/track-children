"""Corrective DB function migration: run only after test approval, before commit."""
import os
from pathlib import Path
import sys
from uuid import uuid4
from datetime import timedelta
import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
import pytest
from tests.auth_migration_fixture import historical_auth_database
from app.core import security as sec
sys.path.insert(0,str(Path(__file__).parents[1]/'scripts'))
from prepare_auth_v2_test_db import test_url as dedicated_test_url, TEST_DB

pytestmark=pytest.mark.skipif(os.environ.get('AUTH_026_TEST_APPROVED')!='true', reason='026 approval required')


@pytest.fixture(scope='module')
def migration_url():
    with historical_auth_database(25) as url:
        yield url


def test_function_cutover_preserves_child_guard_receipts_and_rollback(migration_url):
    with psycopg.connect(migration_url,row_factory=dict_row,autocommit=True) as db:
        assert db.execute('SELECT current_database() AS name').fetchone()['name'].startswith('auth_compact_25_')
        original=db.execute("SELECT pg_get_functiondef('account.anonymize_user(uuid)'::regprocedure) AS f").fetchone()['f']
        assert 'account.auth_codes' in original
        with db.transaction(force_rollback=True):
            db.execute("SET LOCAL app.auth_026_approved='true'")
            db.execute((Path(__file__).parents[1]/'migrations/026_auth_anonymization_compaction_fix.sql').read_text(encoding='utf-8'))
            uid=uuid4()
            db.execute("INSERT INTO account.users(id,email,password_hash) VALUES (%s,%s,'test-only')",(uid,str(uid)+'@example.com'))
            child=db.execute("INSERT INTO child.children(owner_user_id,full_name,date_of_birth,gender) VALUES (%s,'Test child','2025-01-01','female') RETURNING id",(uid,)).fetchone()['id']
            with pytest.raises(psycopg.errors.RaiseException):
                with db.transaction():
                    db.execute('SELECT account.anonymize_user(%s)',(uid,))
            assert db.execute('SELECT status FROM account.users WHERE id=%s',(uid,)).fetchone()['status']=='pending'
            db.execute('DELETE FROM child.children WHERE id=%s',(child,))
            db.execute("INSERT INTO account.auth_transactions(user_id,purpose,secret_hash,expires_at) VALUES (%s,'reauth',%s,%s)",
                       (uid,str(uuid4()),sec.now()+timedelta(minutes=5)))
            db.execute('INSERT INTO account.auth_consent_receipts(user_id,documents) VALUES (%s,%s)',
                       (uid,Jsonb([{'type':'terms','version':'trial-1.0','sha256':'a'*64}])))
            db.execute('SELECT account.anonymize_user(%s)',(uid,))
            assert db.execute('SELECT status FROM account.users WHERE id=%s',(uid,)).fetchone()['status']=='deleted'
            assert db.execute('SELECT count(*) AS n FROM account.auth_transactions WHERE user_id=%s',(uid,)).fetchone()['n']==0
            assert db.execute('SELECT count(*) AS n FROM account.auth_consent_receipts WHERE user_id=%s',(uid,)).fetchone()['n']==1
        assert db.execute("SELECT pg_get_functiondef('account.anonymize_user(uuid)'::regprocedure) AS f").fetchone()['f']==original
