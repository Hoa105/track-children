"""Legacy API storage compatibility on the current dedicated test schema; no DDL."""
from datetime import timedelta
from pathlib import Path
import sys
from types import SimpleNamespace
from uuid import uuid4, UUID

import psycopg
from psycopg.rows import dict_row

from app.core.config import settings
from app.core import security as sec
from app.features.auth import registration, code_storage
from app.features.auth.errors import AuthFailure
from app.features.auth.schemas import Device

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from prepare_auth_v2_test_db import test_url as dedicated_test_url, TEST_DB


def test_legacy_issue_resend_bad_otp_verify_and_replay_without_schema_changes(monkeypatch):
    monkeypatch.setattr(settings,'app_env','local')
    monkeypatch.setattr(settings,'auth_otp_preview',True)
    monkeypatch.setattr(settings,'auth_secret','compat-test-secret-not-for-production-123456789')
    monkeypatch.setattr(settings,'auth_v2_enabled',True)
    with psycopg.connect(dedicated_test_url(),row_factory=dict_row,autocommit=True) as db:
        assert db.execute('SELECT current_database() AS name').fetchone()['name']==TEST_DB
        with db.transaction(force_rollback=True):
            uid=uuid4()
            user=db.execute("INSERT INTO account.users(id,email,password_hash) VALUES (%s,%s,'test-only') RETURNING *",
                            (uid,str(uid)+'@example.com')).fetchone()
            first,_=registration.issue(db,user)
            assert first['requiresOtp'] and first['deliveryStatus']=='preview'
            blocked,_=registration.issue(db,user)
            assert isinstance(blocked,AuthFailure)
            table,_=code_storage.storage(db)
            # Move only this fixture's cooldown back; do not change JWT/server clock.
            db.execute(f'UPDATE {table} SET created_at=%s WHERE id=%s',
                       (sec.now()-timedelta(seconds=61),first['verificationId']))
            challenge=SimpleNamespace(verificationId=UUID(first['verificationId']),
                registrationToken=first['registrationToken'])
            latest,_=registration.resend(db,challenge,'127.0.0.1')
            assert latest['verificationId']!=first['verificationId']
            assert isinstance(registration.subject(db,challenge),AuthFailure)
            challenge.verificationId=UUID(latest['verificationId'])
            challenge.registrationToken=latest['registrationToken']
            challenge.device=Device(platform='ios',deviceId='compat-test')
            challenge.rememberMe=True
            challenge.code='000000' if latest['devOtp']!='000000' else '111111'
            assert isinstance(registration.verify(db,challenge,'127.0.0.1'),AuthFailure)
            row=db.execute(f'SELECT attempt_count FROM {table} WHERE id=%s',(latest['verificationId'],)).fetchone()
            assert row['attempt_count']==1
            challenge.code=latest['devOtp']
            result=registration.verify(db,challenge,'127.0.0.1')
            assert str(result['user']['id'])==str(uid)
            assert isinstance(registration.verify(db,challenge,'127.0.0.1'),AuthFailure)
            assert db.execute('SELECT count(*) AS n FROM account.user_sessions WHERE user_id=%s',(uid,)).fetchone()['n']==1
