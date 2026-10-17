from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4
import os
import jwt
import psycopg
import pytest
from argon2 import PasswordHasher
from app.features.growth.schemas import SaveDay
from .test_growth import call, save, PAYLOAD, DAY


@pytest.mark.parametrize('payload', [
    {'weightKg':200},{'height':{'value':250,'measurePosition':'standing'}},
    {'headCircumferenceCm':100},{'weightKg':0.01},{'weightKg':8.40},
    {'weightKg':8,'note':'x'*2000}])
def test_boundaries(env,payload):
    assert save(env,payload).status_code==200


@pytest.mark.parametrize('payload', [
    {}, {'note':'x'}, {'weightKg':None}, {'weightKg':'8.4'}, {'weightKg':True},
    {'weightKg':0}, {'weightKg':8.401}, {'weightKg':8, 'ageInDays':99},
    {'weightKg':8, 'createdBy':str(uuid4())}, {'height':{'value':70}},
    {'weightKg':8,'note':'x'*2001}])
def test_http_validation_no_write(env,payload):
    assert save(env,payload).status_code==422
    assert call(env).json()['days']==[]


@pytest.mark.parametrize('condition,code,status', [
    ('expired_token','ACCESS_TOKEN_EXPIRED',401), ('wrong_audience','ACCESS_TOKEN_INVALID',401),
    ('expired_session','SESSION_EXPIRED',401), ('revoked','SESSION_REVOKED',401),
    ('locked','ACCOUNT_UNAVAILABLE',403), ('deleted','ACCOUNT_UNAVAILABLE',403)])
def test_auth_states(env,condition,code,status):
    token=env['tokens']['owner']
    if condition in ('expired_token','wrong_audience'):
        claims=jwt.decode(token,os.environ['AUTH_SECRET'],algorithms=['HS256'],audience='mobile')
        if condition=='expired_token': claims['exp']=datetime.now(timezone.utc)-timedelta(seconds=10)
        else: claims['aud']='admin'
        env['tokens']['owner']=jwt.encode(claims,os.environ['AUTH_SECRET'],algorithm='HS256')
    else:
        with psycopg.connect(env['url']) as db:
            if condition=='expired_session':
                db.execute("UPDATE account.user_sessions SET expires_at=now()-interval '1 second' WHERE user_id=%s",(env['users']['owner'],))
            elif condition=='revoked':
                db.execute('UPDATE account.user_sessions SET revoked_at=now() WHERE user_id=%s',(env['users']['owner'],))
            elif condition=='deleted':
                db.execute("UPDATE account.users SET status='deleted',deleted_at=now() WHERE id=%s",(env['users']['owner'],))
            else: db.execute('UPDATE account.users SET status=%s WHERE id=%s',(condition,env['users']['owner']))
    r=save(env)
    assert r.status_code==status and r.json()['error']['code']==code


def test_missing_and_deleted_children_and_revoked_permission(env):
    assert call(env,actor='edit').status_code==200
    with psycopg.connect(env['url']) as db:
        db.execute("UPDATE child.child_members SET status='revoked' WHERE user_id=%s",(env['users']['edit'],))
    assert save(env,actor='edit').status_code==404
    with psycopg.connect(env['url']) as db:
        db.execute('UPDATE child.children SET deleted_at=now() WHERE id=%s',(env['child'],))
    assert call(env).status_code==404 and save(env).status_code==404


def test_audit_and_note_scope(env):
    r=save(env).json()
    save(env,{'weightKg':9,'note':''},actor='edit')
    with psycopg.connect(env['url']) as db:
        rows=db.execute('''SELECT metric,value,created_by,updated_by,note FROM growth.growth_measurements
            WHERE child_id=%s ORDER BY metric''',(env['child'],)).fetchall()
    for metric,value,creator,updater,note in rows:
        assert creator==env['users']['owner']
        assert updater==env['users']['edit' if metric=='weight' else 'owner']
        assert note==('' if metric=='weight' else 'original')


