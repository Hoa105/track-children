"""Full backend/Flutter run on isolated disposable databases, never app data."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import argparse
import re
import socket
import shutil
import urllib.request
from urllib.parse import quote

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
sys.path.insert(0,str(ROOT/'backend'))
sys.path.insert(0,str(ROOT/'backend/scripts'))
import psycopg
from psycopg import sql
from psycopg.conninfo import conninfo_to_dict,make_conninfo
from prepare_auth_v2_test_db import test_url,TEST_DB
from scripts.test_auth_high_risk import backend_counts,flutter_counts


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only',choices=['all','backend','flutter','analyze'],default='all')
    parser.add_argument('--backend-paths',nargs='+',default=['tests'])
    parser.add_argument('--flutter-paths',nargs='*',default=[])
    parser.add_argument('--auth-only',action='store_true',help='Complete auth suites, including disposable migration replay and live HTTP')
    parser.add_argument('--flutter-sdk',type=Path)
    args=parser.parse_args()
    if args.auth_only:
        args.backend_paths=['tests/auth',*[str(p.relative_to(ROOT/'backend')).replace('\\','/') for p in sorted((ROOT/'backend/tests').glob('test_auth*.py'))]]
        args.flutter_paths=['test/'+p.name for p in sorted((ROOT/'mobile/test').glob('*_test.dart'))
            if re.search(r'auth|registration|recovery|security|login|otp|password',p.name)
            or p.name in {'api_config_test.dart','account_settings_test.dart','widget_test.dart'}]
    stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    report=ROOT/'.runtime/precommit-full'/stamp
    report.mkdir(parents=True)
    p=conninfo_to_dict(test_url())
    assert p['dbname']==TEST_DB and TEST_DB.endswith('_test')
    admin_url=make_conninfo(**{**p,'dbname':'postgres'})
    names={
      'DATABASE_URL':'precommit_'+stamp.lower()+'_test',
      'AUTH_TEST_DATABASE_URL':'precommit_auth_'+stamp.lower()+'_test',
      'GROWTH_TEST_DATABASE_URL':'precommit_'+stamp.lower()+'_growth_test',
      'SHARING_TEST_DATABASE_URL':'precommit_'+stamp.lower()+'_sharing_test',
      'TEETHING_TEST_DATABASE_URL':'precommit_'+stamp.lower()+'_teething_test',
      'ASSESSMENT_TEST_DATABASE_URL':'assessment_admin_test_'+stamp.lower()+'_test',
    }
    if args.auth_only:
        names={k:v for k,v in names.items() if k in ('DATABASE_URL','AUTH_TEST_DATABASE_URL')}
        names['AUTH_LIVE_DATABASE_URL']='precommit_auth_live_'+stamp.lower()+'_test'
    env={**os.environ,'PYTHONPATH':str(ROOT/'backend'), 'APP_ENV':'local',
         'AUTH_SIMULATION':'false', 'AUTH_V2_ENABLED':'false',
         'PGOPTIONS':'-c app.auth_025_approved=true -c app.auth_026_approved=true'}
    created=[]
    summary={'scope':'all backend/tests; all mobile/test; Flutter analyze',
             'source':'dedicated synthetic auth test DB; no app DB fixture writes',
             'results':{}}
    jobs=[]
    server=None
    server_log=None
    try:
        if args.only in ('all','backend') or (args.auth_only and args.only=='flutter'):
          with psycopg.connect(admin_url,autocommit=True,connect_timeout=5) as admin:
            for key,name in names.items():
                assert name.endswith('_test') and name!=TEST_DB
                admin.execute(sql.SQL('CREATE DATABASE {} TEMPLATE {}').format(sql.Identifier(name),sql.Identifier(TEST_DB)))
                created.append(name)
                env[key]='postgresql://'+quote(p.get('user',''),safe='')+':'+quote(p.get('password',''),safe='')+'@'+p.get('host','localhost')+':'+p.get('port','5432')+'/'+name
                with psycopg.connect(env[key]) as db:
                    # Mark the actual current template schema in both fixture ledgers.
                    db.execute('CREATE TABLE IF NOT EXISTS public.schema_migrations(version text PRIMARY KEY)')
                    db.execute('CREATE TABLE IF NOT EXISTS public.auth_test_migrations(name text PRIMARY KEY)')
                    for migration in sorted((ROOT/'backend/migrations').glob('*.sql')):
                        db.execute('INSERT INTO public.schema_migrations(version) VALUES (%s) ON CONFLICT DO NOTHING',(migration.stem,))
                        db.execute('INSERT INTO public.auth_test_migrations(name) VALUES (%s) ON CONFLICT DO NOTHING',(migration.name,))
        if 'AUTH_TEST_DATABASE_URL' in env:
            env['AUTH_MIGRATION_TEST_DATABASE_URL']=env['AUTH_TEST_DATABASE_URL']
        if args.auth_only:
            env['AUTH_025_TEST_APPROVED']='true'
            env['AUTH_026_TEST_APPROVED']='true'
            if args.only in ('all','flutter'):
                probe=socket.socket()
                try:
                    if probe.connect_ex(('127.0.0.1',8009))==0:
                        raise RuntimeError('Port 8009 is already in use; refusing to reuse an unknown test server')
                finally:probe.close()
                server_log=(report/'live-server.log').open('w',encoding='utf-8')
                live_env={**env,'AUTH_TEST_DATABASE_URL':env['AUTH_LIVE_DATABASE_URL']}
                server=subprocess.Popen([sys.executable,'-m','tests.auth.live_server'],cwd=ROOT/'backend',env=live_env,stdout=server_log,stderr=subprocess.STDOUT)
                for attempt in range(60):
                    if server.poll() is not None:raise RuntimeError('Live auth test server exited; see live-server.log')
                    try:
                        with urllib.request.urlopen('http://127.0.0.1:8009/health',timeout=1) as response:
                            if response.status==200:break
                    except OSError:time.sleep(.25)
                else:raise RuntimeError('Live auth test server did not become healthy')
        sdk=args.flutter_sdk
        if sdk is None:
            flutter_command=shutil.which('flutter')
            sdk=Path(flutter_command).resolve().parents[1] if flutter_command else Path(os.environ.get('FLUTTER_ROOT','missing-flutter-sdk'))
        dart=sdk/'bin/cache/dart-sdk/bin/dart.exe'
        flutter=dart.parents[2]/'flutter_tools.snapshot'
        if args.only!='backend' and (not dart.is_file() or not flutter.is_file()):
            raise RuntimeError('Flutter SDK cache missing; provide --flutter-sdk or configure Flutter in PATH')
        suites=[
          ('backend',[sys.executable,'-m','pytest',*args.backend_paths,'-q','--tb=short','-p','no:cacheprovider',
                      '--basetemp='+str(report/'pytest-tmp'),'--junitxml='+str(report/'backend.xml')],ROOT/'backend'),
          ('flutter',[str(dart),str(flutter),'test','--no-pub','--reporter=json',
                      *(['--dart-define=AUTH_LIVE_TEST=true','--dart-define=API_BASE_URL=http://127.0.0.1:8009/api/v1'] if args.auth_only else []),*args.flutter_paths],ROOT/'mobile'),
          ('analyze',[str(dart),'analyze',*(['lib/features/auth','lib/features/settings/security_screen.dart',
              'lib/features/settings/live_change_password_dialog.dart','lib/services/auth_service.dart',
              'lib/services/api_config.dart','lib/services/social_identity.dart',
              'lib/services/auth_entry_preferences.dart','lib/services/authorized_client.dart',*args.flutter_paths] if args.auth_only else [])],ROOT/'mobile'),
        ]
        suites=[s for s in suites if args.only=='all' or s[0]==args.only]
        summary['selection']={'only':args.only,'backend':args.backend_paths,'flutter':args.flutter_paths}
        if args.auth_only:summary['scope']='Complete auth backend/mobile suites + auth analyzer + live HTTP test; excludes non-auth feature suites'
        print('Reports:',report,flush=True)
        for name,cmd,cwd in suites:
            log=(report/(name+'.log')).open('w',encoding='utf-8')
            jobs.append((name,subprocess.Popen(cmd,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT),log))
        pending=list(jobs)
        while pending:
            for item in list(pending):
                name,process,log=item
                code=process.poll()
                if code is None:continue
                log.close()
                try:
                    counts=backend_counts(report/'backend.xml') if name=='backend' else flutter_counts(report/'flutter.log') if name=='flutter' else {}
                except (OSError,ValueError):counts={'reportUnreadable':True}
                counts['exitCode']=code
                counts['status']='PASS' if code==0 and not counts.get('skipped') and not counts.get('failed') else 'FAIL_OR_INCOMPLETE'
                summary['results'][name]=counts
                (report/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
                print(name,counts,flush=True)
                pending.remove(item)
            if pending:time.sleep(1)
        return 0 if all(r['status']=='PASS' for r in summary['results'].values()) else 1
    finally:
        for _,process,log in jobs:
            if process.poll() is None:
                process.terminate();process.wait(timeout=30)
            log.close()
        if server is not None and server.poll() is None:
            server.terminate();server.wait(timeout=30)
        if server_log is not None:server_log.close()
        if created:
            with psycopg.connect(admin_url,autocommit=True,connect_timeout=5) as admin:
                for name in created:
                    assert name in names.values() and name!=TEST_DB and name.endswith('_test')
                    admin.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(name)))
        print('Temporary databases cleaned; app DB was not used for fixtures.',flush=True)


if __name__=='__main__':
    sys.exit(main())
