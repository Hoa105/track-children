"""Run only after explicit 025 review approval; all changes roll back."""
from datetime import timedelta
import os
from pathlib import Path
import sys
from types import SimpleNamespace
from uuid import uuid4

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
import pytest

from app.core.config import settings
from app.core import security as sec
from app.features.auth import registration, code_storage
from app.features.auth.schemas import Device
from tests.auth_migration_fixture import historical_auth_database

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from prepare_auth_v2_test_db import test_url as dedicated_test_url, TEST_DB

pytestmark = pytest.mark.skipif(os.environ.get('AUTH_025_TEST_APPROVED') != 'true',
                              reason='Migration 025 requires explicit test approval')


@pytest.fixture(scope='module')
def migration_url():
    with historical_auth_database(24) as url:
        yield url


def test_compaction_preserves_legacy_codes_constraints_and_rollback(monkeypatch,migration_url):
    with psycopg.connect(migration_url, row_factory=dict_row, autocommit=True) as db:
        assert db.execute('SELECT current_database() AS name').fetchone()['name'].startswith('auth_compact_24_')
        assert code_storage.storage(db)[0] == 'account.auth_codes'
        with db.transaction(force_rollback=True):
            # These synthetic rows and all DDL are rolled back together.
            uid, other, aid, sid = uuid4(), uuid4(), uuid4(), uuid4()
            for user in (uid, other):
                db.execute("INSERT INTO account.users(id,email,password_hash) VALUES (%s,%s,'test-only')",
                           (user, str(user)+'@example.com'))
            db.execute("INSERT INTO admin.admin_users(id,email,password_hash,full_name) VALUES (%s,%s,'test-only','Test admin')",
                       (aid, str(aid)+'@example.com'))
            db.execute("INSERT INTO account.user_sessions(id,user_id,refresh_token_hash,platform,expires_at) VALUES (%s,%s,%s,'android',%s)",
                       (sid,uid,str(uuid4()),sec.now()+timedelta(days=1)))
            monkeypatch.setattr(settings, 'app_env', 'local')
            monkeypatch.setattr(settings, 'auth_otp_preview', True)
            monkeypatch.setattr(settings, 'auth_secret', 'migration-test-secret-not-for-production-123456789')
            grant, _ = registration.issue(db, db.execute('SELECT * FROM account.users WHERE id=%s', (uid,)).fetchone())
            assert grant['deliveryStatus'] == 'preview'
            db.execute("""INSERT INTO account.auth_codes(admin_user_id,purpose,channel,target,code_hash,expires_at)
                VALUES (%s,'reset_password','email',%s,'preserve-this-hash',%s)""",
                       (aid,str(aid)+'@example.com',sec.now()+timedelta(minutes=5)))
            old = db.execute('SELECT * FROM account.auth_codes').fetchall()
            db.execute("SET LOCAL app.auth_025_approved='true'")
            db.execute((Path(__file__).parents[1]/'migrations/025_auth_compact_codes.sql').read_text(encoding='utf-8'))
            assert code_storage.storage(db)[0] == 'account.auth_transactions'
            for row in old:
                migrated = db.execute('SELECT * FROM account.auth_transactions WHERE id=%s', (row['id'],)).fetchone()
                for key in row:
                    if key != 'purpose':
                        assert migrated[key] == row[key], key
                assert migrated['purpose'] == 'legacy_'+row['purpose']
            # Signed challenge issued before cutover still verifies afterwards.
            challenge = SimpleNamespace(registrationToken=grant['registrationToken'],
                verificationId=uuid4(), code=grant['devOtp'], device=Device(platform='android',deviceId='migration-test'), rememberMe=True)
            from uuid import UUID
            challenge.verificationId = UUID(grant['verificationId'])
            assert not isinstance(registration.subject(db,challenge), registration.AuthFailure)
            result = registration.verify(db, challenge, '127.0.0.1')
            assert str(result['user']['id']) == str(uid)
            assert isinstance(registration.verify(db,challenge,'127.0.0.1'), registration.AuthFailure)
            new, _ = registration.issue(db,db.execute('SELECT * FROM account.users WHERE id=%s', (other,)).fetchone())
            assert new['requiresOtp'] is True
            assert db.execute("SELECT count(*) AS n FROM account.auth_transactions WHERE id=%s AND purpose='legacy_verify_contact'",
                              (new['verificationId'],)).fetchone()['n'] == 1
            for query, values in [
                ("UPDATE account.users SET auth_known_devices=%s WHERE id=%s", (Jsonb([{'hash':'bad'}]),uid)),
                ("INSERT INTO account.auth_consent_receipts(user_id,documents) VALUES (%s,%s)", (uid,Jsonb([]))),
                ("INSERT INTO account.auth_transactions(purpose,user_id,session_id,secret_hash,expires_at) VALUES ('reauth',%s,%s,%s,%s)",
                 (other,sid,str(uuid4()),sec.now()+timedelta(minutes=5))),
                ("INSERT INTO account.device_tokens(user_id,session_id,fcm_token,platform) VALUES (%s,%s,%s,'ios')",
                 (other,sid,str(uuid4()))),
            ]:
                with pytest.raises(psycopg.IntegrityError):
                    with db.transaction():
                        db.execute(query, values)
            valid = [{'hash': 'a'*64, 'lastAuthenticatedAt': sec.now().isoformat()}]
            db.execute('UPDATE account.users SET auth_known_devices=%s WHERE id=%s', (Jsonb(valid),uid))
            receipt = [{'type':'terms','version':'trial-1.0','sha256':'b'*64}]
            db.execute('INSERT INTO account.auth_consent_receipts(user_id,documents) VALUES (%s,%s)', (uid,Jsonb(receipt)))
        assert code_storage.storage(db)[0] == 'account.auth_codes'
        assert not db.execute('SELECT id FROM account.users WHERE id=%s', (uid,)).fetchone()


