"""Login regression suite against an isolated, fully migrated PostgreSQL DB."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta

import jwt
import pytest

from app.core import security as sec
from app.core.config import settings
from .test_registration_v2 import database, env

PASSWORD = ' Mật khẩu test 123 '
DEVICE = {'platform': 'android', 'deviceId': 'login-test'}


@pytest.fixture(scope='module')
def password_hash():
    return sec.password_hasher.hash(PASSWORD)


@pytest.fixture
def login_env(env, monkeypatch, password_hash):
    c, db, sent = env
    if db.execute("SELECT to_regclass('account.auth_rate_limits') t").fetchone()['t']:
        db.execute('TRUNCATE account.auth_rate_limits')
    monkeypatch.setattr(settings, 'auth_skip_otp', False)
    monkeypatch.setattr(settings, 'app_env', 'local')
    user = db.execute('''INSERT INTO account.users
        (email,phone,password_hash,status,consented_at,email_verified_at,phone_verified_at)
        VALUES ('parent@example.com','+84912345678',%s,'active',now(),now(),now()) RETURNING *''',
        (password_hash,)).fetchone()
    return c, db, sent, user


def login(c, **changes):
    return c.post('/api/v1/auth/login', json={
        'email': 'parent@example.com', 'password': PASSWORD, 'device': DEVICE, **changes})


def error(response, status, code):
    assert response.status_code == status, response.text
    assert response.json()['error']['code'] == code, response.text


def seeded_session(login_env):
    """Exercise session endpoints independently of password-login availability."""
    _, db, _, user = login_env
    from uuid import uuid4
    raw = uuid4().hex
    expiry = sec.now() + timedelta(days=1)
    row = db.execute('''INSERT INTO account.user_sessions
        (user_id,refresh_token_hash,platform,expires_at)
        VALUES (%s,%s,'android',%s) RETURNING id''',
        (user['id'],sec.secret_hash(raw),expiry)).fetchone()
    return {'refreshToken':raw, 'accessToken':sec.access_token(
        user['id'],row['id'],sec.now()+timedelta(minutes=15))}


@pytest.mark.parametrize('contact', [
    {'email': 'parent@example.com'}, {'email': ' PARENT@EXAMPLE.COM '},
    {'email': None, 'phone': '0912345678'},
    {'email': None, 'phone': '+84912345678'},
    {'email': None, 'phone': '(091) 234-5678'},
])
@pytest.mark.parametrize('remember', [True, False])
def test_success_contact_normalization_and_session_lifetime(login_env, contact, remember):
    c, db, _, user = login_env
    r = login(c, **contact, rememberMe=remember)
    assert r.status_code == 200, r.text
    data = r.json()
    assert data['user']['id'] == str(user['id'])
    assert 'password' not in str(data['user']).lower()
    assert data['tokenType'] == 'Bearer' and 0 < data['expiresIn'] <= 900
    session = db.execute('SELECT * FROM account.user_sessions').fetchone()
    assert session['refresh_token_hash'] == sec.secret_hash(data['refreshToken'])
    assert session['remember_me'] is remember
    assert abs((session['expires_at'] - session['created_at']).total_seconds()
               - (30 if remember else 1) * 86400) < 2
    headers = {'Authorization': 'Bearer ' + data['accessToken']}
    assert c.get('/api/v1/auth/me', headers=headers).status_code == 200
    refreshed = c.post('/api/v1/auth/refresh', json={'refreshToken': data['refreshToken']})
    assert refreshed.status_code == 200
    assert refreshed.json()['refreshToken'] == data['refreshToken']
    assert c.post('/api/v1/auth/logout', json={'refreshToken': data['refreshToken']}).status_code == 204
    error(c.get('/api/v1/auth/me', headers=headers), 401, 'SESSION_REVOKED')
    error(c.post('/api/v1/auth/refresh', json={'refreshToken': data['refreshToken']}), 401, 'SESSION_REVOKED')


@pytest.mark.parametrize('changes', [
    {'password': ''}, {'password': 'x'*129}, {'password': None},
    {'email': None}, {'email': 'invalid'}, {'phone': '0912345678'},
    {'device': {}}, {'device': {'platform': 'windows'}},
    {'rememberMe': 'true'}, {'unexpected': True},
])
def test_invalid_input_creates_no_session(login_env, changes):
    c, db, _, _ = login_env
    error(login(c, **changes), 422, 'VALIDATION_ERROR')
    assert db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n'] == 0


@pytest.mark.parametrize('changes', [
    {'password': 'wrong'}, {'email': 'missing@example.com'},
    {'email': None, 'phone': '0987654321'}, {'password': PASSWORD.strip()},
    {'password': "' OR 1=1 --"},
])
def test_invalid_credentials_do_not_reveal_account(login_env, changes):
    c, db, _, _ = login_env
    error(login(c, **changes), 401, 'INVALID_CREDENTIALS')
    assert db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n'] == 0


def test_five_failures_lock_email_and_phone_then_unlock(login_env, monkeypatch):
    c, db, _, _ = login_env
    for _ in range(5):
        error(login(c, password='wrong'), 401, 'INVALID_CREDENTIALS')
    error(login(c), 429, 'LOGIN_TEMPORARILY_LOCKED')
    error(login(c, email=None, phone='0912345678'), 429, 'LOGIN_TEMPORARILY_LOCKED')
    db.execute("UPDATE account.users SET locked_until=now()-interval '1 second'")
    from app.features.auth import rate_limit
    original = rate_limit.time.time()
    monkeypatch.setattr(rate_limit.time, 'time', lambda: original+901)
    assert login(c).status_code == 200
    u = db.execute('SELECT * FROM account.users').fetchone()
    assert u['failed_login_attempts'] == 0 and u['locked_until'] is None


def test_success_resets_failed_attempts(login_env):
    c, db, _, _ = login_env
    for _ in range(4):
        error(login(c, password='wrong'), 401, 'INVALID_CREDENTIALS')
    assert login(c).status_code == 200
    assert login(c).status_code == 200
    assert db.execute('SELECT failed_login_attempts FROM account.users').fetchone()['failed_login_attempts'] == 0


def test_unknown_identifier_throttle(login_env):
    c, _, _, _ = login_env
    for _ in range(5):
        error(login(c, email='missing@example.com'), 401, 'INVALID_CREDENTIALS')
    r = login(c, email=' MISSING@EXAMPLE.COM ')
    error(r, 429, 'LOGIN_TEMPORARILY_LOCKED')
    assert int(r.headers['retry-after']) > 0


def test_ip_throttle_cannot_be_bypassed_with_forwarded_header(login_env):
    c, _, _, _ = login_env
    for i in range(30):
        r = login(c, email=f'missing{i}@example.com')
        error(r, 401, 'INVALID_CREDENTIALS')
    r = c.post('/api/v1/auth/login', headers={'X-Forwarded-For': '1.2.3.4'}, json={
        'email': 'fresh@example.com', 'password': PASSWORD, 'device': DEVICE})
    error(r, 429, 'RATE_LIMITED')


@pytest.mark.parametrize('state,code', [('locked','ACCOUNT_LOCKED'), ('deleted','ACCOUNT_UNAVAILABLE')])
def test_account_state_blocks_session(login_env, state, code):
    c, db, _, _ = login_env
    db.execute('UPDATE account.users SET status=%s', (state,))
    error(login(c), 403, code)
    assert db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n'] == 0


def test_pending_requires_otp_and_can_finish_login(login_env):
    c, db, sent, _ = login_env
    db.execute("UPDATE account.users SET status='pending',email_verified_at=NULL")
    r = login(c)
    error(r, 403, 'VERIFICATION_REQUIRED')
    assert db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n'] == 0
    ch = r.json()['error']['details']['registration']
    verified = c.post('/api/v1/auth/register/verify', json={
        'verificationId': ch['verificationId'], 'registrationToken': ch['registrationToken'],
        'code': sent[-1][2], 'device': DEVICE})
    assert verified.status_code == 200, verified.text


@pytest.mark.parametrize('kind', ['expired', 'revoked', 'locked', 'deleted'])
def test_session_state_checked_on_me_and_refresh(login_env, kind):
    c, db, _, _ = login_env
    data = seeded_session(login_env)
    if kind == 'expired':
        db.execute("UPDATE account.user_sessions SET expires_at=now()-interval '1 second'")
    elif kind == 'revoked':
        db.execute('UPDATE account.user_sessions SET revoked_at=now()')
    else:
        db.execute('UPDATE account.users SET status=%s', (kind,))
    code = {'expired':'SESSION_EXPIRED','revoked':'SESSION_REVOKED'}.get(kind, 'ACCOUNT_UNAVAILABLE')
    status = 401 if kind in ('expired','revoked') else 403
    error(c.get('/api/v1/auth/me', headers={'Authorization':'Bearer '+data['accessToken']}), status, code)
    error(c.post('/api/v1/auth/refresh', json={'refreshToken':data['refreshToken']}), status, code)


@pytest.mark.parametrize('kind', ['missing','malformed','expired','wrong-signature','wrong-audience','unknown-session'])
def test_access_token_boundaries(login_env, kind):
    c, _, _, _ = login_env
    raw = seeded_session(login_env)['accessToken']
    claims = jwt.decode(raw, options={'verify_signature':False})
    secret = settings.auth_secret
    if kind == 'missing':
        raw = ''
    elif kind == 'malformed':
        raw = 'not-a-jwt'
    elif kind == 'expired':
        claims['exp'] = sec.now()-timedelta(seconds=1)
    elif kind == 'wrong-signature':
        secret = 'untrusted-test-signing-key-1234567890'
    elif kind == 'wrong-audience':
        claims['aud'] = 'another-app'
    else:
        claims['sid'] = '00000000-0000-4000-8000-000000000001'
    if kind not in ('missing','malformed'):
        raw = jwt.encode(claims, secret, algorithm='HS256')
    r = c.get('/api/v1/auth/me', headers={'Authorization':'Bearer '+raw} if raw else {})
    error(r, 401, 'ACCESS_TOKEN_EXPIRED' if kind == 'expired' else
          'SESSION_REVOKED' if kind == 'unknown-session' else 'ACCESS_TOKEN_INVALID')


def test_logout_idempotent_and_other_session_survives(login_env):
    c, _, _, _ = login_env
    first, second = seeded_session(login_env), seeded_session(login_env)
    for raw in [first['refreshToken'], first['refreshToken'], 'unknown-token']:
        assert c.post('/api/v1/auth/logout', json={'refreshToken':raw}).status_code == 204
    assert c.get('/api/v1/auth/me', headers={'Authorization':'Bearer '+second['accessToken']}).status_code == 200
    error(c.post('/api/v1/auth/refresh', json={'refreshToken':'unknown-token'}), 401, 'REFRESH_TOKEN_INVALID')


def test_concurrent_login_preserves_failed_attempt_count(login_env):
    c, db, _, _ = login_env
    with ThreadPoolExecutor(max_workers=5) as pool:
        results = list(pool.map(lambda _: login(c, password='wrong'), range(5)))
    assert [r.status_code for r in results] == [401]*5
    assert db.execute('SELECT failed_login_attempts FROM account.users').fetchone()['failed_login_attempts'] == 5
    error(login(c), 429, 'LOGIN_TEMPORARILY_LOCKED')


def test_auth_not_configured(login_env, monkeypatch):
    c, db, _, _ = login_env
    monkeypatch.setattr(settings, 'auth_secret', '')
    error(login(c), 503, 'AUTH_NOT_CONFIGURED')
    assert db.execute('SELECT count(*) n FROM account.user_sessions').fetchone()['n'] == 0


def test_concurrent_refresh_and_logout_always_revokes_session(login_env):
    c, _, _, _ = login_env
    data = seeded_session(login_env)
    with ThreadPoolExecutor(max_workers=2) as pool:
        refresh = pool.submit(c.post, '/api/v1/auth/refresh', json={'refreshToken':data['refreshToken']})
        logout = pool.submit(c.post, '/api/v1/auth/logout', json={'refreshToken':data['refreshToken']})
        assert refresh.result().status_code in (200,401)
        assert logout.result().status_code == 204
    error(c.get('/api/v1/auth/me', headers={'Authorization':'Bearer '+data['accessToken']}), 401, 'SESSION_REVOKED')


def test_database_outage_returns_structured_error(login_env, monkeypatch):
    import psycopg
    from app.features.auth import router
    c, _, _, _ = login_env
    def offline():
        raise psycopg.OperationalError('test database unavailable')
    monkeypatch.setattr(router, 'transaction', offline)
    error(login(c), 503, 'DATABASE_UNAVAILABLE')
