import yaml
import json
from datetime import timedelta
from uuid import uuid4

import jwt
import pytest
from jsonschema import Draft202012Validator
from pathlib import Path

from app.core import security as sec
from app.core.config import settings
from app.features.auth import service
from app.features.auth import sms as sms_gateway
from .conftest import DEVICE,register_and_verify
from .test_auth import bearer,code,login,parallel


@pytest.mark.parametrize('field,size,valid',[
    ('displayName',1,True),('displayName',150,True),('displayName',151,False),
    ('username',3,False),('username',30,False),('username',31,False),
    ('password',5,False),('password',8,True),('password',64,True),('password',65,False)])
def test_length_boundaries(env,payload,field,size,valid):
    c,_,_=env
    payload[field]=('Aa1!'+'a'*(size-4)) if field=='password' else 'a'*size
    assert c.post('/api/v1/auth/register',json=payload).status_code==(201 if valid else 422)


@pytest.mark.parametrize('body', ['{bad', '[]','null'])
def test_malformed_body(env,body):
    r=env[0].post('/api/v1/auth/register',content=body,headers={'Content-Type':'application/json'})
    assert r.status_code==422 and code(r)=='VALIDATION_ERROR'


def test_consent_duplicates_and_unknown(env,payload):
    c,db,_=env
    for value in (False, 'true', 1, None):
        assert c.post('/api/v1/auth/register',json={**payload,'acceptedTerms':value}).status_code==422
    assert c.post('/api/v1/auth/register',json={**payload,'consents':[]}).status_code==422
    assert not db.execute('SELECT id FROM account.users').fetchone()


@pytest.mark.parametrize('field,value',[('email','PARENT@EXAMPLE.COM'),('phone','+84912345678')])
def test_each_unique_identifier_independently(env,payload,field,value):
    c,db,_=env
    data={k:v for k,v in payload.items() if k!='email'}
    data[field]='parent@example.com' if field=='email' else '0912345678'
    register_and_verify(env,data)
    assert code(c.post('/api/v1/auth/register',json={**data,field:value}))=='ACCOUNT_CONFLICT'
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n']==1


def test_registration_rolls_back_after_insert(env,payload,monkeypatch):
    def broken(db, parameters):
        raise RuntimeError('test rollback')
    monkeypatch.setattr(__import__('app.features.auth.code_storage',fromlist=['insert']), 'insert', lambda *a,**k:broken(None,None))
    with pytest.raises(RuntimeError,match='test rollback'):
        env[0].post('/api/v1/auth/register',json=payload)
    assert not env[1].execute('SELECT id FROM account.users').fetchone()
    assert not env[2]


def test_verify_rolls_back_activation_and_attempts_on_db_error(env,payload,monkeypatch):
    c,db,sms=env
    ch=c.post('/api/v1/auth/register',json=payload).json()
    body={k:ch[k] for k in ['verificationId','registrationToken']}
    body.update(code=sms[-1][1],device=DEVICE)
    original=service.new_session
    monkeypatch.setattr(service,'new_session',lambda *args:(_ for _ in ()).throw(RuntimeError('test rollback')))
    with pytest.raises(RuntimeError,match='test rollback'):c.post('/api/v1/auth/register/verify',json=body)
    assert db.execute('SELECT status FROM account.users').fetchone()['status']=='pending'
    assert db.execute('SELECT consumed_at FROM account.auth_transactions').fetchone()['consumed_at'] is None
    monkeypatch.setattr(service,'new_session',original)
    assert c.post('/api/v1/auth/register/verify',json=body).status_code==200


def test_exact_otp_and_challenge_expiry(env,payload,monkeypatch):
    c,db,sms=env
    ch=c.post('/api/v1/auth/register',json=payload).json()
    body={k:ch[k] for k in ['verificationId','registrationToken']}
    body.update(code=sms[-1][1],device=DEVICE)
    expiry=db.execute('SELECT expires_at FROM account.auth_transactions').fetchone()['expires_at']
    monkeypatch.setattr(sec,'now',lambda:expiry)
    assert code(c.post('/api/v1/auth/register/verify',json=body))=='OTP_EXPIRED'
    expiry=sec.now()+timedelta(minutes=31)
    monkeypatch.setattr(sec,'now',lambda:expiry)
    assert code(c.post('/api/v1/auth/register/verify',json=body))=='OTP_EXPIRED'


def test_cross_user_challenge(env,payload):
    c,db,sms=env
    a=c.post('/api/v1/auth/register',json=payload).json()
    payload.update(email='other@example.com')
    b=c.post('/api/v1/auth/register',json=payload).json()
    r=c.post('/api/v1/auth/register/verify',json={'verificationId':b['verificationId'],
      'registrationToken':a['registrationToken'],'code':sms[-1][1],'device':DEVICE})
    assert code(r)=='REGISTRATION_CHALLENGE_INVALID'
    assert all(u['status']=='pending' for u in db.execute('SELECT status FROM account.users'))


