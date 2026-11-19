"""Approved dedicated PostgreSQL integration tests; never use the application DB."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timedelta,timezone
from pathlib import Path
from uuid import uuid4
import sys
import pytest
import psycopg
from psycopg.rows import dict_row
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.core.config import settings
from app.core import security as sec
from app.features.auth import social,sms,validation,rate_limit
from app.features.auth.setup import install_auth
from app.features.auth.recovery import risk_reasons

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from prepare_auth_v2_test_db import test_url as dedicated_test_url,TEST_DB

DEVICE={'platform':'android','deviceId':'known-test-device'}
PREFIX='/api/v1/auth/v2'
REAL_SMS_SEND=sms.send_code

@pytest.fixture
def simulated_env(env,monkeypatch):
    from app.features.auth import simulation
    monkeypatch.setattr(settings,'auth_simulation',True)
    monkeypatch.setattr(sms,'send_code',REAL_SMS_SEND)
    monkeypatch.setattr(simulation,'_delivery_fails',False)
    simulation._messages.clear()
    return env


def test_simulation_config_rejects_production_and_app_database():
    from app.core.config import Settings
    for mode,url in [('production','postgresql://test@localhost/auth_test'),('local','postgresql://test@localhost/track_children')]:
        with pytest.raises(ValueError):
            Settings(_env_file=None,app_env=mode,database_url=url,auth_simulation=True)


def test_simulation_routes_hidden_when_disabled(env):
    assert env[0].get('/api/v1/auth/testing/outbox').status_code==404


def test_simulation_real_signup_and_recovery_with_outbox(simulated_env):
    c,db,_,phone,_=simulated_env
    grant=c.post(PREFIX+'/signup/start',json={'phone':phone,'device':DEVICE}).json()
    messages=c.get('/api/v1/auth/testing/outbox').json()['messages']
    assert messages[0]['kind']=='otp' and messages[0]['target']==phone
    verified_grant=c.post(PREFIX+'/signup/verify',json={**ticket(grant),'code':messages[0]['code']}).json()
    result=complete(simulated_env,verified_grant)
    assert result.status_code==200,result.text
    reset=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':DEVICE}).json()
    code=c.get('/api/v1/auth/testing/outbox').json()['messages'][0]['code']
    verified_reset=c.post(PREFIX+'/recovery/verify',json={**ticket(reset),'code':code,'device':DEVICE})
    assert verified_reset.status_code==200,verified_reset.text
    assert not verified_reset.json()['requiresAdditionalVerification']
    result=c.post(PREFIX+'/recovery/complete',json={**ticket(reset),'newPassword':'New!pass789','confirmPassword':'New!pass789'})
    assert result.status_code==200,result.text
    assert any(m['kind']=='security-notice' for m in c.get('/api/v1/auth/testing/outbox').json()['messages'])


def test_simulation_failure_and_wrong_proof_stay_blocked(simulated_env,monkeypatch):
    from app.features.auth import simulation
    c,_,_,phone,_=simulated_env
    monkeypatch.setattr(simulation,'_delivery_fails',True)
    result=c.post(PREFIX+'/signup/start',json={'phone':phone,'device':DEVICE})
    assert result.status_code==503,result.text
    assert not c.get('/api/v1/auth/testing/outbox').json()['messages']
    challenge=c.post('/api/v1/auth/social/apple/challenge').json()
    proof=c.post('/api/v1/auth/testing/provider',json={'provider':'apple','nonce':'wrong-nonce'}).json()
    result=c.post(PREFIX+'/social/start',json={'provider':'apple','idToken':proof['idToken'],
        'authorizationCode':proof['authorizationCode'],'challenge':challenge['challenge'],'device':DEVICE})
    assert result.status_code==401,result.text


@pytest.mark.parametrize('provider',['google','apple'])
def test_simulated_provider_new_existing_reauth_setup_and_delete(simulated_env,provider):
    c,db,_,phone,_=simulated_env;account_id='t'+phone[-7:]
    def credential():
        challenge=c.post('/api/v1/auth/social/apple/challenge').json() if provider=='apple' else {}
        value=c.post('/api/v1/auth/testing/provider',json={'provider':provider,'account':account_id,'nonce':challenge.get('nonce')}).json()
        return {**value,'provider':provider,'device':DEVICE,**({'challenge':challenge['challenge']} if challenge else {})}
    def start_body(proof):return {k:v for k,v in proof.items() if k not in ('email',)}
    start=c.post(PREFIX+'/social/start',json=start_body(credential()))
    assert start.status_code==200,start.text
    grant=start.json()
    result=c.post(PREFIX+'/social/complete',json={**ticket(grant),'documentsDigest':grant['documentsDigest'],
        'displayName':'Nguyễn Thị Ánh','defaultRelationship':'mother','acceptedTerms':True,'device':DEVICE})
    assert result.status_code==200,result.text
    session=result.json()
    again=c.post(PREFIX+'/social/start',json=start_body(credential()))
    assert again.status_code==200 and again.json()['isNewUser'] is False
    grant=c.post(PREFIX+'/reauth',headers=headers(session),json={'action':'set_password','providerCredential':start_body(credential())})
    assert grant.status_code==200,grant.text
    result=c.post(PREFIX+'/password/setup',headers=headers(session),json={**ticket(grant.json()),'newPassword':'New!pass789','confirmPassword':'New!pass789','device':DEVICE})
    assert result.status_code==200,result.text
    session=result.json()
    grant=c.post(PREFIX+'/reauth',headers=headers(session),json={'action':'delete_account','currentPassword':'New!pass789'}).json()
    result=c.post(PREFIX+'/account/delete',headers=headers(session),json={**ticket(grant),
        **({'appleCredential':start_body(credential())} if provider=='apple' else {})})
    assert result.status_code==200,result.text
    db.execute('DELETE FROM account.users WHERE id=%s',(session['user']['id'],))

@pytest.fixture
def env(monkeypatch,tmp_path):
    assert TEST_DB.endswith('_test')
    url=dedicated_test_url()
    with psycopg.connect(url,row_factory=dict_row) as db:
        if not db.execute("SELECT to_regclass('account.auth_transactions') AS t").fetchone()['t']:
            pytest.skip('Apply approved test migrations 023/024 first')
        if not db.execute("SELECT 1 FROM information_schema.columns WHERE table_schema='account' AND table_name='users' AND column_name='auth_known_devices'").fetchone():
            pytest.skip('Apply approved compaction migration 024 first')
    block=tmp_path/'blocked.txt'
    block.write_text('password123\n12345678\n',encoding='utf-8')
    monkeypatch.setattr(settings,'database_url',url)
    monkeypatch.setattr(settings,'auth_v2_enabled',True)
    monkeypatch.setattr(settings,'app_env','local')
    monkeypatch.setattr(settings,'auth_secret','unit-test-secret-not-for-production-123456789')
    monkeypatch.setattr(settings,'auth_otp_secret','unit-test-otp-secret-not-for-production-12345')
    monkeypatch.setattr(settings,'auth_password_blocklist_path',str(block))
    monkeypatch.setattr(settings,'auth_rate_limit_path',str(tmp_path/'limits.sqlite3'))
    monkeypatch.setattr(settings,'legal_documents_path',str(Path(__file__).resolve().parents[1]/'legal-documents.local.json'))
    monkeypatch.setattr(settings,'sms_webhook_url','https://sms.test.invalid')
    monkeypatch.setattr(settings,'sms_webhook_token','test-only')
    monkeypatch.setattr(settings,'auth_otp_preview',False)
    clock=[sec.now()]
    monkeypatch.setattr(sec,'now',lambda:clock[0])
    monkeypatch.setattr(rate_limit.time,'time',lambda:clock[0].timestamp())
    sent=[]
    monkeypatch.setattr(sms,'send_code',lambda channel,target,code: sent.append((channel,target,code)) or True)
    app=FastAPI();install_auth(app)
    phone='+8491'+f'{uuid4().int%10000000:07d}'
    with TestClient(app) as client,psycopg.connect(url,row_factory=dict_row,autocommit=True) as db:
        yield client,db,sent,phone,clock
        # Delete only synthetic identities created by this run, inside the guarded test DB.
        db.execute('DELETE FROM account.users WHERE phone=%s OR email LIKE %s',(phone,'%'+phone[-7:]+'@example.com'))

def ticket(result):
    return {k:result[k] for k in ('transactionId','transactionToken')}

def start(env):
    client,db,sent,phone,_=env
    response=client.post(PREFIX+'/signup/start',json={'phone':phone,'device':DEVICE})
    assert response.status_code==200,response.text
    return response.json()

def verified(env):
    c,_,sent,_,_=env
    value=start(env)
    response=c.post(PREFIX+'/signup/verify',json={**ticket(value),'code':sent[-1][2]})
    assert response.status_code==200,response.text
    return response.json()

def complete(env,grant=None,**overrides):
    c,_,_,_,_=env
    grant=grant or verified(env)
    body={**ticket(grant),'password':'Q7!m2#Zx','confirmPassword':'Q7!m2#Zx',
      'displayName':'Nguyễn Thị Ánh','defaultRelationship':'mother','acceptedTerms':True,
      'documentsDigest':grant['documentsDigest'],'device':DEVICE}
    return c.post(PREFIX+'/signup/complete',json={**body,**overrides})

def account(env):
    response=complete(env)
    assert response.status_code==200,response.text
    return response.json()

def headers(value):return {'Authorization':'Bearer '+value['accessToken']}

def reauth(env,value,action,**extra):
    result=env[0].post(PREFIX+'/reauth',headers=headers(value),json={'action':action,'currentPassword':'Q7!m2#Zx',**extra})
    assert result.status_code==200,result.text
    return result.json()


def test_provider_link_unlink_no_auto_merge_and_single_use(env,monkeypatch):
    c,db,_,phone,clock=env;value=account(env)
    monkeypatch.setattr(social,'verify_identity',lambda data:{'sub':'link-'+phone,'iat':int(clock[0].timestamp())})
    credential={'provider':'google','idToken':'fixture','device':DEVICE}
    grant=reauth(env,value,'link_google')
    body={**ticket(grant),'credential':credential}
    result=c.post(PREFIX+'/providers/link',headers=headers(value),json=body)
    assert result.status_code==200,result.text
    assert c.post(PREFIX+'/providers/link',headers=headers(value),json=body).status_code==401
    assert c.get(PREFIX+'/security',headers=headers(value)).json()['providers']==['google']
    grant=reauth(env,value,'unlink_google')
    assert c.post(PREFIX+'/providers/unlink',headers=headers(value),json={**ticket(grant),'provider':'google'}).status_code==200
    assert not db.execute('SELECT 1 FROM account.social_identities WHERE user_id=%s',(value['user']['id'],)).fetchone()


def test_unlink_cannot_remove_last_login_method(env,monkeypatch):
    c,db,_,phone,clock=env;value=account(env)
    db.execute("UPDATE account.users SET password_hash='!social' WHERE id=%s",(value['user']['id'],))
    db.execute('INSERT INTO account.social_identities(provider,subject,user_id) VALUES (%s,%s,%s)',('google','last-'+phone,value['user']['id']))
    monkeypatch.setattr(social,'verify_identity',lambda data:{'sub':'last-'+phone,'iat':int(clock[0].timestamp())})
    proof={'provider':'google','idToken':'fixture','device':DEVICE}
    grant=c.post(PREFIX+'/reauth',headers=headers(value),json={'action':'unlink_google','providerCredential':proof}).json()
    result=c.post(PREFIX+'/providers/unlink',headers=headers(value),json={**ticket(grant),'provider':'google'})
    assert result.status_code==409 and result.json()['error']['code']=='LAST_LOGIN_METHOD'


def test_legacy_unverified_can_login_but_must_verify_before_password_change(env):
    c,db,_,phone,_=env;value=account(env)
    db.execute('UPDATE account.users SET phone_verified_at=NULL WHERE phone=%s',(phone,))
    result=c.post('/api/v1/auth/login',json={'phone':phone,'password':'Q7!m2#Zx','device':DEVICE})
    assert result.status_code==200,result.text
    state=c.get(PREFIX+'/security',headers=headers(result.json())).json()
    assert state['requiresIdentifierVerification']
    result=c.post(PREFIX+'/password/change',headers=headers(value),json={'currentPassword':'Q7!m2#Zx','newPassword':'New!pass789','confirmPassword':'New!pass789','device':DEVICE})
    assert result.status_code==403


def test_delete_anonymizes_user_revokes_sessions_and_preserves_receipts(env):
    c,db,_,phone,_=env;value=account(env);uid=value['user']['id']
    grant=reauth(env,value,'delete_account')
    result=c.post(PREFIX+'/account/delete',headers=headers(value),json=ticket(grant))
    assert result.status_code==200,result.text
    user=db.execute('SELECT * FROM account.users WHERE id=%s',(uid,)).fetchone()
    assert user['status']=='deleted' and user['phone'] is None and user['email'] is None
    assert not user['auth_known_devices']
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==401
    assert db.execute('SELECT count(*) AS n FROM account.auth_consent_receipts WHERE user_id=%s',(uid,)).fetchone()['n']==1
    db.execute('DELETE FROM account.users WHERE id=%s',(uid,))


def test_delete_blocks_owned_child_without_altering_data(env):
    c,db,_,_,_=env;value=account(env);uid=value['user']['id']
    child=db.execute("INSERT INTO child.children(owner_user_id,full_name,date_of_birth,gender) VALUES (%s,'Test child','2025-01-01','female') RETURNING id",(uid,)).fetchone()['id']
    try:
        grant=reauth(env,value,'delete_account')
        result=c.post(PREFIX+'/account/delete',headers=headers(value),json=ticket(grant))
        assert result.status_code==409 and result.json()['error']['code']=='CHILD_OWNERSHIP_REQUIRED'
        assert db.execute('SELECT owner_user_id FROM child.children WHERE id=%s',(child,)).fetchone()['owner_user_id']==__import__('uuid').UUID(uid)
        assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==200
    finally:db.execute('DELETE FROM child.children WHERE id=%s',(child,))


def test_apple_revoke_failure_preserves_app_account(env,monkeypatch):
    from app.features.auth.errors import failure
    c,db,_,phone,clock=env;value=account(env)
    db.execute('INSERT INTO account.social_identities(provider,subject,user_id) VALUES (%s,%s,%s)',('apple','delete-'+phone,value['user']['id']))
    monkeypatch.setattr(social,'verify_identity',lambda _:{'sub':'delete-'+phone,'iat':int(clock[0].timestamp())})
    monkeypatch.setattr(social,'revoke_apple',lambda _:failure(503,'SOCIAL_PROVIDER_UNAVAILABLE'))
    grant=reauth(env,value,'delete_account')
    body={**ticket(grant),'appleCredential':{'provider':'apple','idToken':'test','challenge':str(uuid4()),'authorizationCode':'test-code','device':DEVICE}}
    result=c.post(PREFIX+'/account/delete',headers=headers(value),json=body)
    assert result.status_code==503,result.text
    assert db.execute('SELECT status FROM account.users WHERE id=%s',(value['user']['id'],)).fetchone()['status']=='active'
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==200


def test_postgres_limiter_atomic_across_workers_and_clear(env,monkeypatch):
    monkeypatch.setattr(settings,'auth_rate_limit_backend','postgres')
    key='multi-worker-'+str(uuid4())
    with ThreadPoolExecutor(max_workers=8) as pool:
        results=list(pool.map(lambda _:rate_limit.consume(key,5,60),range(12)))
    assert sum(result is None for result in results)==5
    assert sum(result is not None for result in results)==7
    rate_limit.clear(key)
    assert rate_limit.consume(key,5,60) is None


def test_authenticated_activity_prevents_false_inactivity(env):
    c,db,_,phone,clock=env;value=account(env)
    db.execute('UPDATE account.users SET last_login_at=%s WHERE phone=%s',(clock[0]-timedelta(days=89),phone))
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==200
    assert db.execute('SELECT last_login_at FROM account.users WHERE phone=%s',(phone,)).fetchone()['last_login_at']==clock[0]


def test_approved_auth_retention_prunes_devices_and_deleted_consent_only(env,monkeypatch):
    from psycopg.types.json import Jsonb
    from app.features.auth import maintenance,recovery,notices
    c,db,_,phone,clock=env;value=account(env);uid=value['user']['id']
    monkeypatch.setattr(recovery,'process_pending',lambda **kw:0)
    monkeypatch.setattr(notices,'process_pending',lambda **kw:0)
    device=[{'hash':sec.secret_hash('old'),'lastAuthenticatedAt':(clock[0]-timedelta(days=90)).isoformat()},
            {'hash':sec.secret_hash('current'),'lastAuthenticatedAt':clock[0].isoformat()}]
    db.execute('UPDATE account.users SET auth_known_devices=%s WHERE id=%s',(Jsonb(device),uid))
    maintenance.main()
    user=db.execute('SELECT * FROM account.users WHERE id=%s',(uid,)).fetchone()
    assert [entry['hash'] for entry in user['auth_known_devices']]==[sec.secret_hash('current')]
    assert db.execute('SELECT count(*) AS n FROM account.auth_consent_receipts WHERE user_id=%s',(uid,)).fetchone()['n']==1
    db.execute("UPDATE account.users SET status='deleted',deleted_at=%s::timestamptz-interval '3 years' WHERE id=%s",(clock[0],uid))
    maintenance.main()
    assert db.execute('SELECT count(*) AS n FROM account.auth_consent_receipts WHERE user_id=%s',(uid,)).fetchone()['n']==0


def test_worker_health_uses_recent_success_without_secrets(env):
    import json
    from app.features.auth import worker
    from datetime import datetime,timezone
    path=worker.heartbeat_path()
    assert not worker.healthy()
    path.write_text(json.dumps({'lastSuccess':datetime.now(timezone.utc).isoformat()}),encoding='utf-8')
    assert worker.healthy()
    path.write_text(json.dumps({'lastSuccess':(datetime.now(timezone.utc)-timedelta(minutes=10)).isoformat()}),encoding='utf-8')
    assert not worker.healthy()


def test_bundled_blocklist_has_verified_provenance_and_rejects_common_passwords(env,monkeypatch):
    import hashlib,json
    from app.features.auth import transactions
    path=Path(__file__).resolve().parents[1]/'data'/'auth'/'common-passwords.txt'
    manifest=json.loads(path.with_name('blocklist-manifest.json').read_text(encoding='utf-8'))
    assert manifest['entries']>=10000
    assert hashlib.sha256(path.read_bytes()).hexdigest()==manifest['sha256']
    monkeypatch.setattr(settings,'auth_password_blocklist_path',str(path))
    monkeypatch.setattr(settings,'app_env','production')
    assert transactions.ready() is None
    for password in ('password123','Password123','belonkhon123'):
        with pytest.raises(ValueError):validation.password(password)


def test_security_notice_is_durable_has_no_secret_and_retries(env,monkeypatch):
    from app.features.auth import notices
    c,db,_,phone,clock=env;value=account(env)
    result=c.post(PREFIX+'/password/change',headers=headers(value),json={'currentPassword':'Q7!m2#Zx','newPassword':'New!pass789','confirmPassword':'New!pass789','device':DEVICE})
    assert result.status_code==200,result.text
    row=db.execute("SELECT * FROM account.auth_transactions WHERE user_id=%s AND metadata ? 'notice'",(value['user']['id'],)).fetchone()
    assert row['metadata']['notice']['contacts']==[{'channel':'sms','target':phone}]
    assert 'New!pass789' not in str(row) and 'Q7!m2#Zx' not in str(row)
    monkeypatch.setattr(settings,'auth_security_webhook_url','https://notice.test.invalid')
    monkeypatch.setattr(settings,'auth_security_webhook_token','test-only')
    calls=[]
    class Client:
        def __init__(self,**kw):pass
        def __enter__(self):return self
        def __exit__(self,*args):pass
        def post(self,url,**kw):
            from types import SimpleNamespace
            calls.append(kw)
            return SimpleNamespace(status_code=503 if len(calls)==1 else 202)
    monkeypatch.setattr(notices.httpx,'Client',Client)
    notices.process_pending();assert len(calls)==1
    notices.process_pending();assert len(calls)==1
    clock[0]+=timedelta(seconds=60);notices.process_pending()
    assert calls[0]['headers']['Idempotency-Key']==calls[1]['headers']['Idempotency-Key']
    assert db.execute('SELECT metadata FROM account.auth_transactions WHERE id=%s',(row['id'],)).fetchone()['metadata']['notice']['state']=='delivered'


@pytest.mark.parametrize('variant',['valid','duplicate','wrong_audience','bad_signature','future_event','string_events','email_disabled','email_enabled'])
def test_apple_signed_revoke_events(env,monkeypatch,variant):
    import jwt,json
    from types import SimpleNamespace
    from cryptography.hazmat.primitives.asymmetric import rsa
    c,db,_,phone,clock=env;value=account(env)
    db.execute('INSERT INTO account.social_identities(provider,subject,user_id) VALUES (%s,%s,%s)',('apple','apple-'+phone,value['user']['id']))
    key=rsa.generate_private_key(public_exponent=65537,key_size=2048);public=key.public_key()
    monkeypatch.setattr(settings,'apple_client_ids',['test-apple'])
    monkeypatch.setattr(social,'keys',lambda _:SimpleNamespace(get_signing_key_from_jwt=lambda _:SimpleNamespace(key=public)))
    stamp=int(clock[0].timestamp())
    event={'type':'consent-revoked','sub':'apple-'+phone,'event_time':stamp+1}
    if variant in ('email_disabled','email_enabled'):
        email=phone[1:]+'@privaterelay.appleid.com'
        db.execute('UPDATE account.users SET email=%s,email_verified_at=%s WHERE id=%s',(email,None if variant=='email_enabled' else clock[0],value['user']['id']))
        event.update(type=variant.replace('_','-'),email=email)
    if variant=='future_event':event['event_time']=stamp+1000
    claims={'iss':'https://appleid.apple.com','aud':'wrong' if variant=='wrong_audience' else 'test-apple','iat':stamp,'jti':str(uuid4()),'events':json.dumps(event) if variant=='string_events' else event}
    if variant=='bad_signature':key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    payload={'payload':jwt.encode(claims,key,algorithm='RS256')}
    result=c.post(PREFIX+'/providers/apple/events',json=payload)
    valid=variant in ('valid','duplicate','string_events','email_disabled','email_enabled')
    assert result.status_code==(200 if valid else 401),result.text
    if variant=='duplicate':assert c.post(PREFIX+'/providers/apple/events',json=payload).status_code==200
    assert db.execute('SELECT status FROM account.users WHERE id=%s',(value['user']['id'],)).fetchone()['status']=='active'
    revoked=valid and variant not in ('email_disabled','email_enabled')
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==(401 if revoked else 200)
    if variant in ('email_disabled','email_enabled'):
        from app.features.auth.notices import relay_disabled
        assert relay_disabled(db,value['user']['id'],email) is (variant=='email_disabled')

def test_signup_creates_no_user_before_completion(env):
    c,db,_,phone,_=env
    grant=verified(env)
    assert db.execute('SELECT id FROM account.users WHERE phone=%s',(phone,)).fetchone() is None
    result=complete(env,grant)
    assert result.status_code==200,result.text
    user=result.json()['user']
    assert user['phoneVerifiedAt'] and user['email'] is None and user['displayName']=='Nguyễn Thị Ánh'
    assert db.execute('SELECT count(*) AS n FROM account.auth_consent_receipts WHERE user_id=%s',(user['id'],)).fetchone()['n']==1
    replay=complete(env,grant)
    assert replay.status_code==200 and replay.json()['requiresLogin']
    assert 'accessToken' not in replay.json()
    assert complete(env,grant,displayName='Different request').status_code==401

def test_signup_bypass_wrong_purpose_and_consent(env):
    c,db,_,phone,_=env
    value=start(env)
    assert complete(env,value).status_code==401
    grant=c.post(PREFIX+'/signup/verify',json={**ticket(value),'code':env[2][-1][2]}).json()
    assert complete(env,grant,acceptedTerms=False).status_code==422
    assert complete(env,grant,documentsDigest='0'*64).status_code==409
    assert db.execute('SELECT id FROM account.users WHERE phone=%s',(phone,)).fetchone() is None
    assert c.post(PREFIX+'/social/complete',json={**ticket(grant),'displayName':'Test',
      'defaultRelationship':'mother','acceptedTerms':True,'documentsDigest':grant['documentsDigest'],'device':DEVICE}).status_code==401

def test_otp_limits_expiry_resend_and_no_user(env):
    c,db,sent,phone,clock=env
    value=start(env);old=sent[-1][2]
    assert c.post(PREFIX+'/signup/resend',json=ticket(value)).status_code==429
    clock[0]+=timedelta(seconds=60)
    response=c.post(PREFIX+'/signup/resend',json=ticket(value));assert response.status_code==200,response.text
    fresh=sent[-1][2]
    if old!=fresh:
        assert c.post(PREFIX+'/signup/verify',json={**ticket(value),'code':old}).status_code==400
    for _ in range(5):
        c.post(PREFIX+'/signup/verify',json={**ticket(value),'code':'999999' if fresh!='999999' else '888888'})
    assert c.post(PREFIX+'/signup/verify',json={**ticket(value),'code':fresh}).status_code==429
    clock[0]+=timedelta(seconds=301)
    assert c.post(PREFIX+'/signup/verify',json={**ticket(value),'code':fresh}).status_code==401
    assert c.post(PREFIX+'/signup/resend',json=ticket(value)).status_code==200

def test_signup_concurrent_commit_only_once(env):
    grant=verified(env)
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(lambda _:complete(env,grant),range(2)))
    assert [r.status_code for r in results]==[200,200]
    assert sum('accessToken' in r.json() for r in results)==1

@pytest.mark.parametrize('value',['1234567','A'*65,'Matkhẩu8!','Đangnhap8!','abcdefgh\n','abcd efgh','abc😀defgh','abcdefg\x00','password123'])
def test_password_invalid_new_only(env,value):
    grant=verified(env)
    assert complete(env,grant,password=value,confirmPassword=value).status_code==422

@pytest.mark.parametrize('value',['Q7!m2#Zx','Aa7!'*16])
def test_password_valid_boundaries(env,value):
    assert complete(env,password=value,confirmPassword=value).status_code==200

def test_name_unicode_normalization_and_email_phone_validation(env):
    assert validation.name('  Nguyễn  ')=='Nguyễn'
    assert validation.phone('0912345678')=='+84912345678'
    assert validation.email(' a.b+tag@Example.com ')=='a.b+tag@example.com'
    for value in ['09 12345678','+84123456789','０９１２３４５６７８']:
        with pytest.raises(ValueError):validation.phone(value)

def test_social_new_existing_and_no_second_code_exchange(env,monkeypatch):
    c,db,_,phone,_=env
    count=[]
    def verify(data):
        count.append(data.provider)
        return {'sub':'sub-'+phone,'email':'social'+phone[-7:]+'@example.com','email_verified':True}
    monkeypatch.setattr(social,'verify_identity',verify)
    initial=c.post(PREFIX+'/social/start',json={'provider':'apple','idToken':'fixture','authorizationCode':'one-use',
                    'challenge':'challenge-'+phone,'device':DEVICE})
    assert initial.status_code==200,initial.text
    grant=initial.json();assert grant['requiresProfile']
    result=c.post(PREFIX+'/social/complete',json={**ticket(grant),'displayName':'Đỗ Đức',
      'defaultRelationship':'father','acceptedTerms':True,'documentsDigest':grant['documentsDigest'],'device':DEVICE})
    assert result.status_code==200,result.text
    assert len(count)==1
    existing=c.post(PREFIX+'/social/start',json={'provider':'apple','idToken':'fixture','authorizationCode':'new-code',
                   'challenge':'second-'+phone,'device':DEVICE})
    assert existing.status_code==200 and existing.json()['user']['id']==result.json()['user']['id']
    assert not existing.json().get('requiresProfile')

def test_refresh_rotation_retry_reuse_and_access_revocation(env):
    c,_,_,_,clock=env;value=account(env)
    body={'refreshToken':value['refreshToken']}
    fresh=c.post('/api/v1/auth/refresh',json=body)
    assert fresh.status_code==200,fresh.text
    assert fresh.json()['refreshToken']!=value['refreshToken']
    assert c.post('/api/v1/auth/refresh',json=body).json()['refreshToken']==fresh.json()['refreshToken']
    clock[0]+=timedelta(seconds=6)
    assert c.post('/api/v1/auth/refresh',json=body).status_code==401
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==401

def test_change_password_replaces_current_revokes_other(env):
    c,_,_,phone,_=env;value=account(env)
    other=c.post('/api/v1/auth/login',json={'phone':phone,'password':'Q7!m2#Zx','device':DEVICE}).json()
    response=c.post(PREFIX+'/password/change',headers=headers(value),json={
      'currentPassword':'Q7!m2#Zx','newPassword':'New!pass789','confirmPassword':'New!pass789','device':DEVICE})
    assert response.status_code==200,response.text
    assert c.get('/api/v1/auth/me',headers=headers(other)).status_code==401
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==401
    assert c.get('/api/v1/auth/me',headers=headers(response.json())).status_code==200

def test_sms_recovery_revokes_all_and_replay_fails(env):
    c,_,sent,phone,_=env;value=account(env)
    response=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':DEVICE})
    grant=response.json()
    verified_response=c.post(PREFIX+'/recovery/verify',json={**ticket(grant),'code':sent[-1][2],'device':DEVICE})
    assert verified_response.status_code==200,verified_response.text
    assert verified_response.json()['requiresAdditionalVerification'] is False
    body={**ticket(grant),'newPassword':'New!pass789','confirmPassword':'New!pass789'}
    assert c.post(PREFIX+'/recovery/complete',json=body).status_code==200
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==401
    replay=c.post(PREFIX+'/recovery/complete',json=body)
    assert replay.status_code==200 and replay.json()['alreadyCompleted']

def test_anomalous_sms_only_requires_support_without_logout(env):
    c,db,sent,phone,clock=env;value=account(env)
    db.execute('UPDATE account.users SET last_login_at=%s WHERE phone=%s',(clock[0]-timedelta(days=90),phone))
    device={**DEVICE,'deviceId':'new-device'}
    grant=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':device}).json()
    result=c.post(PREFIX+'/recovery/verify',json={**ticket(grant),'code':sent[-1][2],'device':device})
    assert result.status_code==200 and result.json()['requiresAdditionalVerification'] is True
    body={**ticket(grant),'newPassword':'New!pass789','confirmPassword':'New!pass789'}
    assert c.post(PREFIX+'/recovery/complete',json=body).status_code==403
    assert c.post(PREFIX+'/recovery/email/start',json=ticket(grant)).status_code==403
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==200

def test_risk_exact_boundaries():
    now=datetime(2026,11,18,tzinfo=timezone.utc)
    def risk(**kw):
        return risk_reasons(new_device=kw.get('new',True),last_activity=kw.get('last',now),
             security_changed=kw.get('change'),failures=kw.get('fail',0),now=now)
    assert not risk(new=False,fail=8,last=now-timedelta(days=100))
    assert not risk(last=now-timedelta(days=90)+timedelta(seconds=1),fail=4,change=now-timedelta(hours=24))
    assert risk(last=now-timedelta(days=90))==['inactive_90d']
    assert risk(fail=5)==['recovery_failures_30m']
    assert risk(change=now-timedelta(hours=24)+timedelta(seconds=1))==['security_change_24h']

def test_reauth_is_bound_to_action_and_delete_blocker(env):
    c,_,_,_,_=env;value=account(env)
    grant=c.post(PREFIX+'/reauth',headers=headers(value),json={'action':'change_email',
       'target':'new@example.com','currentPassword':'Q7!m2#Zx'}).json()
    assert c.post(PREFIX+'/phone/start',headers=headers(value),json=ticket(grant)).status_code==401
    assert c.post(PREFIX+'/account/delete',json=ticket(grant)).status_code==401

@pytest.mark.parametrize('age,expected',[(299,200),(300,401),(301,401)])
def test_otp_exact_expiry(env,age,expected):
    c,_,sent,_,clock=env
    value=start(env);clock[0]+=timedelta(seconds=age)
    assert c.post(PREFIX+'/signup/verify',json={**ticket(value),'code':sent[-1][2]}).status_code==expected

@pytest.mark.parametrize('age,expected',[(599,200),(600,401),(601,401)])
def test_completion_grant_exact_expiry(env,age,expected):
    grant=verified(env);env[4][0]+=timedelta(seconds=age)
    assert complete(env,grant).status_code==expected

def test_identifier_change_rollback_conflict_and_session_binding(env,monkeypatch):
    c,db,sent,phone,_=env;value=account(env)
    email='new'+phone[-7:]+'@example.com'
    monkeypatch.setattr(settings,'email_provider','webhook')
    monkeypatch.setattr(settings,'email_webhook_url','https://email.test.invalid')
    monkeypatch.setattr(settings,'email_webhook_token','test-only')
    grant_response=c.post(PREFIX+'/reauth',headers=headers(value),json={'action':'change_email','target':email,'currentPassword':'Q7!m2#Zx'})
    assert grant_response.status_code==200,grant_response.text
    grant=grant_response.json()
    challenge=c.post(PREFIX+'/email/start',headers=headers(value),json=ticket(grant))
    assert challenge.status_code==200,challenge.text
    code=sent[-1][2]
    wrong=c.post(PREFIX+'/email/verify',headers=headers(value),json={**ticket(challenge.json()),'code':'999999' if code!='999999' else '888888'})
    assert wrong.status_code==400
    assert db.execute('SELECT email FROM account.users WHERE phone=%s',(phone,)).fetchone()['email'] is None
    result=c.post(PREFIX+'/email/verify',headers=headers(value),json={**ticket(challenge.json()),'code':code})
    assert result.status_code==200,result.text
    assert result.json()['user']['email']==email and result.json()['user']['emailVerifiedAt']
    from app.features.auth.recovery import security_changed_at
    updated=db.execute('SELECT * FROM account.users WHERE phone=%s',(phone,)).fetchone()
    assert updated['password_changed_at'] is None
    assert security_changed_at(db,updated) is not None
    assert c.post(PREFIX+'/email/start',headers=headers(result.json()),json=ticket(grant)).status_code==401

def test_recovery_additional_email_proof_is_required_and_consumed(env,monkeypatch):
    c,db,sent,phone,clock=env;value=account(env)
    email='recovery'+phone[-7:]+'@example.com'
    db.execute('UPDATE account.users SET email=%s,email_verified_at=%s,last_login_at=%s WHERE phone=%s',
        (email,clock[0]-timedelta(days=100),clock[0]-timedelta(days=90),phone))
    monkeypatch.setattr(settings,'email_provider','webhook')
    monkeypatch.setattr(settings,'email_webhook_url','https://email.test.invalid')
    monkeypatch.setattr(settings,'email_webhook_token','test-only')
    device={**DEVICE,'deviceId':'new-device'}
    grant=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':device}).json()
    verified_result=c.post(PREFIX+'/recovery/verify',json={**ticket(grant),'code':sent[-1][2],'device':device})
    assert verified_result.json()['requiresAdditionalVerification']
    extra=c.post(PREFIX+'/recovery/email/start',json=ticket(grant))
    assert extra.status_code==200,extra.text
    # A child email ticket cannot be used as the primary SMS proof or reset grant.
    assert c.post(PREFIX+'/recovery/verify',json={**ticket(extra.json()),'code':sent[-1][2],'device':device}).status_code==401
    assert c.post(PREFIX+'/recovery/complete',json={**ticket(extra.json()),'newPassword':'New!pass789','confirmPassword':'New!pass789'}).status_code==401
    verified_extra=c.post(PREFIX+'/recovery/email/verify',json={**ticket(extra.json()),'code':sent[-1][2]})
    assert verified_extra.status_code==200,verified_extra.text
    assert c.post(PREFIX+'/recovery/email/verify',json={**ticket(extra.json()),'code':sent[-1][2]}).status_code==200
    result=c.post(PREFIX+'/recovery/complete',json={**ticket(grant),'newPassword':'New!pass789','confirmPassword':'New!pass789'})
    assert result.status_code==200,result.text


def test_verify_retry_keeps_deadline_and_checks_original_code(env):
    c,_,sent,_,clock=env
    grant=start(env);code=sent[-1][2]
    body={**ticket(grant),'code':code}
    first=c.post(PREFIX+'/signup/verify',json=body).json()
    clock[0]+=timedelta(seconds=30)
    retry=c.post(PREFIX+'/signup/verify',json=body)
    assert retry.status_code==200 and retry.json()['expiresAt']==first['expiresAt']
    wrong='999999' if code!='999999' else '888888'
    assert c.post(PREFIX+'/signup/verify',json={**body,'code':wrong}).status_code==401


def test_recovery_queue_resumes_after_process_loss_and_resend(env):
    from app.core.database import transaction
    from app.features.auth import recovery as recovery,schemas_v2 as schema
    c,db,sent,phone,clock=env;account(env)
    with transaction() as conn:
        grant=recovery.start(conn,schema.RecoveryStart(identifier=phone,device=DEVICE),'queue-test-ip')
    before=len(sent)
    recovery.process_pending()
    assert len(sent)==before+1
    recovery.process_pending()
    assert len(sent)==before+1
    assert c.post(PREFIX+'/recovery/resend',json={**ticket(grant),'device':DEVICE}).status_code==429
    clock[0]+=timedelta(seconds=60)
    result=c.post(PREFIX+'/recovery/resend',json={**ticket(grant),'device':DEVICE})
    assert result.status_code==200,result.text
    assert c.post(PREFIX+'/recovery/verify',json={**ticket(grant),'code':sent[-1][2],'device':DEVICE}).status_code==401
    assert c.post(PREFIX+'/recovery/verify',json={**ticket(result.json()),'code':sent[-1][2],'device':DEVICE}).status_code==200


def test_recovery_queue_provider_failure_retries_without_storing_secrets(env,monkeypatch):
    from app.features.auth import recovery as recovery
    c,db,sent,phone,clock=env;account(env)
    monkeypatch.setattr(sms,'send_code',lambda *args:False)
    grant=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':DEVICE}).json()
    def job():
        return db.execute('SELECT metadata FROM account.auth_transactions WHERE id=%s',(grant['transactionId'],)).fetchone()['metadata']['delivery']
    assert job()['state']=='pending' and job()['attempts']==1
    recovery.process_pending();assert job()['attempts']==1
    clock[0]+=timedelta(seconds=60)
    monkeypatch.setattr(sms,'send_code',lambda channel,target,code:sent.append((channel,target,code)) or True)
    recovery.process_pending()
    assert job()['state']=='delivered' and job()['attempts']==2
    assert set(job())=={'state','attempts','nextAttemptAt','ipHash'}


def test_older_queued_recovery_cannot_invalidate_newer_request(env):
    from app.core.database import transaction
    from app.features.auth import recovery as recovery,schemas_v2 as schema
    c,db,sent,phone,clock=env;account(env)
    with transaction() as conn:
        older=recovery.start(conn,schema.RecoveryStart(identifier=phone,device=DEVICE),'ordering-ip')
    clock[0]+=timedelta(seconds=61)
    with transaction() as conn:
        newer=recovery.start(conn,schema.RecoveryStart(identifier=phone,device=DEVICE),'ordering-ip')
    recovery.deliver(older)
    assert db.execute('SELECT invalidated_at FROM account.auth_transactions WHERE id=%s',(newer['transactionId'],)).fetchone()['invalidated_at'] is None
    clock[0]+=timedelta(seconds=60)
    recovery.deliver(newer)
    assert c.post(PREFIX+'/recovery/verify',json={**ticket(newer),'code':sent[-1][2],'device':DEVICE}).status_code==200


def test_empty_device_history_is_not_trusted_for_inactive_recovery(env):
    c,db,sent,phone,clock=env;value=account(env)
    db.execute("UPDATE account.users SET auth_known_devices='[]'::jsonb,last_login_at=%s WHERE phone=%s",(clock[0]-timedelta(days=90),phone))
    grant=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':DEVICE}).json()
    result=c.post(PREFIX+'/recovery/verify',json={**ticket(grant),'code':sent[-1][2],'device':DEVICE})
    assert result.status_code==200 and result.json()['requiresAdditionalVerification']
    assert result.json()['verificationOptions']==['support']
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==200


def test_security_capabilities_require_session_and_hide_internal_data(env):
    c,_,_,_,_=env;value=account(env)
    assert c.get(PREFIX+'/security').status_code==401
    result=c.get(PREFIX+'/security',headers=headers(value))
    assert result.status_code==200,result.text
    body=result.json()
    assert body['actions']['changePassword'] and body['actions']['deleteAccount']
    assert body['providers']==[]
    assert 'auth_known_devices' not in body and 'password_hash' not in body

def test_five_failures_across_requests_escalates_without_logout(env):
    c,_,sent,phone,_=env;value=account(env)
    device={**DEVICE,'deviceId':'new-device'}
    first=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':device}).json()
    wrong='999999' if sent[-1][2]!='999999' else '888888'
    for _ in range(5):c.post(PREFIX+'/recovery/verify',json={**ticket(first),'code':wrong,'device':device})
    env[4][0]+=timedelta(seconds=61)
    second=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':device}).json()
    result=c.post(PREFIX+'/recovery/verify',json={**ticket(second),'code':sent[-1][2],'device':device})
    assert result.status_code==200 and result.json()['requiresAdditionalVerification']
    assert c.get('/api/v1/auth/me',headers=headers(value)).status_code==200

def test_provider_recovery_correct_identity_only(env,monkeypatch):
    c,db,sent,phone,clock=env;value=account(env)
    db.execute('INSERT INTO account.social_identities(provider,subject,user_id,created_at) VALUES (%s,%s,%s,%s)',
        ('google','linked-'+phone,value['user']['id'],clock[0]-timedelta(days=100)))
    db.execute('UPDATE account.users SET last_login_at=%s WHERE phone=%s',(clock[0]-timedelta(days=90),phone))
    device={**DEVICE,'deviceId':'new-device'}
    grant=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':device}).json()
    c.post(PREFIX+'/recovery/verify',json={**ticket(grant),'code':sent[-1][2],'device':device})
    monkeypatch.setattr(social,'verify_identity',lambda data:{'sub':'wrong','iat':int(clock[0].timestamp())})
    body={**ticket(grant),'provider':'google','idToken':'fixture','device':device}
    assert c.post(PREFIX+'/recovery/provider',json=body).status_code==401
    monkeypatch.setattr(social,'verify_identity',lambda data:{'sub':'linked-'+phone,'iat':int(clock[0].timestamp())})
    assert c.post(PREFIX+'/recovery/provider',json=body).status_code==200
    assert c.post(PREFIX+'/recovery/complete',json={**ticket(grant),'newPassword':'New!pass789','confirmPassword':'New!pass789'}).status_code==200

def test_generic_recovery_does_not_send_to_nonexistent_user(env):
    c,_,sent,phone,_=env
    result=c.post(PREFIX+'/recovery/start',json={'identifier':phone,'device':DEVICE})
    assert result.status_code==200 and not sent
    assert result.json()['message'].startswith('Nếu')
    assert 'deliveryStatus' not in result.json()

def test_explicit_invalidation_and_disabled_account(env):
    c,db,sent,phone,_=env
    value=start(env)
    assert c.post(PREFIX+'/signup/invalidate',json=ticket(value)).status_code==200
    assert c.post(PREFIX+'/signup/verify',json={**ticket(value),'code':sent[-1][2]}).status_code==401
    # Move past cooldown before a new independent registration.
    env[4][0]+=timedelta(seconds=61)
    value=account(env)
    db.execute("UPDATE account.users SET status='pending_deletion' WHERE phone=%s",(phone,))
    login=c.post('/api/v1/auth/login',json={'phone':phone,'password':'Q7!m2#Zx','device':DEVICE})
    assert login.status_code==403
    assert db.execute('SELECT status FROM account.users WHERE phone=%s',(phone,)).fetchone()['status']=='pending_deletion'
    assert c.post('/api/v1/auth/refresh',json={'refreshToken':value['refreshToken']}).status_code==401

@pytest.mark.parametrize('provider,trusted,expected',[('apple',True,200),('google',False,403)])
def test_setup_password_requires_trusted_identifier_and_provider_reauth(env,monkeypatch,provider,trusted,expected):
    c,db,_,phone,clock=env
    monkeypatch.setattr(social,'verify_identity',lambda data:{'sub':'setup-'+phone,
       'email':'setup'+phone[-7:]+'@example.com','email_verified':True,'iat':int(clock[0].timestamp())})
    credential={'provider':provider,'idToken':'fixture','authorizationCode':'one-use',
       'challenge':'setup-start-'+phone,'device':DEVICE}
    grant=c.post(PREFIX+'/social/start',json=credential).json()
    created=c.post(PREFIX+'/social/complete',json={**ticket(grant),'displayName':'Đỗ Đức',
       'defaultRelationship':'father','acceptedTerms':True,'documentsDigest':grant['documentsDigest'],'device':DEVICE})
    assert created.status_code==200,created.text
    user=created.json()
    assert bool(user['user']['emailVerifiedAt']) is trusted
    proof=c.post(PREFIX+'/reauth',headers=headers(user),json={'action':'set_password',
       'providerCredential':{**credential,'challenge':'setup-reauth-'+phone}})
    assert proof.status_code==200,proof.text
    result=c.post(PREFIX+'/password/setup',headers=headers(user),json={**ticket(proof.json()),
       'newPassword':'New!pass789','confirmPassword':'New!pass789','device':DEVICE})
    assert result.status_code==expected,result.text
    if expected==200:
        assert result.json()['user']['hasPassword']
        assert db.execute('SELECT user_id FROM account.social_identities WHERE user_id=%s',(user['user']['id'],)).fetchone()

def test_logout_with_rotated_token_revokes_current_session(env):
    c,_,_,_,_=env;value=account(env)
    fresh=c.post('/api/v1/auth/refresh',json={'refreshToken':value['refreshToken']}).json()
    assert c.post('/api/v1/auth/logout',json={'refreshToken':value['refreshToken']}).status_code==204
    assert c.post('/api/v1/auth/refresh',json={'refreshToken':fresh['refreshToken']}).status_code==401

def test_different_device_cannot_complete_phone_grant(env):
    grant=verified(env)
    assert complete(env,grant,device={**DEVICE,'deviceId':'different'}).status_code==401

def test_legacy_creation_paths_disabled_when_v2_is_enabled(env):
    c,_,_,phone,_=env
    assert c.post('/api/v1/auth/register',json={'phone':phone,'password':'Q7!m2#Zx','acceptedTerms':True}).status_code==409
    assert c.post('/api/v1/auth/social',json={'provider':'google','idToken':'fixture','acceptedTerms':True,'device':DEVICE}).status_code==409

def test_failed_resend_preserves_previous_code(env,monkeypatch):
    c,_,sent,_,clock=env
    value=start(env);code=sent[-1][2]
    clock[0]+=timedelta(seconds=60)
    monkeypatch.setattr(sms,'send_code',lambda *args:False)
    assert c.post(PREFIX+'/signup/resend',json=ticket(value)).status_code==503
    assert c.post(PREFIX+'/signup/verify',json={**ticket(value),'code':code}).status_code==200

@pytest.mark.parametrize('variant',['valid','expired','audience','issuer','missing_sub','signature'])
def test_google_cryptographic_token_validation(env,monkeypatch,variant):
    import jwt
    from types import SimpleNamespace
    from cryptography.hazmat.primitives.asymmetric import rsa
    from app.features.auth.schemas_v2 import SocialStart
    from app.features.auth.errors import AuthFailure
    key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    public=key.public_key()
    monkeypatch.setattr(settings,'google_client_ids',['test-audience'])
    monkeypatch.setattr(social,'keys',lambda provider:SimpleNamespace(get_signing_key_from_jwt=lambda token:SimpleNamespace(key=public)))
    stamp=int(env[4][0].timestamp())
    claims={'sub':'test-sub','iss':'https://accounts.google.com','aud':'test-audience','iat':stamp,'exp':stamp+300}
    if variant=='expired':claims['exp']=stamp-60
    if variant=='audience':claims['aud']='wrong-audience'
    if variant=='issuer':claims['iss']='https://attacker.invalid'
    if variant=='missing_sub':claims.pop('sub')
    if variant=='signature':key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    result=social.verify_identity(SocialStart(provider='google',idToken=jwt.encode(claims,key,algorithm='RS256'),device=DEVICE))
    assert isinstance(result,AuthFailure) is (variant!='valid')

def test_device_cache_concurrent_updates_deduplicate_and_stay_bounded(env):
    from app.features.auth import transactions as tx
    from app.features.auth.schemas import Device
    _,db,_,phone,_=env;value=account(env);uid=value['user']['id']
    def add(number):
        with psycopg.connect(dedicated_test_url(),row_factory=dict_row) as connection:
            tx.record_device(connection,uid,Device(platform='android',deviceId=f'parallel-{number}'))
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(add,range(12)))
    user=db.execute('SELECT * FROM account.users WHERE id=%s',(uid,)).fetchone()
    assert len(user['auth_known_devices'])==13
    assert {sec.secret_hash(f'parallel-{n}') for n in range(12)} <= tx.known_devices(user)
    for number in range(20):
        with db.transaction():
            tx.record_device(db,uid,Device(platform='ios',deviceId=f'recent-{number}'))
    with db.transaction():
        tx.record_device(db,uid,Device(platform='ios',deviceId='recent-19'))
    user=db.execute('SELECT * FROM account.users WHERE id=%s',(uid,)).fetchone()
    assert len(user['auth_known_devices'])==16
    assert user['auth_known_devices'][0]['hash']==sec.secret_hash('recent-19')
    assert len(tx.known_devices(user))==16
    assert not db.execute("SELECT to_regclass('account.auth_device_history') AS t").fetchone()['t']
    assert not db.execute("SELECT to_regclass('account.mobile_login_limits') AS t").fetchone()['t']

def test_expired_session_removal_does_not_erase_known_device_risk_signal(env):
    from app.features.auth.recovery import assess
    from app.features.auth.schemas import Device
    _,db,_,phone,clock=env;value=account(env);uid=value['user']['id']
    db.execute('DELETE FROM account.user_sessions WHERE user_id=%s',(uid,))
    user=db.execute('UPDATE account.users SET last_login_at=%s WHERE id=%s RETURNING *',
        (clock[0]-timedelta(days=90),uid)).fetchone()
    assert assess(db,user,Device(**DEVICE))==[]
    assert assess(db,user,Device(platform='ios',deviceId='unknown'))==['inactive_90d']

def test_device_cache_not_exposed_in_account_response(env):
    c,_,_,_,_=env;value=account(env)
    result=c.get('/api/v1/auth/me',headers=headers(value))
    assert result.status_code==200
    assert 'auth_known_devices' not in result.json()
    assert sec.secret_hash(DEVICE['deviceId']) not in result.text

def test_compaction_migrates_device_data_and_refuses_silent_loss(env):
    """Replay the old->new migration inside a rollback-only transaction on test DB."""
    _,db,_,phone,clock=env
    ddl=(Path(__file__).resolve().parents[1]/'migrations/024_auth_storage_compaction.sql').read_text(encoding='utf-8')
    class RollbackOnly(Exception):pass
    with pytest.raises(RollbackOnly):
        with db.transaction():
            db.execute('ALTER TABLE account.users DROP COLUMN auth_known_devices')
            db.execute('''CREATE TABLE account.auth_device_history (
               user_id uuid NOT NULL REFERENCES account.users(id),device_hash text NOT NULL,
               last_authenticated_at timestamptz NOT NULL,PRIMARY KEY(user_id,device_hash))''')
            db.execute('CREATE TABLE account.mobile_login_limits(key text PRIMARY KEY,attempts integer)')
            uid=db.execute("INSERT INTO account.users(phone,password_hash,display_name,status) VALUES (%s,'!test','Migration','active') RETURNING id",(phone,)).fetchone()['id']
            for number in range(17):
                db.execute('INSERT INTO account.auth_device_history VALUES (%s,%s,%s)',
                    (uid,sec.secret_hash(f'old-{number}'),clock[0]-timedelta(days=number)))
            with pytest.raises(psycopg.errors.RaiseException,match='More than 16'):
                with db.transaction():db.execute(ddl)
            db.execute('DELETE FROM account.auth_device_history WHERE device_hash=%s',(sec.secret_hash('old-16'),))
            db.execute("INSERT INTO account.mobile_login_limits VALUES ('test-counter',1)")
            with pytest.raises(psycopg.errors.RaiseException,match='not empty'):
                with db.transaction():db.execute(ddl)
            db.execute('DELETE FROM account.mobile_login_limits')
            db.execute(ddl)
            entries=db.execute('SELECT auth_known_devices FROM account.users WHERE id=%s',(uid,)).fetchone()['auth_known_devices']
            assert len(entries)==16
            assert {item['hash'] for item in entries}=={sec.secret_hash(f'old-{n}') for n in range(16)}
            assert datetime.fromisoformat(entries[0]['lastAuthenticatedAt'])==clock[0]
            assert not db.execute("SELECT to_regclass('account.auth_device_history') AS t").fetchone()['t']
            raise RollbackOnly()
    assert db.execute("SELECT 1 FROM information_schema.columns WHERE table_schema='account' AND table_name='users' AND column_name='auth_known_devices'").fetchone()
