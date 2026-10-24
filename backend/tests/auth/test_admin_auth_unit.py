"""Policy/error-boundary tests without a PostgreSQL service."""
from datetime import timedelta
from uuid import uuid4
from unittest.mock import Mock
import sqlite3

import pytest
from app.core import security as sec
from app.core.config import settings
from app.features.auth.admin import service, repository as repo
from app.features.auth.admin.schemas import AdminLogin, AdminPasswordChange
from app.features.auth.errors import failure


@pytest.fixture
def policy(monkeypatch):
    monkeypatch.setattr(settings,'auth_secret','admin-unit-secret-12345678901234567890')
    user=dict(id=uuid4(),is_active=True,password_hash='argon-hash',full_name='Test Admin')
    session=dict(id=uuid4(),expires_at=sec.now()+timedelta(hours=8),revoked_at=None)
    mocks={}
    for name,value in {'lock_by_email':user,'create_session':session,'profile':{'id':str(user['id'])},
        'set_password':None,'lock_refresh_user':user,'lock_refresh_session':session,
        'rotate_session':None,'lock_user':user,'revoke_all':None,'audit_account_change':None}.items():
        mocks[name]=Mock(return_value=value)
        monkeypatch.setattr(repo,name,mocks[name])
    for name,value in {'quota':None,'verify_password':True,'current_user':user}.items():
        mocks[name]=Mock(return_value=value)
        monkeypatch.setattr(service,name,mocks[name])
    mocks['clear']=Mock()
    monkeypatch.setattr(service.rate_limit,'clear',mocks['clear'])
    return user,session,mocks


def data():return AdminLogin(email='admin@example.com',password='AdminPassword123')


@pytest.mark.parametrize('position',[0,1])
def test_login_quota_prevents_password_check(policy,position):
    _,_,m=policy
    m['quota'].side_effect=([None] if position else [])+[failure(429,'RATE_LIMITED')]
    assert service.login(None,data(),'127.0.0.1').status_code==429
    m['verify_password'].assert_not_called()
    m['create_session'].assert_not_called()


@pytest.mark.parametrize('exists',[True,False])
def test_login_generic_credentials_error(policy,exists):
    _,_,m=policy
    if not exists:m['lock_by_email'].return_value=None
    m['verify_password'].return_value=False
    assert service.login(None,data(),'127.0.0.1').code=='INVALID_CREDENTIALS'
    m['create_session'].assert_not_called()
    if not exists:assert m['verify_password'].call_args.args[2]==sec.dummy_hash


def test_disabled_valid_password_cannot_create_session(policy):
    user,_,m=policy;user['is_active']=False
    assert service.login(None,data(),'127.0.0.1').code=='ACCOUNT_UNAVAILABLE'
    m['create_session'].assert_not_called()


@pytest.mark.parametrize('exception',[OSError('down'),sqlite3.OperationalError('down')])
def test_limiter_clear_failure_creates_no_session(policy,exception):
    _,_,m=policy;m['clear'].side_effect=exception
    assert service.login(None,data(),'127.0.0.1').code=='RATE_LIMIT_UNAVAILABLE'
    m['create_session'].assert_not_called()


def test_token_is_admin_audience_and_refresh_is_hashed(policy):
    import jwt
    user,session,m=policy
    result=service.login(None,data(),'127.0.0.1')
    assert len(result['refreshToken'])>=32
    assert m['create_session'].call_args.args[2]==sec.secret_hash(result['refreshToken'])
    claims=jwt.decode(result['accessToken'],settings.auth_secret,algorithms=['HS256'],
                      audience=settings.auth_admin_audience,issuer=settings.auth_issuer)
    assert claims['sub']==str(user['id']) and claims['sid']==str(session['id'])
    assert result['tokenType']=='Bearer' and 0<result['expiresIn']<=900
    assert result['sessionExpiresAt']==session['expires_at']


@pytest.mark.parametrize('state',['no-user','disabled','no-session','revoked','expired','expiry-equals-now'])
def test_refresh_states_do_not_rotate(policy,monkeypatch,state):
    user,session,m=policy
    if state=='no-user':m['lock_refresh_user'].return_value=None
    if state=='disabled':user['is_active']=False
    if state=='no-session':m['lock_refresh_session'].return_value=None
    if state=='revoked':session['revoked_at']=sec.now()
    if state=='expired':session['expires_at']=sec.now()-timedelta(seconds=1)
    if state=='expiry-equals-now':
        now=sec.now();session['expires_at']=now;monkeypatch.setattr(sec,'now',lambda:now)
    assert service.refresh(None,'raw').code=='SESSION_EXPIRED'
    m['rotate_session'].assert_not_called()


