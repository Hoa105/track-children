"""Opt-in local baseline; records measurements, not a production SLA assertion."""
import os
import json
import time
from datetime import date,timedelta
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import psycopg
import pytest
from .test_growth import call,save


@pytest.mark.skipif(os.environ.get('GROWTH_PERF')!='1',reason='Opt-in local performance baseline')
def test_five_year_history(env):
    birth=date(2021,10,17)
    with psycopg.connect(env['url']) as db:
        db.execute('UPDATE child.children SET date_of_birth=%s WHERE id=%s',(birth,env['child']))
        with db.cursor() as cur:
            cur.executemany('''INSERT INTO growth.growth_measurements
                (child_id,metric,value,measure_position,measured_at,age_in_days,created_by)
                VALUES (%s,%s,%s,%s,%s,%s,%s)''',[
                (env['child'],metric,value,position,birth+timedelta(days=i),i,env['users']['owner'])
                for i in range(1826) for metric,value,position in
                [('weight',10,None),('height',100,'standing'),('head_circumference',45,None)]])
    def measure(kind):
        started=time.perf_counter()
        if kind=='getAll': r=call(env)
        elif kind=='getRange': r=call(env,tail='?from=2026-10-01&to=2026-10-17')
        elif kind=='put': r=save(env,{'weightKg':11})
        else:
            record=save(env,{'headCircumferenceCm':46}).json()
            mid=next(m['id'] for m in record['measurements'] if m['metric']=='head_circumference')
            r=call(env,'DELETE','/measurements/'+mid)
        assert r.status_code in (200,204),r.text
        return (time.perf_counter()-started)*1000,len(r.content)
    report={'environment':'Windows host, Docker PostgreSQL 16, FastAPI TestClient; not production or physical-device network',
        'concurrency':20,'days':1826,'measurements':5478,'results':{}}
    for kind in ['getAll','getRange','put']:
        with ThreadPoolExecutor(20) as pool: samples=list(pool.map(measure,[kind]*20))
        values=sorted(t for t,size in samples)
        report['results'][kind]={'p50Ms':round(values[9],2),'p95Ms':round(values[18],2),
            'responseBytes':samples[0][1],'errors':0}
    # A single deletion baseline avoids concurrent delete/upsert intentionally changing IDs.
    elapsed,size=measure('delete')
    report['results']['deleteIncludingSetup']={'ms':round(elapsed,2),'responseBytes':size,'errors':0}
    target=Path(__file__).parents[3]/'docs/api/mobile-growth-performance.json'
    target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
