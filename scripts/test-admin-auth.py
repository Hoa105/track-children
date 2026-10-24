"""Run admin API tests; provision only disposable *_test databases via fixtures."""
import os
from pathlib import Path
import sys
from uuid import uuid4

root = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(root/'backend'), str(root/'.test-deps')]
os.chdir(root)
from app.core.config import Settings
from psycopg.conninfo import make_conninfo
import pytest

if not os.environ.get('AUTH_TEST_DATABASE_URL'):
    config = Settings(_env_file=root/'backend/.env')
    os.environ['AUTH_TEST_DATABASE_URL'] = make_conninfo(
        config.database_url,dbname='track_children_auth_test',connect_timeout=5)
results=root/'.auth-test-logs'
results.mkdir(exist_ok=True)
raise SystemExit(pytest.main(['backend/tests/auth/test_admin_auth.py',
    'backend/tests/auth/test_admin_auth_unit.py','backend/tests/auth/test_admin_account.py','-q','--tb=short','-p','no:cacheprovider',
    '--basetemp='+str(results/('pytest-admin-'+uuid4().hex)),
    '--junitxml='+str(results/'admin-auth.xml'),*sys.argv[1:]]))
