import pytest
from app.core.config import settings, Settings
from app.seed.local_auth import seed, SAMPLE_PASSWORD
from .conftest import DEVICE


def local_mode(monkeypatch):
    monkeypatch.setattr(settings, 'app_env', 'local')
    monkeypatch.setattr(settings, 'auth_skip_otp', True)


def test_local_register_login_session_logout(env, payload, monkeypatch):
    local_mode(monkeypatch)
    c, db, sms = env
    payload['password'] = SAMPLE_PASSWORD
    r = c.post('/api/v1/auth/register', json=payload)
    assert r.status_code == 201 and r.json()['requiresOtp'] is False
    assert not sms
    u = db.execute('SELECT * FROM account.users').fetchone()
    assert u['status'] == 'active' and u['phone_verified_at'] is None
    assert db.execute('SELECT count(*) n FROM account.verification_codes').fetchone()['n'] == 0
    body = dict(email=payload['email'], password=SAMPLE_PASSWORD, device=DEVICE)
    assert c.post('/api/v1/auth/login', json={**body, 'password':'wrong'}).status_code == 401
    result = c.post('/api/v1/auth/login', json=body)
    assert result.status_code == 200
    tokens = result.json()
    headers = {'Authorization':'Bearer ' + tokens['accessToken']}
    assert c.get('/api/v1/auth/me', headers=headers).status_code == 200
    refreshed = c.post('/api/v1/auth/refresh', json={'refreshToken':tokens['refreshToken']})
    assert refreshed.status_code == 200
    assert c.post('/api/v1/auth/logout', json={'refreshToken':refreshed.json()['refreshToken']}).status_code == 204
    assert c.get('/api/v1/auth/me', headers=headers).status_code == 401
    assert c.post('/api/v1/auth/register', json=payload).status_code == 409


def test_pending_user_can_login_locally(env, payload, monkeypatch):
    c, db, sms = env
    assert c.post('/api/v1/auth/register', json=payload).status_code == 201
    local_mode(monkeypatch)
    sms.clear()
    r = c.post('/api/v1/auth/login', json=dict(email=payload['email'], password=payload['password'], device=DEVICE))
    assert r.status_code == 200 and not sms
    assert r.json()['user']['phoneVerifiedAt'] is None


def test_sample_migration_idempotent_and_ten_logins(env, monkeypatch):
    local_mode(monkeypatch)
    c, db, sms = env
    seed(db)
    seed(db)
    db.commit()
    assert db.execute('SELECT count(*) n FROM account.users').fetchone()['n'] == 10
    for n in range(1, 11):
        r = c.post('/api/v1/auth/login', json=dict(email=f'parent{n:02}@example.com', password=SAMPLE_PASSWORD, device=DEVICE))
        assert r.status_code == 200, r.text
        assert r.json()['user']['status'] == 'active'
    assert not sms


def test_bypass_rejected_outside_local():
    with pytest.raises(ValueError, match='APP_ENV=local'):
        Settings(_env_file=None, app_env='production', auth_skip_otp=True)


def test_sample_migration_rejected_outside_local(monkeypatch):
    monkeypatch.setattr(settings, 'app_env', 'production')
    with pytest.raises(RuntimeError, match='APP_ENV=local'):
        seed(None)
