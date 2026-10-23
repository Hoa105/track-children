"""Consolidated-schema API tests. Each run uses a new, disposable *_test DB."""
import json
import os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from uuid import uuid4

import psycopg
from psycopg import sql
from psycopg.conninfo import conninfo_to_dict, make_conninfo
from psycopg.rows import dict_row
import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.features.auth import sms
from app.main import app


@pytest.fixture(scope='module')
def database():
    url = os.environ.get('AUTH_TEST_DATABASE_URL')
    if not url:
        pytest.skip('AUTH_TEST_DATABASE_URL required; never use the application database')
    if not conninfo_to_dict(url).get('dbname','').endswith('_test'):
        pytest.fail('Test URL must name a *_test database')
    name = 'registration_' + uuid4().hex + '_test'
    with psycopg.connect(make_conninfo(url, dbname='postgres'), autocommit=True) as owner:
        owner.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
        try:
            target = make_conninfo(url, dbname=name)
            with psycopg.connect(target, autocommit=True) as db:
                for file in sorted((Path(__file__).parents[1]/'migrations').glob('*.sql')):
                    with db.transaction():
                        db.execute(file.read_text(encoding='utf-8'))
            yield target
        finally:
            owner.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(name)))


@pytest.fixture
def env(database, monkeypatch, tmp_path):
    path = tmp_path/'legal.json'
    path.write_text(json.dumps([{'docType': k, 'version':'test', 'content':'Test only',
        'isRequired':True,'effectiveAt':'2020-01-01T00:00:00Z'} for k in ['terms','privacy','data_policy']]),encoding='utf-8')
    for key,value in {'database_url':database,'auth_secret':'test-registration-secret-1234567890123456789',
        'legal_documents_path':str(path),'email_webhook_url':'https://example.com/email',
        'email_webhook_token':'test','sms_webhook_url':'https://example.com/sms','sms_webhook_token':'test',
        'auth_otp_preview':False,'email_provider':'webhook',
        'auth_rate_limit_path':str(tmp_path/'rate-limits.sqlite3')}.items():
        monkeypatch.setattr(settings,key,value)
    sent=[]
    monkeypatch.setattr(sms,'send_code',lambda *args: sent.append(args) or True)
    with psycopg.connect(database,autocommit=True,row_factory=dict_row) as db:
        db.execute('TRUNCATE account.users CASCADE')
        yield TestClient(app),db,sent


def payload(**kwargs):
    return {'email':'parent@example.com','password':'a password 123','acceptedTerms':True,**kwargs}


def verify(client,ch,code='000000'):
    return client.post('/api/v1/auth/register/verify',json={
        'verificationId':ch['verificationId'],'registrationToken':ch['registrationToken'],
        'code':code,'device':{'platform':'android'},'rememberMe':False})


@pytest.mark.parametrize('channel', ['email','sms'])
def test_registration_and_session(env,channel):
    client,db,sent=env
    data=payload(displayName='  ',defaultRelationship='grandfather')
    if channel=='sms':
        data.pop('email');data['phone']='0912345678'
    r=client.post('/api/v1/auth/register',json=data)
    assert r.status_code==201,r.text
    ch=r.json()
    assert ch['channel']==channel and sent[-1][0]==channel
    u=db.execute('SELECT * FROM account.users').fetchone()
    assert u['status']=='pending' and u['display_name']=='Phụ huynh' and u['consented_at']
    assert u['password_hash'].startswith('$argon2')
    r=verify(client,ch,sent[-1][2]);assert r.status_code==200,r.text
    result=r.json();assert result['user']['relationship']=='grandfather'
    from jsonschema import Draft202012Validator
    contract=json.loads((Path(__file__).parents[2]/'docs/api/mobile-auth.openapi.json').read_text(encoding='utf-8'))
    Draft202012Validator({'$ref':'#/components/schemas/AuthResult',
        'components':contract['components']}).validate(result)
    headers={'Authorization':'Bearer '+result['accessToken']}
    assert client.get('/api/v1/auth/me',headers=headers).status_code==200
    u=db.execute('SELECT * FROM account.users').fetchone()
    assert u['email_verified_at' if channel=='email' else 'phone_verified_at']
    assert db.execute('SELECT remember_me FROM account.user_sessions').fetchone()['remember_me'] is False
    assert verify(client,ch,sent[-1][2]).status_code==401
    assert client.post('/api/v1/auth/refresh',json={'refreshToken':result['refreshToken']}).status_code==200
    assert client.post('/api/v1/auth/logout',json={'refreshToken':result['refreshToken']}).status_code==204
    assert client.get('/api/v1/auth/me',headers=headers).status_code==401


