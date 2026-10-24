from datetime import timedelta
from types import SimpleNamespace

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa, ec
from cryptography.hazmat.primitives import serialization

from app.core import security as sec
from app.core.config import settings
from app.features.auth import social
from app.features.auth.schemas import SocialRegister
from app.features.auth.errors import AuthFailure
from .test_registration_v2 import database, env  # isolated migrated PostgreSQL fixtures


@pytest.fixture
def signing(monkeypatch):
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    monkeypatch.setattr(settings, 'google_client_ids', ['google-client'])
    monkeypatch.setattr(social, 'keys', lambda _: SimpleNamespace(
        get_signing_key_from_jwt=lambda token: SimpleNamespace(key=key.public_key())))
    return key


def token(key, **changes):
    claims = {'sub':'provider-user-1','aud':'google-client','iss':'https://accounts.google.com',
        'exp':sec.now()+timedelta(minutes=5),'iat':sec.now(),
        'email':'social@example.com','email_verified':True,'name':'Google Parent',**changes}
    return jwt.encode(claims,key,algorithm='RS256')


def body(raw, **changes):
    return {'provider':'google','idToken':raw,'acceptedTerms':True,
            'device':{'platform':'android'},**changes}


@pytest.mark.parametrize('changes', [{'aud':'other-app'},{'iss':'https://attacker.example'},
    {'exp':sec.now()-timedelta(minutes=5)},{'sub':''}])
def test_reject_invalid_signed_claims(signing,changes):
    result=social.verify_identity(SocialRegister(**body(token(signing,**changes))))
    assert isinstance(result,AuthFailure) and result.code=='SOCIAL_TOKEN_INVALID'


def test_google_creates_and_reuses_identity(env,signing):
    c,db,_=env
    payload=body(token(signing),defaultRelationship='grandmother')
    first=c.post('/api/v1/auth/social',json=payload)
    assert first.status_code==200,first.text
    first=first.json()
    assert first['isNewUser'] is True and first['user']['relationship']=='grandmother'
    second=c.post('/api/v1/auth/social',json=payload).json()
    assert second['isNewUser'] is False and second['user']['id']==first['user']['id']
    assert db.execute('SELECT count(*) n FROM account.social_identities').fetchone()['n']==1
    assert db.execute('SELECT password_hash FROM account.users').fetchone()['password_hash']=='!social'
    assert c.get('/api/v1/auth/me',headers={'Authorization':'Bearer '+first['accessToken']}).status_code==200
    db.execute("UPDATE account.users SET status='locked'")
    assert c.post('/api/v1/auth/social',json=payload).status_code==403


def test_email_collision_does_not_link(env,signing):
    c,db,_=env
    db.execute("""INSERT INTO account.users(email,password_hash,consented_at)
        VALUES ('social@example.com','existing-password',now())""")
    r=c.post('/api/v1/auth/social',json=body(token(signing)))
    assert r.status_code==409 and r.json()['error']['code']=='SOCIAL_ACCOUNT_CONFLICT'
    assert db.execute('SELECT count(*) n FROM account.social_identities').fetchone()['n']==0


def test_unverified_email_and_missing_consent(env,signing):
    c,db,_=env
    assert c.post('/api/v1/auth/social',json=body(token(signing,email_verified=False))).status_code==403
    assert c.post('/api/v1/auth/social',json=body(token(signing),acceptedTerms=False)).status_code==422
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n']==0


def test_wrong_signature_and_missing_config(signing,monkeypatch):
    other=rsa.generate_private_key(public_exponent=65537,key_size=2048)
    assert social.verify_identity(SocialRegister(**body(token(other)))).code=='SOCIAL_TOKEN_INVALID'
    monkeypatch.setattr(settings,'google_client_ids',[])
    assert social.verify_identity(SocialRegister(**body(token(signing)))).code=='SOCIAL_AUTH_NOT_CONFIGURED'


