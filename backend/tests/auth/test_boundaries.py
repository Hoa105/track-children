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
from .conftest import DEVICE,register_and_verify
from .test_auth import bearer,code,login,parallel


@pytest.mark.parametrize('field,size,valid',[
    ('fullName',1,True),('fullName',150,True),('fullName',151,False),
    ('username',3,True),('username',30,True),('username',31,False),
    ('password',9,False),('password',10,True),('password',128,True),('password',129,False)])
def test_length_boundaries(env,payload,field,size,valid):
    c,_,_=env
    payload[field]='a'*size
    assert c.post('/api/v1/auth/register',json=payload).status_code==(201 if valid else 422)


@pytest.mark.parametrize('body', ['{bad', '[]','null'])
def test_malformed_body(env,body):
    r=env[0].post('/api/v1/auth/register',content=body,headers={'Content-Type':'application/json'})
    assert r.status_code==422 and code(r)=='VALIDATION_ERROR'


def test_consent_duplicates_and_unknown(env,payload):
    c,db,_=env
    payload['consents'].append(payload['consents'][0])
    assert c.post('/api/v1/auth/register',json=payload).status_code==422
    payload['consents']=payload['consents'][:-1]+[{'documentId':str(uuid4()),'isAccepted':True}]
    assert code(c.post('/api/v1/auth/register',json=payload))=='LEGAL_CONSENT_REQUIRED'
    assert not db.execute('SELECT id FROM account.users').fetchone()


@pytest.mark.parametrize('field,value',[
    ('email','PARENT@EXAMPLE.COM'),('phone','+84912345678'),('username','PARENT_TEST')])
def test_each_unique_identifier_independently(env,payload,field,value):
    c,db,_=env
    assert c.post('/api/v1/auth/register',json=payload).status_code==201
    changed={**payload,'email':'new@example.com','phone':'0987654321','username':'new_parent'}
    changed[field]=value
    assert code(c.post('/api/v1/auth/register',json=changed))=='ACCOUNT_CONFLICT'
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n']==1


def test_registration_rolls_back_after_insert(env,payload,monkeypatch):
    original=service.one
    def broken(db,sql,args=()):
        if 'INSERT INTO account.verification_codes' in sql:raise RuntimeError('test rollback')
        return original(db,sql,args)
    monkeypatch.setattr(service,'one',broken)
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
    assert db.execute('SELECT used_at FROM account.verification_codes').fetchone()['used_at'] is None
    monkeypatch.setattr(service,'new_session',original)
    assert c.post('/api/v1/auth/register/verify',json=body).status_code==200


def test_exact_otp_and_challenge_expiry(env,payload,monkeypatch):
    c,db,sms=env
    ch=c.post('/api/v1/auth/register',json=payload).json()
    body={k:ch[k] for k in ['verificationId','registrationToken']}
    body.update(code=sms[-1][1],device=DEVICE)
    expiry=db.execute('SELECT expires_at FROM account.verification_codes').fetchone()['expires_at']
    monkeypatch.setattr(sec,'now',lambda:expiry)
    assert code(c.post('/api/v1/auth/register/verify',json=body))=='OTP_EXPIRED'
    expiry=db.execute('SELECT expires_at FROM account.registration_challenges').fetchone()['expires_at']
    monkeypatch.setattr(sec,'now',lambda:expiry)
    assert code(c.post('/api/v1/auth/register/verify',json=body))=='REGISTRATION_CHALLENGE_INVALID'


def test_cross_user_challenge(env,payload):
    c,db,sms=env
    a=c.post('/api/v1/auth/register',json=payload).json()
    payload.update(username='other_parent',email='other@example.com',phone='0987654321')
    b=c.post('/api/v1/auth/register',json=payload).json()
    r=c.post('/api/v1/auth/register/verify',json={'verificationId':b['verificationId'],
      'registrationToken':a['registrationToken'],'code':sms[-1][1],'device':DEVICE})
    assert code(r)=='REGISTRATION_CHALLENGE_INVALID'
    assert all(u['status']=='pending' for u in db.execute('SELECT status FROM account.users'))


def test_send_quota_and_failed_delivery_count(env,payload,monkeypatch):
    c,db,_=env
    monkeypatch.setattr(service,'send_sms',lambda *_:False)
    ch=c.post('/api/v1/auth/register',json=payload).json()
    start=sec.now()
    for i in range(1,5):
        monkeypatch.setattr(sec,'now',lambda i=i:start+timedelta(seconds=61*i))
        r=c.post('/api/v1/auth/register/resend',json={k:ch[k] for k in ['verificationId','registrationToken']})
        assert r.status_code==200 and r.json()['deliveryStatus']=='failed'
        ch=r.json()
    monkeypatch.setattr(sec,'now',lambda:start+timedelta(seconds=61*5))
    r=c.post('/api/v1/auth/register/resend',json={k:ch[k] for k in ['verificationId','registrationToken']})
    assert r.status_code==429 and 'retry-after' in r.headers
    assert db.execute('SELECT count(*) n FROM account.verification_codes').fetchone()['n']==5


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
    doc=json.loads((Path(__file__).parents[3]/'docs/api/mobile-auth.openapi.json').read_text(encoding='utf-8'))
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
