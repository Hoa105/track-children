from concurrent.futures import ThreadPoolExecutor
from datetime import date
from decimal import Decimal
from threading import Barrier
from uuid import uuid4
import json
from pathlib import Path
import psycopg
import pytest
from pydantic import ValidationError
from app.features.growth.schemas import SaveDay
from app.features.growth import service

DAY = '2026-10-15'
PAYLOAD = {'weightKg':8.4,'height':{'value':69.5,'measurePosition':'lying'},'headCircumferenceCm':43.7,'note':'original'}


def call(e, method='GET', tail='', body=None, actor='owner'):
    return e['client'].request(method, f"/api/v1/children/{e['child']}/growth{tail}",
        headers={'Authorization':'Bearer '+e['tokens'][actor]}, **({'json':body} if body is not None else {}))


def save(e, body=PAYLOAD, day=DAY, actor='owner'):
    return call(e,'PUT','/days/'+day,body,actor)


@pytest.mark.parametrize('body', [{},{'note':'x'},{'weightKg':None},{'weightKg':'8.4'},
    {'weightKg':True},{'weightKg':0},{'weightKg':-1},{'weightKg':200.01},
    {'height':{'value':250.01,'measurePosition':'lying'}},{'headCircumferenceCm':100.01},
    {'weightKg':8.401},{'height':{'value':69.5}},{'height':{'value':69.5,'measurePosition':'other'}},
    {'weightKg':8,'bmi':17},{'weightKg':8,'note':'x'*2001}, {'weightKg':float('inf')}])
def test_validation_unit(body):
    with pytest.raises(ValidationError): SaveDay.model_validate(body)


def test_bmi_and_contract():
    assert service.bmi(Decimal('8.4'),Decimal('69.5')) == 17.39
    assert service.bmi(10,100) == 10
    from openapi_spec_validator import validate
    validate(json.loads((Path(__file__).parents[3]/'docs/api/mobile-growth.openapi.json').read_text(encoding='utf-8')))


def test_empty_and_full(env,monkeypatch):
    monkeypatch.setenv('PGTZ','Asia/Ho_Chi_Minh')
    r=call(env).json()
    assert r['days']==[] and all(v is None for v in r['summary'].values())
    r=save(env)
    assert r.status_code==200, r.text
    d=r.json()
    assert len(d['measurements'])==3 and d['bmi']['value']==17.39
    assert all(m['ageInDays']==240 for m in d['measurements'])
    assert {m['unit'] for m in d['measurements']}=={'kg','cm'}
    assert all(m['createdAt'].endswith(('Z','+00:00')) for m in d['measurements'])
    assert all(m['updatedAt'].endswith(('Z','+00:00')) for m in call(env).json()['days'][0]['measurements'])


@pytest.mark.parametrize('actor,read,write', [('owner',200,200),('edit',200,200),('view',200,403),
    ('other',404,404),('none',404,404),('revoked',404,404),('left',404,404)])
def test_permissions(env,actor,read,write):
    assert call(env,actor=actor).status_code==read
    assert save(env,actor=actor).status_code==write
    m=save(env).json()['measurements'][0]['id']
    assert call(env,'DELETE','/measurements/'+m,actor=actor).status_code==(204 if write==200 else write)


def test_upsert_notes_and_bmi(env):
    first=save(env).json()
    assert {m['id'] for m in first['measurements']}=={m['id'] for m in save(env).json()['measurements']}
    r=save(env,{'weightKg':9}).json()
    assert r['bmi']['value']==service.bmi(9,69.5)
    assert all(m['note']=='original' for m in r['measurements'])
    r=save(env,{'weightKg':9,'note':None}).json()
    assert next(m for m in r['measurements'] if m['metric']=='weight')['note'] is None
    assert next(m for m in r['measurements'] if m['metric']=='height')['note']=='original'