@pytest.mark.parametrize('invalid', ['devices', 'consent', 'owner', 'collision'])
def test_migration_refuses_invalid_existing_data_without_partial_ddl(invalid,migration_url):
    with psycopg.connect(migration_url,row_factory=dict_row,autocommit=True) as db:
        assert db.execute('SELECT current_database() AS name').fetchone()['name'].startswith('auth_compact_24_')
        with db.transaction(force_rollback=True):
            uid,other,sid,cid=uuid4(),uuid4(),uuid4(),uuid4()
            for user in (uid,other):
                db.execute("INSERT INTO account.users(id,email,password_hash) VALUES (%s,%s,'test-only')",
                           (user,str(user)+'@example.com'))
            if invalid=='devices':
                db.execute('UPDATE account.users SET auth_known_devices=%s WHERE id=%s',(Jsonb([{'hash':'bad'}]),uid))
            elif invalid=='consent':
                db.execute('INSERT INTO account.auth_consent_receipts(user_id,documents) VALUES (%s,%s)',(uid,Jsonb([])))
            elif invalid=='owner':
                db.execute("INSERT INTO account.user_sessions(id,user_id,refresh_token_hash,platform,expires_at) VALUES (%s,%s,%s,'ios',%s)",
                           (sid,uid,str(uuid4()),sec.now()+timedelta(days=1)))
                db.execute("INSERT INTO account.auth_transactions(user_id,session_id,purpose,secret_hash,expires_at) VALUES (%s,%s,'reauth',%s,%s)",
                           (other,sid,str(uuid4()),sec.now()+timedelta(minutes=5)))
            else:
                db.execute("INSERT INTO account.auth_codes(id,user_id,purpose,channel,target,code_hash,expires_at) VALUES (%s,%s,'verify_contact','sms','+84912345678','test',%s)",
                           (cid,uid,sec.now()+timedelta(minutes=5)))
                db.execute("INSERT INTO account.auth_transactions(id,user_id,purpose,secret_hash,expires_at) VALUES (%s,%s,'reauth',%s,%s)",
                           (cid,uid,str(uuid4()),sec.now()+timedelta(minutes=5)))
            db.execute("SET LOCAL app.auth_025_approved='true'")
            with pytest.raises((psycopg.IntegrityError,psycopg.errors.RaiseException)):
                with db.transaction():
                    db.execute((Path(__file__).parents[1]/'migrations/025_auth_compact_codes.sql').read_text(encoding='utf-8'))
            assert code_storage.storage(db)[0]=='account.auth_codes'
            assert db.execute("SELECT to_regprocedure('account.valid_auth_devices(jsonb)') AS f").fetchone()['f'] is None