def test_refresh_retains_absolute_expiry_and_rotates_hash(policy):
    _,session,m=policy
    result=service.refresh(None,'old-token')
    assert result['refreshToken']!='old-token'
    assert result['sessionExpiresAt']==session['expires_at']
    m['rotate_session'].assert_called_once_with(None,session['id'],sec.secret_hash(result['refreshToken']))


@pytest.mark.parametrize('stage',[0,1])
def test_password_change_rechecks_session_after_user_lock(policy,stage):
    user,_,m=policy
    err=failure(401,'SESSION_REVOKED')
    m['current_user'].side_effect=([user] if stage else [])+[err]
    assert service.change_password(None,None,AdminPasswordChange(currentPassword='old',newPassword='NewPassword123')) is err
    m['set_password'].assert_not_called()
    m['revoke_all'].assert_not_called()


def test_wrong_current_password_does_not_write_or_revoke(policy):
    _,_,m=policy;m['verify_password'].return_value=False
    result=service.change_password(None,None,AdminPasswordChange(currentPassword='old',newPassword='NewPassword123'))
    assert result.code=='INVALID_CREDENTIALS'
    m['set_password'].assert_not_called();m['revoke_all'].assert_not_called()


def test_password_quota_prevents_verification(policy):
    _,_,m=policy;m['quota'].return_value=failure(429,'RATE_LIMITED')
    assert service.change_password(None,None,AdminPasswordChange(currentPassword='old',newPassword='NewPassword123')).status_code==429
    m['verify_password'].assert_not_called()


def test_password_change_hashes_and_revokes_all(policy):
    user,_,m=policy
    assert service.change_password(None,None,AdminPasswordChange(currentPassword='old',newPassword='NewPassword123')) is None
    assert sec.verify_password('NewPassword123',m['set_password'].call_args.args[2])
    m['revoke_all'].assert_called_once_with(None,user['id'])


@pytest.mark.parametrize('legacy',[True,False])
def test_password_hash_format_dispatch(monkeypatch,legacy):
    from app.features.auth.admin import service as svc
    legacy_check=Mock(return_value=True);argon_check=Mock(return_value=True)
    monkeypatch.setattr(repo,'verify_legacy_password',legacy_check)
    monkeypatch.setattr(sec,'verify_password',argon_check)
    hashed='$2b$test' if legacy else '$argon2id$test'
    assert svc.verify_password(None,'password',hashed)
    assert legacy_check.called is legacy
    assert argon_check.called is not legacy


@pytest.mark.parametrize('password', ['a'*73, 'é'*37, 'invalid\x00password'])
def test_bcrypt_unrepresentable_password_is_rejected(password):
    db=Mock()
    assert repo.verify_legacy_password(db,password,'$2b$test') is False
    db.execute.assert_not_called()


@pytest.mark.parametrize('stage',[0,1])
def test_profile_update_rechecks_session_after_user_lock(policy,stage,monkeypatch):
    from app.features.auth.admin.schemas import AdminProfileUpdate
    user,_,m=policy
    err=failure(401,'SESSION_REVOKED')
    m['current_user'].side_effect=([user] if stage else [])+[err]
    update=Mock();monkeypatch.setattr(repo,'update_profile',update)
    assert service.update_profile(None,None,AdminProfileUpdate(fullName='New Name')) is err
    update.assert_not_called();m['audit_account_change'].assert_not_called()


def test_profile_update_uses_server_identity_and_audits(policy,monkeypatch):
    from app.features.auth.admin.schemas import AdminProfileUpdate
    user,_,m=policy
    saved={**user,'full_name':'New Name'}
    update=Mock(return_value=saved);monkeypatch.setattr(repo,'update_profile',update)
    service.update_profile(None,None,AdminProfileUpdate(fullName=' New  Name '))
    update.assert_called_once_with(None,user['id'],'New Name')
    m['audit_account_change'].assert_called_once_with(None,user['id'],'profile.update',
        {'fullName':'Test Admin'},{'fullName':'New Name'})
    m['revoke_all'].assert_not_called()


def test_profile_noop_does_not_write_or_audit(policy,monkeypatch):
    from app.features.auth.admin.schemas import AdminProfileUpdate
    _,_,m=policy
    update=Mock();monkeypatch.setattr(repo,'update_profile',update)
    service.update_profile(None,None,AdminProfileUpdate(fullName=' Test  Admin '))
    update.assert_not_called();m['audit_account_change'].assert_not_called()