def test_partial_dates_and_summary(env):
    save(env)
    save(env,{'weightKg':8.5},'2026-10-16')
    save(env,{'height':{'value':70,'measurePosition':'lying'}},'2026-10-17')
    r=call(env,tail='?from=2026-10-16&to=2026-10-17').json()
    assert len(r['days'])==2 and all(d['bmi'] is None for d in r['days'])
    assert r['summary']['bmi']['measuredAt']==DAY
    assert r['summary']['weight']['value']==8.5 and r['summary']['height']['value']==70
    assert call(env,tail='?from=2026-10-17&to=2026-10-16').status_code==422
    assert len(call(env,tail='?from='+DAY+'&to='+DAY).json()['days'])==1
    assert call(env,tail='?from=2027-01-01').json()['summary']['bmi']['value']==17.39


@pytest.mark.parametrize('day,status', [('2026-02-17',200),('2026-10-17',200),('2026-02-16',422),
    ('2026-10-18',422),('2026-02-30',422),('bad',422)])
def test_dates(env,day,status):
    assert save(env,{'weightKg':8},day).status_code==status


def test_delete_restore_and_foreign_id(env):
    first=save(env).json()
    mid=next(m['id'] for m in first['measurements'] if m['metric']=='weight')
    assert call(env,'DELETE','/measurements/'+mid).status_code==204
    assert call(env).json()['days'][0]['bmi'] is None
    assert call(env,'DELETE','/measurements/'+mid).status_code==204
    assert call(env,'DELETE','/measurements/'+str(uuid4())).status_code==404
    result=save(env,{'weightKg':8.4}).json()
    assert next(m['id'] for m in result['measurements'] if m['metric']=='weight')!=mid
    with psycopg.connect(env['url']) as db:
        assert db.execute('SELECT deleted_by FROM growth.growth_measurements WHERE id=%s',(mid,)).fetchone()[0]==env['users']['owner']
    for m in result['measurements']: assert call(env,'DELETE','/measurements/'+m['id']).status_code==204
    assert call(env).json()['days']==[]


def test_rollback(env,monkeypatch):
    original=service.day_result
    def fail(*args): raise psycopg.OperationalError('injected after writes')
    monkeypatch.setattr(service,'day_result',fail)
    assert save(env).status_code==503
    monkeypatch.setattr(service,'day_result',original)
    assert call(env).json()['days']==[]


def test_concurrent_writes(env):
    barrier=Barrier(2)
    def run(body):
        barrier.wait()
        return save(env,body)
    with ThreadPoolExecutor(2) as pool:
        results=list(pool.map(run,[{'weightKg':8.4},{'height':{'value':69.5,'measurePosition':'lying'}}]))
    assert [r.status_code for r in results]==[200,200]
    r=call(env).json()['days'][0]
    assert len(r['measurements'])==2 and r['bmi']['value']==17.39
    barrier=Barrier(2)
    with ThreadPoolExecutor(2) as pool:
        assert all(r.status_code==200 for r in pool.map(run,[{'weightKg':9},{'weightKg':10}]))
    assert len(call(env).json()['days'][0]['measurements'])==2


def test_auth_and_child_profile(env):
    r=env['client'].get(f"/api/v1/children/{env['child']}/growth")
    assert r.status_code==401 and r.headers['WWW-Authenticate']=='Bearer'
    headers={'Authorization':'Bearer '+env['tokens']['owner']}
    r=env['client'].post('/api/v1/children',headers=headers,
        json={'fullName':'Same name','dateOfBirth':'2026-02-17','gender':'female'})
    assert r.status_code==201
    other_child=r.json()['id']
    mid=save(env).json()['measurements'][0]['id']
    assert env['client'].delete(f'/api/v1/children/{other_child}/growth/measurements/{mid}',headers=headers).status_code==404
    r=env['client'].put(f"/api/v1/children/{env['child']}",headers=headers,
        json={'fullName':'New name','dateOfBirth':'2026-03-17','gender':'male'})
    assert r.status_code==200
    assert call(env).json()['days'][0]['measurements'][0]['ageInDays']==212
    with psycopg.connect(env['url']) as db:
        db.execute('UPDATE account.user_sessions SET revoked_at=now() WHERE user_id=%s',(env['users']['owner'],))
    assert call(env).status_code==401
