import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from uuid import uuid4

import psycopg
import pytest

from app.core import security as sec
from app.core.config import settings
from app.features.auth import service
from app.features.auth import sms as sms_gateway
from .conftest import DEVICE,register_and_verify
from .test_auth import bearer,code,login,parallel


def contact_request(db,uid):
    admin=db.execute("INSERT INTO admin.admin_users(email,password_hash,full_name) VALUES (%s,'test-hash','Test Support') RETURNING id",('support-'+str(uuid4())+'@example.com',)).fetchone()['id']
    db.execute('''INSERT INTO account.contact_change_requests(user_id,new_email,verified_items,note,requested_by,effective_at)
        VALUES (%s,'recovered@example.com','["a","b","c"]','test recovery',%s,now()-interval '1 second')''',(uid,admin))


def test_recovery_invalidates_all_sessions(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload);b=login(c,payload).json()
    contact_request(db,a['user']['id'])
    assert db.execute('SELECT account.apply_due_contact_changes() n').fetchone()['n']==1
    for result in [a,b]:
        assert c.get('/api/v1/auth/me',headers=bearer(result)).status_code==401
        assert c.post('/api/v1/auth/refresh',json={'refreshToken':result['refreshToken']}).status_code==401
    u=db.execute('SELECT * FROM account.users').fetchone()
    assert u['email']=='recovered@example.com' and u['email_verified_at'] is None


def test_anonymize_cascades_new_auth_tables(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload)
    assert c.post('/api/v1/auth/refresh',json={'refreshToken':a['refreshToken']}).status_code==200
    db.execute('SELECT account.anonymize_user(%s)',(a['user']['id'],))
    for table in ['user_sessions','verification_codes','registration_challenges','refresh_token_history']:
        assert db.execute('SELECT count(*) n FROM account.'+table).fetchone()['n']==0
    assert db.execute('SELECT count(*) n FROM account.user_consents').fetchone()['n']==3


def test_login_races_due_anonymize(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload)
    db.execute("UPDATE account.users SET status='pending_deletion'")
    db.execute('INSERT INTO account.data_deletion_requests(user_id,scheduled_at) SELECT id,%s FROM account.users',(sec.now()-timedelta(seconds=1),))
    def anonymize(_):
        with psycopg.connect(settings.database_url) as conn:
            conn.execute('SELECT account.anonymize_user(%s)',(a['user']['id'],))
        return None
    responses=parallel([lambda client:login(client,payload),anonymize])
    assert responses[0].status_code in [401,403]
    assert db.execute('SELECT status FROM account.users').fetchone()['status']=='deleted'
    assert not db.execute('SELECT id FROM account.user_sessions').fetchone()


def test_refresh_races_recovery(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload)
    contact_request(db,a['user']['id'])
    def recover(_):
        with psycopg.connect(settings.database_url) as conn:conn.execute('SELECT account.apply_due_contact_changes()')
    responses=parallel([lambda client:client.post('/api/v1/auth/refresh',json={'refreshToken':a['refreshToken']}),recover])
    assert responses[0].status_code in [200,401]
    assert c.get('/api/v1/auth/me',headers=bearer(a)).status_code==401
    assert not db.execute('SELECT id FROM account.user_sessions').fetchone()


def test_login_races_recovery(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload)
    contact_request(db,a['user']['id'])
    def recover(_):
        with psycopg.connect(settings.database_url) as conn:
            conn.execute('SELECT account.apply_due_contact_changes()')
    responses=parallel([lambda client:login(client,payload),recover])
    assert responses[0].status_code in [200,401]
    assert db.execute('SELECT email FROM account.users').fetchone()['email']=='recovered@example.com'
    assert not db.execute('SELECT id FROM account.user_sessions').fetchone()
    if responses[0].status_code==200:
        assert c.get('/api/v1/auth/me',headers=bearer(responses[0].json())).status_code==401


