"""Run the isolated teething regression suite; fail on failures or skipped cases."""
import datetime
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/test-results/teething'
OUT.mkdir(parents=True, exist_ok=True)
mobile = ROOT / 'mobile'
files = sorted(p.relative_to(mobile).as_posix() for p in (mobile / 'test').glob('teething*_test.dart'))
files += ['test/demo_store_child_lookup_test.dart', 'test/sharing_permissions_test.dart']
flutter = shutil.which('flutter')
if not flutter:
    sys.exit('Flutter must be on PATH')

def run(name, command, cwd):
    print(f'Running {name}...', flush=True)
    with (OUT / f'{name}.log').open('w', encoding='utf-8') as log:
        result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT,
                                encoding='utf-8', timeout=600)
    return result.returncode

flutter_code = run('flutter', [flutter, 'test', '--no-pub', '--reporter', 'json', *files], mobile)
tests = {}
done = False
for line in (OUT / 'flutter.log').read_text(encoding='utf-8').splitlines():
    try:
        event = json.loads(line)
    except ValueError:
        continue
    if event.get('type') == 'testStart':
        test = event['test']
        tests[test['id']] = {'name': test['name'], 'hidden': test.get('metadata', {}).get('hidden', False)}
    elif event.get('type') == 'testDone' and event['testID'] in tests:
        tests[event['testID']].update(result=event['result'], skipped=event['skipped'], hidden=event.get('hidden', False))
    elif event.get('type') == 'done':
        done = event['success']
cases = [t for t in tests.values() if not t['hidden']]
critical = {int(m.group(1)) for t in cases if (m := re.search(r'TC-TEETH-(\d+)', t['name'])) and t.get('result') == 'success' and not t.get('skipped')}
flutter_ok = flutter_code == 0 and done and bool(cases) and critical == set(range(1, 15)) and all(t.get('result') == 'success' and not t.get('skipped') for t in cases)

python = ROOT / '.venv/Scripts/python.exe'
backend_code = run('backend', [str(python), '-m', 'pytest', 'tests/test_teething_contract.py', '-q', f'--junitxml={OUT / "backend.xml"}'], ROOT / 'backend')
backend_cases = list(ET.parse(OUT / 'backend.xml').iter('testcase')) if (OUT / 'backend.xml').exists() else []
backend_ok = backend_code == 0 and bool(backend_cases) and all(not any(t.find(tag) is not None for tag in ['failure', 'error', 'skipped']) for t in backend_cases)
analysis_code = run('analysis', [flutter, 'analyze', '--no-pub', 'lib/features/teething', 'lib/services/demo_store.dart', *files], mobile)
ok = flutter_ok and backend_ok and analysis_code == 0
summary = {'passed': ok, 'timestamp': datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=7))).isoformat(), 'flutter_count': len(cases), 'backend_count': len(backend_cases), 'critical_passed': sorted(critical), 'flutter_exit': flutter_code, 'backend_exit': backend_code, 'analysis_exit': analysis_code, 'flutter_cases': cases}
(OUT / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
rows = ['# Teething automated test results', '', f'Status: **{"PASS" if ok else "FAIL"}**', '', f'Executed: {summary["timestamp"]}', '', '| Suite | Cases | Result |', '|---|---:|---|', f'| Flutter unit/widget/API mocks | {len(cases)} | {"PASS" if flutter_ok else "FAIL"} |', f'| Backend contract (no database) | {len(backend_cases)} | {"PASS" if backend_ok else "FAIL"} |', f'| Flutter static analysis | - | {"PASS" if analysis_code == 0 else "FAIL"} |', '', 'Scope: teething feature and shared-profile permission/cache regression. Uses isolated fixtures and mocked network; excludes physical-device performance, live backend integration and unrelated app suites.', '', 'Completion requires every listed case to pass, zero skips, all 14 critical cases present, and static analysis to pass.', '', 'Run: `python scripts/run_teething_tests.py`', '', '## Flutter cases', '', '| Case | Result |', '|---|---|']
rows += [f'| {t["name"].replace("|", "/")} | {"SKIPPED" if t.get("skipped") else t.get("result", "incomplete")} |' for t in cases]
rows += ['', '## Backend cases', '', '| Case | Result |', '|---|---|']
rows += [f'| {t.attrib["name"]} | {"PASS" if not any(t.find(tag) is not None for tag in ["failure", "error", "skipped"]) else "FAIL/SKIP"} |' for t in backend_cases]
(OUT / 'RESULTS.md').write_text('\n'.join(rows) + '\n', encoding='utf-8')
print(json.dumps({k: v for k, v in summary.items() if k != 'flutter_cases'}, indent=2))
sys.exit(0 if ok else 1)
