"""Admin auth integration tests against an isolated, fully migrated PostgreSQL DB."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from uuid import uuid4
import json
from pathlib import Path

import jwt
import psycopg
import pytest
from fastapi.testclient import TestClient

from app.core import security as sec
from app.core.config import settings
from app.features.auth import rate_limit
from app.features.auth.admin import repository, service
from app.features.auth.admin.schemas import AdminLogin
from app.main import app
from .test_registration import database

PASSWORD = ' Admin Password 123 '
HEADERS = {'X-Requested-With':'TrackChildrenAdmin'}


@pytest.fixture(scope='module')
def hashed():
    return sec.password_hasher.hash(PASSWORD)


@pytest.fixture
def admin_env(database,monkeypatch,tmp_path,hashed):
    monkeypatch.setattr(settings,'database_url',database)
    monkeypatch.setattr(settings,'auth_secret','admin-test-secret-123456789012345678901234')
    monkeypatch.setattr(settings,'app_env','local')
    monkeypatch.setattr(settings,'auth_rate_limit_path',str(tmp_path/'admin-rate.sqlite3'))
    from psycopg.rows import dict_row
    with psycopg.connect(database,autocommit=True,row_factory=dict_row) as db:
        db.execute('TRUNCATE admin.admin_users CASCADE')
        user=db.execute('''INSERT INTO admin.admin_users(email,password_hash,full_name)
            VALUES ('admin@example.com',%s,'Test Admin') RETURNING *''',(hashed,)).fetchone()
        db.execute('''INSERT INTO admin.admin_user_roles SELECT %s,id FROM admin.roles
            WHERE code='super_admin' ''',(user['id'],))
        with TestClient(app,client=('127.0.0.1',50000),headers=HEADERS) as client:
            yield client,db,user


def login(client,**changes):
    return client.post('/admin/auth/login',json={'email':'admin@example.com','password':PASSWORD,**changes})


def bearer(response):
    assert response.status_code==200,response.text
    return {'Authorization':'Bearer '+response.json()['accessToken']}


def error(response,status,code):
    assert response.status_code==status,response.text
    assert response.json()['error']['code']==code,response.text
    assert response.headers['cache-control']=='no-store'


@pytest.mark.parametrize('email',['admin@example.com',' ADMIN@EXAMPLE.COM ','Admin@Example.com'])
def test_login_profile_token_cookie_and_storage(admin_env,email):
    client,db,user=admin_env
    response=login(client,email=email)
    auth=bearer(response)
    data=response.json()
    assert set(data)=={'accessToken','tokenType','expiresIn','admin'}
    assert data['tokenType']=='Bearer' and 0<data['expiresIn']<=900
    assert data['admin']['id']==str(user['id'])
    assert data['admin']['role']=='super_admin'
    assert 'health.write' in data['admin']['permissions']
    claims=jwt.decode(data['accessToken'],settings.auth_secret,algorithms=['HS256'],
                      audience=settings.auth_admin_audience,issuer=settings.auth_issuer)
    assert claims['sub']==str(user['id'])
    row=db.execute('SELECT * FROM admin.admin_sessions').fetchone()
    assert str(row['id'])==claims['sid']
    assert row['refresh_token_hash']==sec.secret_hash(client.cookies.get('tc_admin_refresh'))
    assert abs((row['expires_at']-row['created_at']).total_seconds()-28800)<3
    assert db.execute('SELECT last_login_at FROM admin.admin_users').fetchone()['last_login_at']
    cookie=response.headers['set-cookie']
    assert 'HttpOnly' in cookie and 'SameSite=strict' in cookie and 'Path=/' in cookie
    assert 'Secure' not in cookie
    assert client.get('/admin/auth/me',headers=auth).json()==data['admin']
    assert not any(k in str(data['admin']).lower() for k in ['password','refresh_token'])


@pytest.mark.parametrize('changes',[{'password':'wrong'},{'email':'missing@example.com'},
    {'password':PASSWORD.strip()},{'password':"' OR 1=1 --"}])
def test_invalid_credentials(admin_env,changes):
    client,db,_=admin_env
    error(login(client,**changes),401,'INVALID_CREDENTIALS')
    assert db.execute('SELECT count(*) n FROM admin.admin_sessions').fetchone()['n']==0


@pytest.mark.parametrize('body',[{}, {'email':'bad','password':PASSWORD},
    {'email':'admin@example.com'}, {'email':None,'password':PASSWORD},
    {'email':'admin@example.com','password':None},{'email':'admin@example.com','password':''},
    {'email':'admin@example.com','password':'x'*1025},
    {'email':'admin@example.com','password':123},
    {'email':'admin@example.com','password':PASSWORD,'role':'super_admin'},
    {'email':'x'*250+'@example.com','password':PASSWORD}])
def test_login_validation(admin_env,body):
    client,db,_=admin_env
    error(client.post('/admin/auth/login',json=body),422,'VALIDATION_ERROR')
    assert db.execute('SELECT count(*) n FROM admin.admin_sessions').fetchone()['n']==0


@pytest.mark.parametrize('path',['login','refresh','logout','change-password'])
@pytest.mark.parametrize('header',[None,'wrong'])
def test_csrf_header_is_required(monkeypatch,path,header):
    monkeypatch.setattr(settings,'auth_secret','x'*32)
    headers={} if header is None else {'X-Requested-With':header}
    error(TestClient(app).post('/admin/auth/'+path,headers=headers,json={}),403,'CSRF_REJECTED')


@pytest.mark.parametrize('path',['login','refresh','logout','change-password','me'])
def test_unconfigured_secret(monkeypatch,path):
    monkeypatch.setattr(settings,'auth_secret','')
    client=TestClient(app,headers=HEADERS)
    response=client.get('/admin/auth/me') if path=='me' else client.post('/admin/auth/'+path,json={})
    error(response,503,'AUTH_NOT_CONFIGURED')


@pytest.mark.parametrize('password',[PASSWORD,'wrong'])
def test_disabled_account(admin_env,password):
    client,db,_=admin_env
    db.execute('UPDATE admin.admin_users SET is_active=false')
    error(login(client,password=password),403 if password==PASSWORD else 401,
          'ACCOUNT_UNAVAILABLE' if password==PASSWORD else 'INVALID_CREDENTIALS')


def test_legacy_bcrypt_upgrade(admin_env):
    client,db,_=admin_env
    db.execute("UPDATE admin.admin_users SET password_hash=crypt(%s,gen_salt('bf',4))",(PASSWORD,))
    error(login(client,password='wrong'),401,'INVALID_CREDENTIALS')
    bearer(login(client))
    assert sec.verify_password(PASSWORD,db.execute('SELECT password_hash FROM admin.admin_users').fetchone()['password_hash'])


def test_malformed_hash_is_invalid_credentials(admin_env):
    client,db,_=admin_env
    db.execute("UPDATE admin.admin_users SET password_hash='invalid'")
    error(login(client),401,'INVALID_CREDENTIALS')


def test_email_throttle_reset_and_expiry(admin_env,monkeypatch):
    client,_,_=admin_env
    for _ in range(4):error(login(client,password='bad'),401,'INVALID_CREDENTIALS')
    bearer(login(client))
    for _ in range(5):error(login(client,password='bad'),401,'INVALID_CREDENTIALS')
    result=login(client,email=' ADMIN@EXAMPLE.COM ')
    error(result,429,'RATE_LIMITED')
    assert 0<int(result.headers['retry-after'])<=900
    now=rate_limit.time.time()
    monkeypatch.setattr(rate_limit.time,'time',lambda:now+901)
    bearer(login(client))


def test_unknown_email_throttled(admin_env):
    client,_,_=admin_env
    for _ in range(5):error(login(client,email='missing@example.com'),401,'INVALID_CREDENTIALS')
    error(login(client,email=' MISSING@EXAMPLE.COM '),429,'RATE_LIMITED')


def test_ip_throttle_ignores_forwarded_header(admin_env):
    client,_,_=admin_env
    for i in range(30):error(login(client,email=f'absent{i}@example.com'),401,'INVALID_CREDENTIALS')
    error(client.post('/admin/auth/login',headers={'X-Forwarded-For':'1.2.3.4'},
        json={'email':'fresh@example.com','password':PASSWORD}),429,'RATE_LIMITED')


def test_limiter_unavailable_fails_closed(admin_env,monkeypatch):
    client,db,_=admin_env
    def fail(*args):raise OSError('unavailable')
    monkeypatch.setattr(rate_limit,'consume',fail)
    error(login(client),503,'RATE_LIMIT_UNAVAILABLE')
    assert db.execute('SELECT count(*) n FROM admin.admin_sessions').fetchone()['n']==0


def test_refresh_rotates_and_preserves_absolute_expiry(admin_env):
    client,db,_=admin_env
    auth=bearer(login(client))
    old=client.cookies.get('tc_admin_refresh')
    expiry=db.execute('SELECT expires_at FROM admin.admin_sessions').fetchone()['expires_at']
    bearer(client.post('/admin/auth/refresh'))
    new=client.cookies.get('tc_admin_refresh')
    assert old!=new
    assert db.execute('SELECT expires_at FROM admin.admin_sessions').fetchone()['expires_at']==expiry
    assert client.get('/admin/auth/me',headers=auth).status_code==200
    with TestClient(app,headers={**HEADERS,'Cookie':'tc_admin_refresh='+old}) as other:
        error(other.post('/admin/auth/refresh'),401,'SESSION_EXPIRED')
    bearer(client.post('/admin/auth/refresh'))


@pytest.mark.parametrize('state',['expired','revoked','disabled','missing','unknown'])
def test_refresh_invalid_state(admin_env,state):
    client,db,_=admin_env
    bearer(login(client))
    if state=='expired':db.execute("UPDATE admin.admin_sessions SET expires_at=now()-interval '1 second'")
    elif state=='revoked':db.execute('UPDATE admin.admin_sessions SET revoked_at=now()')
    elif state=='disabled':db.execute('UPDATE admin.admin_users SET is_active=false')
    elif state=='missing':client.cookies.clear()
    elif state=='unknown':client.cookies.clear();client.cookies.set('tc_admin_refresh','unknown')
    response=client.post('/admin/auth/refresh')
    error(response,401,'SESSION_EXPIRED')
    assert 'Max-Age=0' in response.headers['set-cookie']


def test_concurrent_refresh_allows_one_use(admin_env):
    client,db,_=admin_env
    bearer(login(client))
    raw=client.cookies.get('tc_admin_refresh')
    def refresh(_):
        with TestClient(app,headers={**HEADERS,'Cookie':'tc_admin_refresh='+raw}) as c:
            return c.post('/admin/auth/refresh').status_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(refresh,range(2)))==[200,401]
    assert db.execute('SELECT count(*) n FROM admin.admin_sessions').fetchone()['n']==1


@pytest.mark.parametrize('header',['','Basic x','Bearer junk','Bearer ','Bearer null'])
def test_me_rejects_bad_tokens(admin_env,header):
    client,_,_=admin_env
    error(client.get('/admin/auth/me',headers={'Authorization':header}),401,'ACCESS_TOKEN_INVALID')


@pytest.mark.parametrize('change',['aud','iss','sub','sid','exp','signature','missing-claim'])
def test_me_rejects_invalid_claims(admin_env,change):
    client,_,_=admin_env
    response=login(client)
    claims=jwt.decode(response.json()['accessToken'],options={'verify_signature':False})
    if change=='aud':claims['aud']=settings.auth_audience
    elif change=='iss':claims['iss']='wrong'
    elif change in ('sub','sid'):claims[change]=str(uuid4())
    elif change=='exp':claims['exp']=int(sec.now().timestamp())-1
    elif change=='missing-claim':del claims['sid']
    raw=jwt.encode(claims,'wrong-secret-with-at-least-32-chars' if change=='signature' else settings.auth_secret,algorithm='HS256')
    code='ACCESS_TOKEN_EXPIRED' if change=='exp' else 'SESSION_REVOKED' if change in ('sub','sid') else 'ACCESS_TOKEN_INVALID'
    error(client.get('/admin/auth/me',headers={'Authorization':'Bearer '+raw}),401,code)


@pytest.mark.parametrize('state',['expired','revoked','disabled','deleted'])
def test_live_session_state_checked(admin_env,state):
    client,db,_=admin_env
    auth=bearer(login(client))
    if state=='expired':db.execute("UPDATE admin.admin_sessions SET expires_at=now()-interval '1 second'")
    elif state=='revoked':db.execute('UPDATE admin.admin_sessions SET revoked_at=now()')
    elif state=='disabled':db.execute('UPDATE admin.admin_users SET is_active=false')
    else:db.execute('DELETE FROM admin.admin_sessions')
    status,code=(403,'ACCOUNT_UNAVAILABLE') if state=='disabled' else (401,'SESSION_EXPIRED') if state=='expired' else (401,'SESSION_REVOKED')
    error(client.get('/admin/auth/me',headers=auth),status,code)


def test_permissions_from_database_and_multiple_roles(admin_env):
    client,db,user=admin_env
    auth=bearer(login(client))
    db.execute('DELETE FROM admin.admin_user_roles')
    empty=client.get('/admin/auth/me',headers=auth).json()
    assert empty['roles']==[] and empty['permissions']==[]
    db.execute("INSERT INTO admin.admin_user_roles SELECT %s,id FROM admin.roles WHERE code IN ('support','moderator')",(user['id'],))
    data=client.get('/admin/auth/me',headers=auth).json()
    assert data['roles']==['moderator','support'] and data['role']=='moderator'
    assert 'user.read' in data['permissions'] and len(data['permissions'])==len(set(data['permissions']))
    assert client.get('/admin/vaccines',headers=auth).status_code==403


def test_logout_revokes_only_current_session_and_is_idempotent(admin_env):
    client,db,_=admin_env
    first=bearer(login(client))
    second=bearer(login(client))
    for _ in range(2):
        response=client.post('/admin/auth/logout')
        assert response.status_code==204 and response.content==b''
        assert 'Max-Age=0' in response.headers['set-cookie']
    error(client.get('/admin/auth/me',headers=second),401,'SESSION_REVOKED')
    assert client.get('/admin/auth/me',headers=first).status_code==200
    assert db.execute('SELECT count(*) n FROM admin.admin_sessions WHERE revoked_at IS NOT NULL').fetchone()['n']==1


@pytest.mark.parametrize('new',['short','a'*12,'12345678901',PASSWORD,'x'*129,'é'*10+'1'])
def test_change_password_policy(admin_env,new):
    client,db,_=admin_env
    auth=bearer(login(client))
    error(client.post('/admin/auth/change-password',headers=auth,
        json={'currentPassword':PASSWORD,'newPassword':new}),422,'VALIDATION_ERROR')
    assert sec.verify_password(PASSWORD,db.execute('SELECT password_hash FROM admin.admin_users').fetchone()['password_hash'])


def test_change_password_wrong_current_and_revoke_all(admin_env):
    client,db,_=admin_env
    first=bearer(login(client))
    second=bearer(login(client))
    error(client.post('/admin/auth/change-password',headers=second,
        json={'currentPassword':'wrong','newPassword':'NewPassword123'}),401,'INVALID_CREDENTIALS')
    response=client.post('/admin/auth/change-password',headers=second,
        json={'currentPassword':PASSWORD,'newPassword':'NewPassword123'})
    assert response.status_code==204
    for auth in [first,second]:error(client.get('/admin/auth/me',headers=auth),401,'SESSION_REVOKED')
    error(login(client),401,'INVALID_CREDENTIALS')
    bearer(login(client,password='NewPassword123'))


def test_production_cookie_secure(admin_env,monkeypatch):
    client,_,_=admin_env
    monkeypatch.setattr(settings,'app_env','production')
    assert 'Secure' in login(client).headers['set-cookie']


def test_database_failure_has_safe_error(monkeypatch):
    from contextlib import contextmanager
    from app.features.auth.admin import router
    monkeypatch.setattr(settings,'auth_secret','x'*32)
    @contextmanager
    def unavailable():
        raise psycopg.OperationalError('private database credentials')
        yield
    monkeypatch.setattr(router,'transaction',unavailable)
    response=TestClient(app,headers=HEADERS).post('/admin/auth/login',json={'email':'admin@example.com','password':PASSWORD})
    error(response,503,'DATABASE_UNAVAILABLE')
    assert 'private' not in response.text


def test_admin_openapi_contract():
    from openapi_spec_validator import validate
    document=json.loads((Path(__file__).parents[3]/'docs/api/admin-auth.openapi.json').read_text(encoding='utf-8'))
    validate(document)
    actual=app.openapi()['paths']
    for path,operations in document['paths'].items():
        for method,operation in operations.items():
            assert method in actual[path]
            assert ('200' if path.endswith(('/login','/refresh','/me')) else '204') in operation['responses']
