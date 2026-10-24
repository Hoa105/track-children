"""Admin account update/password contracts, security boundaries and transactions."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path

from fastapi.testclient import TestClient
import psycopg
import pytest
from jsonschema import Draft202012Validator

from app.core import security as sec
from app.features.auth.admin import repository
from app.main import app
from .test_registration_v2 import database
from .test_admin_auth import admin_env, hashed, login, bearer, error, PASSWORD, HEADERS


@pytest.mark.parametrize('name,normalized',[
    ('  Admin   Updated  ','Admin Updated'),('Nguyễn Thị Ánh','Nguyễn Thị Ánh'),
    ('A B','A B'),('Ab','Ab'),('A'*150,'A'*150),('Admin\u00a0Name','Admin Name'),
    ("Name', is_active=false --","Name', is_active=false --"),
])
def test_update_profile_persists_and_audits(admin_env,name,normalized):
    client,db,user=admin_env
    auth=bearer(login(client))
    before=db.execute('SELECT * FROM admin.admin_users').fetchone()
    response=client.patch('/admin/auth/me',headers=auth,json={'fullName':name})
    assert response.status_code==200,response.text
    assert response.headers['cache-control']=='no-store'
    result=response.json()
    assert result['fullName']==normalized and result['email']==user['email']
    row=db.execute('SELECT * FROM admin.admin_users').fetchone()
    assert row['full_name']==normalized and row['is_active']
    assert row['password_hash']==before['password_hash']
    assert row['updated_at']>=before['updated_at']
    assert client.get('/admin/auth/me',headers=auth).json()==result
    refreshed=client.post('/admin/auth/refresh')
    assert refreshed.status_code==200 and refreshed.json()['admin']['fullName']==normalized
    audit=db.execute('SELECT * FROM admin.admin_audit_logs').fetchone()
    assert audit['action']=='profile.update' and audit['admin_user_id']==user['id']
    assert audit['before_data']=={'fullName':'Test Admin'}
    assert audit['after_data']=={'fullName':normalized}
    document=json.loads((Path(__file__).parents[3]/'docs/api/admin-auth.openapi.json').read_text(encoding='utf-8'))
    Draft202012Validator({'$ref':'#/components/schemas/AdminProfile','components':document['components']}).validate(result)


@pytest.mark.parametrize('body',[{},None,[],{'fullName':None},{'fullName':123},
    {'fullName':''},{'fullName':' '},{'fullName':' A '},{'fullName':'A'*151},
    {'fullName':'A\nB'},{'fullName':'A\tB'},{'fullName':'A\x00B'},{'fullName':'A\u200bB'},
    {'fullName':'A\u202eB'}, {'fullName':'New Name','email':'attacker@example.com'},
    {'fullName':'New Name','role':'super_admin'},{'fullName':'New Name','roles':['super_admin']},
    {'fullName':'New Name','permissions':['admin.manage']},
    {'fullName':'New Name','is_active':False},{'fullName':'New Name','id':'someone-else'},
    {'fullName':'New Name','password_hash':'fake'},{'email':'new@example.com'}])
def test_profile_validation_and_mass_assignment(admin_env,body):
    client,db,_=admin_env
    auth=bearer(login(client))
    error(client.patch('/admin/auth/me',headers=auth,json=body),422,'VALIDATION_ERROR')
    assert db.execute('SELECT full_name FROM admin.admin_users').fetchone()['full_name']=='Test Admin'
    assert db.execute('SELECT count(*) n FROM admin.admin_audit_logs').fetchone()['n']==0


def test_profile_update_noop_and_preserves_all_sessions(admin_env):
    client,db,_=admin_env
    first=bearer(login(client)); second=bearer(login(client))
    before=db.execute('SELECT updated_at FROM admin.admin_users').fetchone()['updated_at']
    assert client.patch('/admin/auth/me',headers=first,json={'fullName':'  Test   Admin '}).status_code==200
    assert db.execute('SELECT updated_at FROM admin.admin_users').fetchone()['updated_at']==before
    assert db.execute('SELECT count(*) n FROM admin.admin_audit_logs').fetchone()['n']==0
    assert client.get('/admin/auth/me',headers=second).status_code==200
    assert client.post('/admin/auth/refresh').status_code==200


def test_profile_update_targets_jwt_owner_only_and_requires_no_management_role(admin_env):
    client,db,user=admin_env
    auth=bearer(login(client))
    other=db.execute('''INSERT INTO admin.admin_users(email,password_hash,full_name)
        VALUES ('other@example.com',%s,'Other Admin') RETURNING *''',(user['password_hash'],)).fetchone()
    db.execute('DELETE FROM admin.admin_user_roles WHERE admin_user_id=%s',(user['id'],))
    response=client.patch('/admin/auth/me',headers=auth,json={'fullName':'My New Name'})
    assert response.status_code==200 and response.json()['permissions']==[]
    assert db.execute('SELECT full_name FROM admin.admin_users WHERE id=%s',(other['id'],)).fetchone()['full_name']=='Other Admin'


@pytest.mark.parametrize('endpoint,method,body',[
    ('/admin/auth/me','patch',{'fullName':'New Admin'}),
    ('/admin/auth/change-password','post',{'currentPassword':PASSWORD,'newPassword':'NextPassword123'})])
@pytest.mark.parametrize('state',['missing-token','mobile-token','expired-token','revoked','session-expired','disabled','deleted'])
def test_account_mutation_requires_live_admin_session(admin_env,endpoint,method,body,state):
    import jwt
    from app.core.config import settings
    client,db,_=admin_env
    auth=bearer(login(client))
    if state=='missing-token':auth={'Authorization':''}
    elif state in ('mobile-token','expired-token'):
        claims=jwt.decode(auth['Authorization'].split()[1],options={'verify_signature':False})
        if state=='mobile-token':claims['aud']=settings.auth_audience
        else:claims['exp']=int(sec.now().timestamp())-1
        auth={'Authorization':'Bearer '+jwt.encode(claims,settings.auth_secret,algorithm='HS256')}
    elif state=='revoked':db.execute('UPDATE admin.admin_sessions SET revoked_at=now()')
    elif state=='session-expired':db.execute("UPDATE admin.admin_sessions SET expires_at=now()-interval '1 second'")
    elif state=='disabled':db.execute('UPDATE admin.admin_users SET is_active=false')
    else:db.execute('DELETE FROM admin.admin_sessions')
    response=getattr(client,method)(endpoint,headers=auth,json=body)
    assert response.status_code==(403 if state=='disabled' else 401),response.text
    assert db.execute('SELECT full_name FROM admin.admin_users').fetchone()['full_name']=='Test Admin'
    assert db.execute('SELECT count(*) n FROM admin.admin_audit_logs').fetchone()['n']==0


def test_profile_patch_requires_csrf_header(admin_env):
    client,db,_=admin_env
    auth=bearer(login(client))
    # Override the client's default valid header.
    error(client.patch('/admin/auth/me',headers={**auth,'X-Requested-With':'wrong'},
        json={'fullName':'New Name'}),403,'CSRF_REJECTED')


@pytest.mark.parametrize('endpoint,method,body',[
    ('/admin/auth/me','patch',{'fullName':'New Admin'}),
    ('/admin/auth/change-password','post',{'currentPassword':PASSWORD,'newPassword':'NextPassword123'})])
def test_audit_failure_rolls_back_entire_account_change(admin_env,monkeypatch,endpoint,method,body):
    client,db,_=admin_env
    auth=bearer(login(client))
    original=db.execute('SELECT * FROM admin.admin_users').fetchone()
    def fail(*args):raise psycopg.OperationalError('test audit failure')
    monkeypatch.setattr(repository,'audit_account_change',fail)
    error(getattr(client,method)(endpoint,headers=auth,json=body),503,'DATABASE_UNAVAILABLE')
    row=db.execute('SELECT * FROM admin.admin_users').fetchone()
    assert row['full_name']==original['full_name'] and row['password_hash']==original['password_hash']
    assert row['updated_at']==original['updated_at']
    assert client.get('/admin/auth/me',headers=auth).status_code==200
    assert db.execute('SELECT count(*) n FROM admin.admin_sessions WHERE revoked_at IS NOT NULL').fetchone()['n']==0


def test_password_change_audit_contains_no_credentials(admin_env):
    client,db,user=admin_env
    auth=bearer(login(client)); old_cookie=client.cookies.get('tc_admin_refresh')
    response=client.post('/admin/auth/change-password',headers=auth,
        json={'currentPassword':PASSWORD,'newPassword':'NextPassword123'})
    assert response.status_code==204 and response.content==b''
    assert 'Max-Age=0' in response.headers['set-cookie']
    audit=db.execute('SELECT * FROM admin.admin_audit_logs').fetchone()
    assert audit['action']=='password.change' and audit['admin_user_id']==user['id']
    assert audit['before_data'] is None and audit['after_data'] is None
    for value in [PASSWORD,'NextPassword123',old_cookie,auth['Authorization']]:
        assert value not in str(audit)
    assert db.execute('SELECT count(*) n FROM admin.admin_sessions WHERE revoked_at IS NULL').fetchone()['n']==0
    with TestClient(app,headers={**HEADERS,'Cookie':'tc_admin_refresh='+old_cookie}) as other:
        error(other.post('/admin/auth/refresh'),401,'SESSION_EXPIRED')
    bearer(login(client,password='NextPassword123'))


@pytest.mark.parametrize('new',['Ab12345678','A1'+'x'*126])
def test_password_policy_exact_boundaries(admin_env,new):
    client,db,_=admin_env
    auth=bearer(login(client))
    assert client.post('/admin/auth/change-password',headers=auth,
        json={'currentPassword':PASSWORD,'newPassword':new}).status_code==204
    assert sec.verify_password(new,db.execute('SELECT password_hash FROM admin.admin_users').fetchone()['password_hash'])


@pytest.mark.parametrize('body',[{}, {'currentPassword':None,'newPassword':'NextPassword123'},
    {'currentPassword':'','newPassword':'NextPassword123'},
    {'currentPassword':PASSWORD,'newPassword':None},
    {'currentPassword':PASSWORD,'newPassword':'NextPassword123','adminId':'other'},
    {'currentPassword':'x'*1025,'newPassword':'NextPassword123'}])
def test_password_body_validation(admin_env,body):
    client,db,_=admin_env
    auth=bearer(login(client))
    error(client.post('/admin/auth/change-password',headers=auth,json=body),422,'VALIDATION_ERROR')
    assert db.execute('SELECT count(*) n FROM admin.admin_audit_logs').fetchone()['n']==0


def test_password_change_rate_limit_does_not_revoke_session(admin_env):
    client,db,_=admin_env
    auth=bearer(login(client))
    for _ in range(5):
        error(client.post('/admin/auth/change-password',headers=auth,
            json={'currentPassword':'wrong','newPassword':'NextPassword123'}),401,'INVALID_CREDENTIALS')
    response=client.post('/admin/auth/change-password',headers=auth,
        json={'currentPassword':PASSWORD,'newPassword':'NextPassword123'})
    error(response,429,'RATE_LIMITED')
    assert int(response.headers['retry-after'])>0
    assert client.get('/admin/auth/me',headers=auth).status_code==200
    assert db.execute('SELECT count(*) n FROM admin.admin_audit_logs').fetchone()['n']==0


def test_concurrent_password_changes_allow_only_one_success(admin_env):
    client,db,_=admin_env
    auth=bearer(login(client))
    def change(_):
        with TestClient(app,headers=HEADERS) as other:
            return other.post('/admin/auth/change-password',headers=auth,
                json={'currentPassword':PASSWORD,'newPassword':'NextPassword123'}).status_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(change,range(2)))==[204,401]
    assert db.execute('SELECT count(*) n FROM admin.admin_audit_logs').fetchone()['n']==1


def test_concurrent_profile_updates_audit_previous_committed_name(admin_env):
    client,db,_=admin_env
    auth=bearer(login(client))
    names=['First Name','Second Name']
    def update(name):
        with TestClient(app,headers=HEADERS) as other:
            return other.patch('/admin/auth/me',headers=auth,json={'fullName':name}).status_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert list(pool.map(update,names))==[200,200]
    logs=db.execute('SELECT * FROM admin.admin_audit_logs ORDER BY id').fetchall()
    assert len(logs)==2 and logs[0]['before_data']=={'fullName':'Test Admin'}
    assert logs[1]['before_data']==logs[0]['after_data']
    assert db.execute('SELECT full_name FROM admin.admin_users').fetchone()['full_name']==logs[-1]['after_data']['fullName']
