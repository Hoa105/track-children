from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier

import pytest
from fastapi.testclient import TestClient

from app.core import security as sec
from app.features.auth import service
from app.main import app
from .conftest import DEVICE,register_and_verify


def bearer(result):return {'Authorization':'Bearer '+result['accessToken']}
def login(client,payload,**kwargs):
    return client.post('/api/v1/auth/login',json={'email':payload['email'],'password':payload['password'],'device':DEVICE,**kwargs})
def code(response):return response.json()['error']['code']


def test_smoke_two_devices(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload)
    assert c.get('/api/v1/auth/me',headers=bearer(a)).json()['id']==a['user']['id']
    assert a['user']['emailVerifiedAt'] is None
    b=login(c,payload).json()
    r=c.post('/api/v1/auth/refresh',json={'refreshToken':a['refreshToken']})
    assert r.status_code==200 and r.headers['cache-control']=='no-store'
    new=r.json()
    assert new['refreshToken']!=a['refreshToken'] and new['sessionExpiresAt']==a['sessionExpiresAt']
    assert c.post('/api/v1/auth/logout',json={'refreshToken':new['refreshToken']}).status_code==204
    assert c.get('/api/v1/auth/me',headers=bearer(a)).status_code==401
    assert c.get('/api/v1/auth/me',headers=bearer(b)).status_code==200
    row=db.execute('SELECT password_hash FROM account.users').fetchone()
    assert row['password_hash'].startswith('$argon2id$') and payload['password'] not in row['password_hash']


@pytest.mark.parametrize('field,value',[('username','a'),('username','!invalid'),('password','short'),('fullName',' '),('email','bad'),('phone','000'),('relationship','admin')])
def test_validation(env,payload,field,value):
    c,db,_=env
    payload[field]=value
    r=c.post('/api/v1/auth/register',json=payload)
    assert r.status_code==422 and code(r)=='VALIDATION_ERROR'
    assert not db.execute('SELECT id FROM account.users').fetchone()


def test_normalization_conflict_consent(env,payload):
    c,db,_=env
    payload.update(username=' Parent_Test ',fullName=' Parent ')
    r=c.post('/api/v1/auth/register',json=payload)
    assert r.status_code==201
    u=db.execute('SELECT * FROM account.users').fetchone()
    assert (u['username'],u['full_name'],u['phone'])==('parent_test','Parent','+84912345678')
    payload['email']=payload['email'].upper()
    assert code(c.post('/api/v1/auth/register',json=payload))=='ACCOUNT_CONFLICT'
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n']==1


def test_consent_and_legal_versions(env,payload):
    c,db,_=env
    payload['consents']=[]
    assert code(c.post('/api/v1/auth/register',json=payload))=='LEGAL_CONSENT_REQUIRED'
    assert not db.execute('SELECT id FROM account.users').fetchone()
    db.execute("INSERT INTO account.legal_documents(doc_type,version,content,effective_at) VALUES ('terms','future','future',now()+interval '1 day')")
    docs=c.get('/api/v1/legal-documents?context=registration').json()['documents']
    assert all(d['version']=='1' for d in docs)
    db.execute("DELETE FROM account.legal_documents WHERE doc_type='privacy'")
    assert c.get('/api/v1/legal-documents?context=registration').status_code==503


def test_otp_attempts_expiry_and_replay(env,payload,monkeypatch):
    c,db,sms=env
    ch=c.post('/api/v1/auth/register',json=payload).json()
    body={k:ch[k] for k in ['verificationId','registrationToken']}
    body.update(device=DEVICE,code='wrong')
    assert c.post('/api/v1/auth/register/verify',json=body).status_code==422
    good=sms[-1][1];body['code']='000000' if good!='000000' else '000001'
    for remaining in range(4,-1,-1):
        r=c.post('/api/v1/auth/register/verify',json=body)
        assert r.status_code==400 and r.json()['error']['details']['attemptsRemaining']==remaining
    body['code']=good
    assert code(c.post('/api/v1/auth/register/verify',json=body))=='OTP_ATTEMPTS_EXCEEDED'
    assert db.execute('SELECT attempts FROM account.verification_codes').fetchone()['attempts']==5
    t=sec.now();monkeypatch.setattr(sec,'now',lambda:t+timedelta(seconds=61))
    r=c.post('/api/v1/auth/register/resend',json={k:ch[k] for k in ['verificationId','registrationToken']})
    assert r.status_code==200
    assert code(c.post('/api/v1/auth/register/verify',json=body))=='OTP_EXPIRED'
    ch=r.json();body.update(verificationId=ch['verificationId'],code=sms[-1][1])
    assert c.post('/api/v1/auth/register/verify',json=body).status_code==200
    assert code(c.post('/api/v1/auth/register/verify',json=body))=='REGISTRATION_CHALLENGE_INVALID'
    assert db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n']==1


