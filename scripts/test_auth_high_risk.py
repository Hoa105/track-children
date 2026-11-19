"""Run the reviewed auth suites; no migrations, installs, or real providers."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MOBILE_TESTS = [
    'auth_entry_test.dart', 'auth_service_test.dart', 'auth_v2_adapter_test.dart',
    'registration_steps_test.dart', 'otp_status_test.dart',
    'recovery_adapter_test.dart', 'recovery_screen_test.dart',
    'security_screen_test.dart', 'social_registration_flow_test.dart',
    'auth_layout_test.dart',
]


def backend_counts(path):
    suites = ET.parse(path).getroot()
    cases = list(suites.iter('testcase'))
    return {
        'total': len(cases),
        'failed': sum(c.find('failure') is not None or c.find('error') is not None for c in cases),
        'skipped': sum(c.find('skipped') is not None for c in cases),
    }


def flutter_counts(path):
    results = {}
    skipped = set()
    complete = False
    for line in path.read_text(encoding='utf-8').splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('type') == 'testDone':
            if event.get('hidden') and event.get('result') == 'success':
                continue
            results[event['testID']] = event.get('result')
            if event.get('skipped'):
                skipped.add(event['testID'])
        if event.get('type') == 'done':
            complete = event.get('success') is True
    return {'total': len(results), 'failed': sum(v != 'success' for v in results.values()),
            'skipped': len(skipped), 'complete': complete}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter-sdk', required=True, type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    os.chdir(ROOT / 'backend')
    sys.path.insert(0, str(ROOT / 'backend'))
    sys.path.insert(0, str(ROOT / 'backend/scripts'))
    import psycopg
    from psycopg.conninfo import conninfo_to_dict
    from prepare_auth_v2_test_db import test_url, TEST_DB
    from app.core.config import settings
    from app.features.auth.registration import legal
    from app.features.auth.errors import AuthFailure

    dart = args.flutter_sdk / 'bin/cache/dart-sdk/bin/dart.exe'
    flutter = args.flutter_sdk / 'bin/cache/flutter_tools.snapshot'
    if not dart.is_file() or not flutter.is_file():
        raise RuntimeError('Flutter SDK cache is missing; run flutter doctor first.')
    if not (ROOT / 'mobile/.dart_tool/package_config.json').is_file():
        raise RuntimeError('Run flutter pub get in mobile before testing.')
    # Never accept an arbitrary database from command-line arguments.
    url = test_url()
    if conninfo_to_dict(url).get('dbname') != TEST_DB or not TEST_DB.endswith('_test'):
        raise RuntimeError('Dedicated test database guard failed.')
    with psycopg.connect(url, connect_timeout=5) as db:
        if db.execute('SELECT current_database()').fetchone()[0] != TEST_DB:
            raise RuntimeError('Unexpected database.')
        for table in ('auth_transactions', 'auth_consent_receipts', 'auth_refresh_history'):
            if db.execute('SELECT to_regclass(%s)', ('account.' + table,)).fetchone()[0] is None:
                raise RuntimeError('Approved test schema is missing; no migration was applied.')
        if not db.execute("SELECT 1 FROM information_schema.columns WHERE table_schema='account' AND table_name='users' AND column_name='auth_known_devices'").fetchone():
            raise RuntimeError('Approved migration 024 is missing; no migration was applied.')
    settings.legal_documents_path = str(ROOT / 'backend/legal-documents.local.json')
    if isinstance(legal(), AuthFailure):
        raise RuntimeError('Trial policies are unavailable or not effective yet.')
    print('Preflight passed: dedicated test DB, schema, policies and Flutter cache.', flush=True)
    if args.prepare_only:
        print('Preparation only: tests have NOT run.')
        return 0

    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    report = ROOT / '.runtime/auth-high-risk' / stamp
    report.mkdir(parents=True)
    env = {**os.environ, 'PYTHONPATH': str(ROOT / 'backend'), 'APP_ENV': 'local',
           'DATABASE_URL': url, 'AUTH_SIMULATION': 'false',
           'LEGAL_DOCUMENTS_PATH': str(ROOT / 'backend/legal-documents.local.json')}
    suites = [
        ('backend', [sys.executable, '-m', 'pytest', 'tests/test_auth_v2.py',
                     'tests/auth/test_trial_legal_documents.py',
                     'tests/test_auth_storage_validation.py',
                     'tests/test_auth_compaction_compatibility.py', '-q', '--tb=no',
                     '-p', 'no:cacheprovider', '--basetemp=' + str(report / 'pytest-tmp'),
                     '--junitxml=' + str(report / 'backend.xml')], ROOT / 'backend'),
        ('flutter', [str(dart), str(flutter), 'test', '--no-pub', '--reporter=json',
                     *['test/' + name for name in MOBILE_TESTS]], ROOT / 'mobile'),
    ]
    summary = {'scope': 'test DB + mocked providers + Flutter widgets; no physical-device or live-provider E2E',
               'database': TEST_DB, 'results': {}}
    print('Reports:', report, flush=True)
    for name, command, cwd in suites:
        print('Running', name, '...', flush=True)
        log = report / (name + '.log')
        with log.open('w', encoding='utf-8') as output:
            try:
                process = subprocess.run(command, cwd=cwd, env=env, stdout=output,
                                         stderr=subprocess.STDOUT, timeout=1200)
                counts = backend_counts(report / 'backend.xml') if name == 'backend' else flutter_counts(log)
                counts['exitCode'] = process.returncode
                counts['status'] = 'PASS' if process.returncode == 0 and counts['total'] > 0 and counts['failed'] == 0 and counts['skipped'] == 0 and counts.get('complete', True) else 'FAIL_OR_INCOMPLETE'
            except (subprocess.TimeoutExpired, OSError, ET.ParseError) as error:
                counts = {'status': 'BLOCKED', 'reason': type(error).__name__}
        summary['results'][name] = counts
        (report / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
        print(name, counts, flush=True)
    print('Detailed logs are local test artifacts; review before sharing.', flush=True)
    return 0 if all(r['status'] == 'PASS' for r in summary['results'].values()) else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        # Connection exceptions can contain credentials; never print their text.
        print('Preflight blocked:', type(error).__name__, '- check test DB/schema, policies and SDK setup.', file=sys.stderr)
        sys.exit(2)