def test_delete_latest_reverts_summary(env):
    save(env)
    r=save(env,PAYLOAD,'2026-10-16').json()
    mid=next(m['id'] for m in r['measurements'] if m['metric']=='weight')
    call(env,'DELETE','/measurements/'+mid)
    summary=call(env).json()['summary']
    assert summary['bmi']['measuredAt']==DAY and summary['weight']['measuredAt']==DAY
    assert summary['height']['measuredAt']=='2026-10-16'


def test_concurrent_delete_update(env):
    mid=next(m['id'] for m in save(env).json()['measurements'] if m['metric']=='weight')
    barrier=Barrier(2)
    def remove(): barrier.wait(); return call(env,'DELETE','/measurements/'+mid)
    def update(): barrier.wait(); return save(env,{'weightKg':9})
    with ThreadPoolExecutor(2) as pool:
        a,b=pool.submit(remove),pool.submit(update)
        assert a.result().status_code==204 and b.result().status_code==200
    r=call(env).json()['days'][0]
    weights=[m for m in r['measurements'] if m['metric']=='weight']
    assert len(weights)<=1
    assert (r['bmi'] is None)==(not weights)


def test_session_login_refresh_logout(env):
    with psycopg.connect(env['url']) as db:
        db.execute('UPDATE account.users SET password_hash=%s WHERE id=%s',
            (PasswordHasher().hash('test-password-only'),env['users']['owner']))
    client=env['client']
    for i in range(5):
        assert client.post('/api/v1/auth/login',json={'email':'nobody@example.test','password':'wrong'}).status_code==401
    assert client.post('/api/v1/auth/login',json={'email':'nobody@example.test','password':'wrong'}).status_code==429
    r=client.post('/api/v1/auth/login',json={'email':'owner@example.test','password':'test-password-only'})
    assert r.status_code==200 and r.headers['cache-control']=='no-store'
    data=r.json()
    renewed=client.post('/api/v1/auth/refresh',json={'refreshToken':data['refreshToken']})
    assert renewed.status_code==200
    assert client.post('/api/v1/auth/refresh',json={'refreshToken':data['refreshToken']}).status_code==401
    token=renewed.json()
    headers={'Authorization':'Bearer '+token['accessToken']}
    assert client.get('/api/v1/children',headers=headers).status_code==200
    assert client.post('/api/v1/auth/logout',json={'refreshToken':token['refreshToken']}).status_code==204
    assert client.get('/api/v1/children',headers=headers).status_code==401


def test_http_response_contract(env):
    from jsonschema import Draft202012Validator
    import json
    from pathlib import Path
    spec=json.loads((Path(__file__).parents[3]/'docs/api/mobile-growth.openapi.json').read_text(encoding='utf-8'))
    save(env)
    for name,instance in [('GrowthResult',call(env).json()),('GrowthDay',save(env).json())]:
        Draft202012Validator({'$ref':'#/components/schemas/'+name,'components':spec['components']}).validate(instance)


def test_calendar_dates_and_birth_update_validation(env):
    assert save(env,{'weightKg':8},'2026-10-15T00:00:00Z').status_code==422
    assert call(env,tail='?from=2026-10-15T00:00:00Z').status_code==422
    save(env)
    headers={'Authorization':'Bearer '+env['tokens']['owner']}
    assert env['client'].put(f"/api/v1/children/{env['child']}",headers=headers,
        json={'fullName':'Child','dateOfBirth':'2026-10-16','gender':'male'}).status_code==422
    with psycopg.connect(env['url']) as db:
        db.execute("UPDATE child.children SET date_of_birth='2024-01-01' WHERE id=%s",(env['child'],))
    assert save(env,{'weightKg':4},'2024-02-29').status_code==200


def test_timezone_and_rounding(monkeypatch):
    from app.features.growth import service
    from decimal import Decimal
    from datetime import date
    original=service.datetime
    class Clock:
        @classmethod
        def now(cls,tz): return original(2026,10,17,17,1,tzinfo=timezone.utc).astimezone(tz)
    monkeypatch.setattr(service,'datetime',Clock)
    assert service.today()==date(2026,10,18)
    assert service.bmi(Decimal('1.005'),100)==1.01
