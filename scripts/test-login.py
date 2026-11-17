"""Run current-schema login tests; DB fixtures create/drop only UUID *_test DBs.

Usage: .venv/Scripts/python.exe scripts/test-login.py
Uses local backend connection credentials solely to provision isolated test DBs.
No application tables are read or mutated by the test suite.
"""
import os
from pathlib import Path
import sys
from uuid import uuid4

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'backend'))
os.chdir(root)

from app.core.config import Settings
from psycopg.conninfo import make_conninfo
import pytest

def main():
    if not os.environ.get('AUTH_TEST_DATABASE_URL'):
        config = Settings(_env_file=root / 'backend/.env')
        os.environ['AUTH_TEST_DATABASE_URL'] = make_conninfo(
            config.database_url, dbname='track_children_auth_test')

    results = root / '.auth-test-logs'
    results.mkdir(exist_ok=True)
    raise SystemExit(pytest.main([
        'backend/tests/auth/test_login.py', 'backend/tests/auth/test_login_schema.py',
        'backend/tests/auth/test_login_rate_limit.py',
        'backend/tests/auth/test_social_auth.py', 'backend/tests/auth/test_registration.py',
        'backend/tests/auth/test_auth_contract.py', '-q', '--tb=short',
        '-p', 'no:cacheprovider', f'--basetemp={results / ("pytest-login-" + uuid4().hex)}',
        f'--junitxml={results / "login-backend.xml"}', *sys.argv[1:]
    ]))


if __name__ == "__main__":
    main()