def test_two_resends_at_same_cooldown(env,payload,monkeypatch):
    c,db,_=env
    ch=c.post('/api/v1/auth/register',json=payload).json()
    t=sec.now()+timedelta(seconds=61)
    monkeypatch.setattr(sec,'now',lambda:t)
    body={k:ch[k] for k in ['verificationId','registrationToken']}
    responses=parallel([lambda client:client.post('/api/v1/auth/register/resend',json=body)]*2)
    assert sorted(r.status_code for r in responses)==[200,429]
    assert db.execute("SELECT count(*) n FROM account.verification_codes WHERE expires_at>%s AND used_at IS NULL",(t,)).fetchone()['n']==1


def test_verify_races_resend(env,payload,monkeypatch):
    c,db,sms=env
    ch=c.post('/api/v1/auth/register',json=payload).json()
    t=sec.now();monkeypatch.setattr(sec,'now',lambda:t+timedelta(seconds=61))
    body={k:ch[k] for k in ['verificationId','registrationToken']}
    responses=parallel([
      lambda client:client.post('/api/v1/auth/register/verify',json={**body,'code':sms[-1][1],'device':DEVICE}),
      lambda client:client.post('/api/v1/auth/register/resend',json=body)])
    statuses=[r.status_code for r in responses]
    assert statuses in [[200,401],[410,200]]
    count=db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n']
    assert count==(1 if statuses[0]==200 else 0)


def test_shared_quota_across_processes(env):
    # Independent processes, not in-memory counters or a mocked repository.
    script='''import sys
from app.core.database import transaction
from app.core.config import settings
from app.features.auth.service import quota
settings.database_url=sys.argv[1]
with transaction() as db:
    error=quota(db,"cross-process-test",1,60)
    print(error.status_code if error else 200)
'''
    def call(_):
        result=subprocess.run([sys.executable,'-c',script,settings.database_url],capture_output=True,text=True,timeout=30)
        assert result.returncode==0,result.stderr
        return int(result.stdout.strip())
    with ThreadPoolExecutor(max_workers=2) as executor:statuses=list(executor.map(call,range(2)))
    assert sorted(statuses)==[200,429]


def test_login_limits_unknown_identity_and_unlock(env,payload,monkeypatch):
    c,db,_=env
    register_and_verify(env,payload)
    bad={**payload,'email':'unknown@example.com','password':'wrong'}
    for _ in range(5):assert login(c,bad).status_code==401
    assert code(login(c,bad))=='LOGIN_TEMPORARILY_LOCKED'
    bad={**payload,'password':'wrong'}
    for _ in range(5):assert login(c,bad).status_code==401
    t=sec.now();monkeypatch.setattr(sec,'now',lambda:t+timedelta(minutes=16))
    assert login(c,payload).status_code==200
    u=db.execute('SELECT failed_login_attempts,locked_until FROM account.users').fetchone()
    assert u['failed_login_attempts']==0 and u['locked_until'] is None


def test_ip_limit_shared_clients(env,payload):
    from fastapi.testclient import TestClient
    from app.main import app
    c,db,_=env
    with TestClient(app,client=('127.0.0.1',50001)) as second:
        for i in range(30):
            data={**payload,'email':f'unknown{i}@example.com'}
            assert login(c if i%2 else second,data).status_code==401
        assert code(login(second,payload))=='RATE_LIMITED'


def test_provider_adapter(monkeypatch):
    from app.features.auth import sms as sms_gateway
    monkeypatch.setattr(settings,'sms_webhook_url','https://sms.example.com/otp')
    monkeypatch.setattr(settings,'sms_webhook_token','secret-for-test')
    class Client:
        def __init__(self,**kwargs):assert kwargs['follow_redirects'] is False
        def __enter__(self):return self
        def __exit__(self,*args):pass
        def post(self,url,**kwargs):
            assert kwargs['headers']['Authorization']=='Bearer secret-for-test'
            assert kwargs['json']['to']=='+84912345678'
            return type('Result',(),{'status_code':202})()
    monkeypatch.setattr(sms_gateway.httpx,'Client',Client)
    assert sms_gateway.send_sms('+84912345678','345678')
    monkeypatch.setattr(settings,'sms_webhook_url','http://unsafe.example.com')
    assert not sms_gateway.send_sms('+84912345678','345678')