def test_attempts_resend_expiry_resume_and_conflict(env):
    c,db,sent=env
    ch=c.post('/api/v1/auth/register',json=payload()).json()
    wrong='000000' if sent[-1][2]!='000000' else '000001'
    for remaining in range(4,-1,-1):
        r=verify(c,ch,wrong)
        assert r.json()['error']['details']['attemptsRemaining']==remaining
    assert verify(c,ch,sent[-1][2]).status_code==429
    body={k:ch[k] for k in ['verificationId','registrationToken']}
    assert c.post('/api/v1/auth/register/resend',json=body).status_code==429
    db.execute("UPDATE account.auth_codes SET created_at=now()-interval '61 seconds'")
    new=c.post('/api/v1/auth/register/resend',json=body).json()
    assert new['verificationId']!=ch['verificationId']
    assert verify(c,ch,wrong).status_code==401
    db.execute("UPDATE account.auth_codes SET expires_at=now()-interval '1 second' WHERE id=%s",(new['verificationId'],))
    assert verify(c,new,sent[-1][2]).json()['error']['code']=='OTP_EXPIRED'
    db.execute("UPDATE account.auth_codes SET created_at=now()-interval '61 seconds'")
    r=c.post('/api/v1/auth/register',json=payload());assert r.status_code==201,r.text
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n']==1
    assert c.post('/api/v1/auth/register',json=payload(password='another password')).status_code==409
    ch=r.json();assert verify(c,ch,sent[-1][2]).status_code==200
    assert c.post('/api/v1/auth/register',json=payload()).status_code==409


@pytest.mark.parametrize('changes', [{'password':'short'},{'acceptedTerms':False},
    {'phone':'0912345678'},{'defaultRelationship':'guardian'},{'username':'legacy'}])
def test_invalid_input(env,changes):
    c,db,_=env
    assert c.post('/api/v1/auth/register',json=payload(**changes)).status_code==422
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n']==0


def test_fail_closed_and_failed_delivery(env,monkeypatch):
    c,db,sent=env
    monkeypatch.setattr(settings,'email_webhook_token','')
    assert c.post('/api/v1/auth/register',json=payload()).status_code==503
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n']==0
    monkeypatch.setattr(settings,'email_webhook_token','test')
    monkeypatch.setattr(sms,'send_code',lambda *args: False)
    ch=c.post('/api/v1/auth/register',json=payload()).json()
    assert ch['deliveryStatus']=='failed'
    monkeypatch.setattr(settings,'legal_documents_path','missing.json')
    assert c.get('/api/v1/legal-documents?context=registration').status_code==503


def test_tampered_token_and_contact_limit(env):
    c,db,sent=env
    ch=c.post('/api/v1/auth/register',json=payload()).json()
    bad={**ch,'registrationToken':ch['registrationToken']+'x'}
    assert verify(c,bad,sent[-1][2]).status_code==401
    for _ in range(4):
        db.execute("UPDATE account.auth_codes SET created_at=now()-interval '61 seconds'")
        ch=c.post('/api/v1/auth/register',json=payload()).json()
    db.execute("UPDATE account.auth_codes SET created_at=now()-interval '61 seconds'")
    assert c.post('/api/v1/auth/register',json=payload()).status_code==429


@pytest.mark.parametrize('channel', ['email', 'sms'])
def test_local_preview_and_production_guard(env,monkeypatch,channel):
    from pydantic import ValidationError
    from app.core.config import Settings
    with pytest.raises(ValidationError):
        Settings(_env_file=None,app_env='production',auth_otp_preview=True)
    c,db,sent=env
    monkeypatch.setattr(settings,'app_env','local')
    monkeypatch.setattr(settings,'auth_otp_preview',True)
    monkeypatch.setattr(settings,'email_webhook_token','')
    monkeypatch.setattr(settings,'sms_webhook_token','')
    data=payload()
    if channel == 'sms':
        data.pop('email')
        data['phone']='0912345678'
    ch=c.post('/api/v1/auth/register',json=data).json()
    assert ch['channel']==channel
    assert ch['deliveryStatus']=='preview' and len(ch['devOtp'])==6 and not sent
    assert verify(c,ch,ch['devOtp']).status_code==200


def test_concurrent_verify_creates_only_one_session(env):
    c,db,sent=env
    ch=c.post('/api/v1/auth/register',json=payload()).json()
    code=sent[-1][2]
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(lambda _: verify(c,ch,code).status_code,range(2)))
    assert sorted(results)==[200,401]
    assert db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n']==1


@pytest.mark.parametrize('role',['mother','father','grandfather','grandmother','other_guardian'])
def test_every_relationship_is_preserved(env,role):
    c,db,sent=env
    ch=c.post('/api/v1/auth/register',json=payload(defaultRelationship=role)).json()
    assert verify(c,ch,sent[-1][2]).json()['user']['defaultRelationship']==role