def test_send_quota_and_failed_delivery_count(env,payload,monkeypatch):
    c,db,_=env
    monkeypatch.setattr(sms_gateway,'send_sms',lambda *_:False)
    ch=c.post('/api/v1/auth/register',json=payload).json()
    start=sec.now()
    for i in range(1,5):
        db.execute("UPDATE account.auth_transactions SET created_at=now()-interval '61 seconds' WHERE id=%s",(ch['verificationId'],))
        r=c.post('/api/v1/auth/register/resend',json={k:ch[k] for k in ['verificationId','registrationToken']})
        assert r.status_code==200 and r.json()['deliveryStatus']=='failed'
        ch=r.json()
    db.execute("UPDATE account.auth_transactions SET created_at=now()-interval '61 seconds' WHERE id=%s",(ch['verificationId'],))
    r=c.post('/api/v1/auth/register/resend',json={k:ch[k] for k in ['verificationId','registrationToken']})
    assert r.status_code==429 and 'retry-after' in r.headers
    assert db.execute('SELECT count(*) n FROM account.auth_transactions').fetchone()['n']==5


@pytest.mark.parametrize('state,scheduled', [('pending','past'),('processing','future'),('pending','null')])
def test_deletion_not_cancelled_outside_window(env,payload,state,scheduled):
    c,db,_=env
    register_and_verify(env,payload)
    db.execute("UPDATE account.users SET status='pending_deletion'")
    when=None if scheduled=='null' else sec.now()+timedelta(days=1 if scheduled=='future' else -1)
    db.execute('INSERT INTO account.data_deletion_requests(user_id,status,scheduled_at) SELECT id,%s,%s FROM account.users',(state,when))
    assert code(login(c,payload))=='ACCOUNT_DELETION_IN_PROGRESS'
    assert db.execute('SELECT status FROM account.data_deletion_requests').fetchone()['status']==state


def test_login_cancel_deletion_rollback(env,payload,monkeypatch):
    c,db,_=env
    register_and_verify(env,payload)
    db.execute("UPDATE account.users SET status='pending_deletion'")
    db.execute("INSERT INTO account.data_deletion_requests(user_id,scheduled_at) SELECT id,now()+interval '1 day' FROM account.users")
    monkeypatch.setattr(service,'new_session',lambda *a:(_ for _ in ()).throw(RuntimeError('test rollback')))
    with pytest.raises(RuntimeError):login(c,payload)
    assert db.execute('SELECT status FROM account.users').fetchone()['status']=='pending_deletion'
    assert db.execute('SELECT status FROM account.data_deletion_requests').fetchone()['status']=='pending'


def test_jwt_claims_and_session_binding(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload)
    claims=jwt.decode(a['accessToken'],settings.auth_secret,algorithms=['HS256'],audience=settings.auth_audience)
    for updates in [{'aud':'admin'},{'iss':'other'},{'sub':str(uuid4())},{'sid':str(uuid4())},{'exp':sec.now()-timedelta(seconds=1)}]:
        token=jwt.encode({**claims,**updates},settings.auth_secret,algorithm='HS256')
        assert c.get('/api/v1/auth/me',headers={'Authorization':'Bearer '+token}).status_code==401


def test_push_session_linkage(env,payload):
    c,db,_=env
    a=register_and_verify(env,payload);b=login(c,payload).json()
    sessions=db.execute('SELECT id FROM account.user_sessions ORDER BY created_at').fetchall()
    db.execute("INSERT INTO account.device_tokens(user_id,fcm_token,platform,session_id) VALUES (%s,'fake-fcm','android',%s)", (a['user']['id'],sessions[1]['id']))
    c.post('/api/v1/auth/logout',json={'refreshToken':a['refreshToken']})
    assert db.execute('SELECT is_active FROM account.device_tokens').fetchone()['is_active']
    c.post('/api/v1/auth/logout',json={'refreshToken':b['refreshToken']})
    assert not db.execute('SELECT is_active FROM account.device_tokens').fetchone()['is_active']


def test_concurrent_verify_and_refresh_logout(env,payload):
    c,db,sms=env
    ch=c.post('/api/v1/auth/register',json=payload).json()
    body={k:ch[k] for k in ['verificationId','registrationToken']};body.update(code=sms[-1][1],device=DEVICE)
    responses=parallel([lambda client:client.post('/api/v1/auth/register/verify',json=body)]*2)
    assert sorted(r.status_code for r in responses)==[200,401]
    a=next(r.json() for r in responses if r.status_code==200)
    responses=parallel([lambda client:client.post('/api/v1/auth/refresh',json={'refreshToken':a['refreshToken']}),
                        lambda client:client.post('/api/v1/auth/logout',json={'refreshToken':a['refreshToken']})])
    assert responses[1].status_code==204
    assert c.get('/api/v1/auth/me',headers=bearer(a)).status_code==401


def test_actual_response_schemas(env,payload):
    # Resolve local refs only. No external schema fetches during tests.
    doc=yaml.safe_load((Path(__file__).parents[3]/'docs/api/mobile-auth.openapi.yaml').read_text(encoding='utf-8'))
    def resolve(value):
        if isinstance(value,dict):
            if '$ref' in value:return resolve(doc['components']['schemas'][value['$ref'].split('/')[-1]])
            return {k:resolve(v) for k,v in value.items()}
        if isinstance(value,list):return [resolve(v) for v in value]
        return value
    c,_,sms=env
    challenge=c.post('/api/v1/auth/register',json=payload)
    a=c.post('/api/v1/auth/register/verify',json={**{k:challenge.json()[k] for k in ['verificationId','registrationToken']},'code':sms[-1][1],'device':DEVICE})
    for response,name in [(challenge,'RegistrationChallenge'),(a,'AuthResult'),(c.get('/api/v1/auth/me',headers=bearer(a.json())),'User'),(c.post('/api/v1/auth/logout',json={}),'Error')]:
        Draft202012Validator(resolve(doc['components']['schemas'][name])).validate(response.json())