@pytest.mark.parametrize('claim', ['sub', 'aud', 'iss', 'exp', 'iat'])
def test_google_requires_all_security_claims(signing, claim):
    claims = jwt.decode(token(signing), options={'verify_signature':False})
    claims.pop(claim)
    raw = jwt.encode(claims, signing, algorithm='RS256')
    assert social.verify_identity(SocialRegister(**body(raw))).code == 'SOCIAL_TOKEN_INVALID'


@pytest.mark.parametrize('raw', ['not-a-token', 'a.b.c', ''])
def test_google_rejects_malformed_tokens(env, signing, raw):
    c, db, _ = env
    r = c.post('/api/v1/auth/social', json=body(raw))
    assert r.status_code == (422 if not raw else 401)
    assert db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n'] == 0


def test_google_jwks_network_failure_is_retryable(env, signing, monkeypatch):
    c, db, _ = env
    def offline(_):
        raise jwt.PyJWKClientConnectionError('test provider offline')
    monkeypatch.setattr(social, 'keys', offline)
    r = c.post('/api/v1/auth/social', json=body(token(signing)))
    assert r.status_code == 503
    assert r.json()['error']['code'] == 'SOCIAL_PROVIDER_UNAVAILABLE'
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n'] == 0


def test_social_account_cannot_use_password_login(env, signing):
    c, db, _ = env
    assert c.post('/api/v1/auth/social', json=body(token(signing))).status_code == 200
    r = c.post('/api/v1/auth/login', json={'email':'social@example.com',
        'password':'!social','device':{'platform':'android'}})
    assert r.status_code == 401 and r.json()['error']['code'] == 'INVALID_CREDENTIALS'


def test_apple_without_developer_configuration(env, monkeypatch):
    c, _, _ = env
    monkeypatch.setattr(settings, 'apple_client_ids', [])
    r = c.post('/api/v1/auth/social/apple/challenge')
    assert r.status_code == 503 and r.json()['error']['code'] == 'SOCIAL_AUTH_NOT_CONFIGURED'


@pytest.mark.parametrize('exchange_status', [200, 400, 'timeout'])
def test_apple_nonce_code_exchange_and_replay(env,signing,monkeypatch,tmp_path,exchange_status):
    c,db,_=env
    private=ec.generate_private_key(ec.SECP256R1())
    path=tmp_path/'apple.p8'
    path.write_bytes(private.private_bytes(serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
    for key,value in {'apple_client_ids':['apple-client'],'apple_team_id':'team',
        'apple_key_id':'key-id','apple_private_key_path':str(path)}.items():
        monkeypatch.setattr(settings,key,value)
    ch=c.post('/api/v1/auth/social/apple/challenge').json()
    raw=token(signing,iss='https://appleid.apple.com',aud='apple-client',nonce=ch['nonce'])
    original=httpx.Client
    def exchange(request):
        assert str(request.url)=='https://appleid.apple.com/auth/token'
        if exchange_status == 'timeout':
            raise httpx.ReadTimeout('test Apple timeout', request=request)
        return httpx.Response(exchange_status,json={'id_token':raw})
    monkeypatch.setattr(social.httpx,'Client',lambda **kwargs: original(transport=httpx.MockTransport(exchange),**kwargs))
    payload=body(raw,provider='apple',authorizationCode='one-time-code',challenge=ch['challenge'],device={'platform':'ios'})
    r=c.post('/api/v1/auth/social',json=payload)
    if exchange_status != 200:
        assert r.status_code == (503 if exchange_status == 'timeout' else 401)
        assert db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n'] == 0
        return
    assert r.status_code==200,r.text
    assert c.post('/api/v1/auth/social',json=payload).status_code==401
    bad=body(token(signing,iss='https://appleid.apple.com',aud='apple-client',nonce='wrong'),
        provider='apple',authorizationCode='code',challenge=ch['challenge'])
    assert c.post('/api/v1/auth/social',json=bad).status_code==401