def test_challenge_secret_and_resend_limit(env,payload):
    c,db,_=env
    ch=c.post('/api/v1/auth/register',json=payload).json()
    body={k:ch[k] for k in ['verificationId','registrationToken']}
    assert c.post('/api/v1/auth/register/resend',json=body).status_code==429
    body['registrationToken']='bad'
    assert code(c.post('/api/v1/auth/register/resend',json=body))=='REGISTRATION_CHALLENGE_INVALID'
    assert db.execute('SELECT attempts FROM account.verification_codes').fetchone()['attempts']==0


def test_pending_login_continues_and_sms_failure(env,payload,monkeypatch):
    c,db,_=env
    monkeypatch.setattr(service,'send_sms',lambda *_:False)
    ch=c.post('/api/v1/auth/register',json=payload).json()
    assert ch['deliveryStatus']=='failed'
    r=login(c,payload)
    assert r.status_code==403 and code(r)=='VERIFICATION_REQUIRED'
    new=r.json()['error']['details']['registration']
    assert new['deliveryStatus']=='deferred' and new['registrationToken']!=ch['registrationToken']
    assert not db.execute('SELECT id FROM account.user_sessions').fetchone()


@pytest.mark.parametrize('status', ['locked','pending_deletion'])
def test_account_state(env,payload,status):
    c,db,_=env
    a=register_and_verify(env,payload)
    db.execute('UPDATE account.users SET status=%s',(status,))
    assert c.get('/api/v1/auth/me',headers=bearer(a)).status_code==403
    assert c.post('/api/v1/auth/refresh',json={'refreshToken':a['refreshToken']}).status_code==403
    assert login(c,payload).status_code==403


def test_pending_deletion_cancel(env,payload):
    c,db,_=env
    register_and_verify(env,payload)
    db.execute("UPDATE account.users SET status='pending_deletion'")
    db.execute("INSERT INTO account.data_deletion_requests(user_id,scheduled_at) SELECT id,now()+interval '1 day' FROM account.users")
    r=login(c,payload)
    assert r.status_code==200 and r.json()['deletionRequestCancelled'] is True
    assert db.execute('SELECT status FROM account.data_deletion_requests').fetchone()['status']=='cancelled'


def test_reuse_and_logout_idempotent(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload)
    assert c.post('/api/v1/auth/refresh',json={'refreshToken':a['refreshToken']}).status_code==200
    assert code(c.post('/api/v1/auth/refresh',json={'refreshToken':a['refreshToken']}))=='REFRESH_TOKEN_REUSED'
    assert c.get('/api/v1/auth/me',headers=bearer(a)).status_code==401
    for token in [a['refreshToken'],'unknown']:
        r=c.post('/api/v1/auth/logout',json={'refreshToken':token})
        assert r.status_code==204 and not r.content


def test_password_lockout(env,payload):
    c,db,_=env
    register_and_verify(env,payload)
    wrong={**payload,'password':'wrong-password'}
    for _ in range(5):assert login(c,wrong).status_code==401
    r=login(c,payload)
    assert r.status_code==429 and 'retry-after' in r.headers
    assert db.execute('SELECT locked_until FROM account.users').fetchone()['locked_until'] is not None


def test_bearer_validation_and_anonymize(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload)
    for raw in ['', 'Basic bad','Bearer invalid']:
        r=c.get('/api/v1/auth/me',headers={'Authorization':raw})
        assert r.status_code==401 and r.headers['www-authenticate']=='Bearer'
    db.execute('SELECT account.anonymize_user(%s)',(a['user']['id'],))
    assert c.get('/api/v1/auth/me',headers=bearer(a)).status_code==401
    assert not db.execute('SELECT id FROM account.user_sessions').fetchone()
    assert login(c,payload).status_code==401


@pytest.mark.parametrize('remember,days',[(False,1),(True,30)])
def test_absolute_session_expiry(env,payload,remember,days):
    c,db,_=env
    a=register_and_verify(env,payload,remember)
    row=db.execute('SELECT * FROM account.user_sessions').fetchone()
    assert abs((row['expires_at']-row['created_at']).total_seconds()-days*86400)<5
    db.execute('UPDATE account.user_sessions SET expires_at=%s',(sec.now()-timedelta(seconds=1),))
    assert code(c.post('/api/v1/auth/refresh',json={'refreshToken':a['refreshToken']}))=='SESSION_EXPIRED'


def parallel(requests):
    barrier=Barrier(len(requests))
    def run(f):
        with TestClient(app,client=('127.0.0.1',50000)) as client:
            barrier.wait(timeout=10)
            return f(client)
    with ThreadPoolExecutor(max_workers=len(requests)) as executor:return list(executor.map(run,requests))


def test_concurrent_refresh(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload)
    responses=parallel([lambda client:client.post('/api/v1/auth/refresh',json={'refreshToken':a['refreshToken']})]*2)
    assert sorted(r.status_code for r in responses)==[200,401]
    assert db.execute('SELECT revoked_at FROM account.user_sessions').fetchone()['revoked_at']


def test_concurrent_register(env,payload):
    _,db,_=env
    responses=parallel([lambda client:client.post('/api/v1/auth/register',json=payload)]*2)
    assert sorted(r.status_code for r in responses)==[201,409]
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n']==1
