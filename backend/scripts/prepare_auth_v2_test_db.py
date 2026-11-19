"""Apply approved migrations only to a dedicated *_test database. No seed/truncate.

Run from backend: ../.venv/Scripts/python scripts/prepare_auth_v2_test_db.py
Source connection is read from settings, credentials are never printed.
"""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import psycopg
from psycopg import sql
from psycopg.conninfo import conninfo_to_dict,make_conninfo
from app.core.config import settings

TEST_DB='auth_v2_20261118_test'

def test_url():
    parameters=conninfo_to_dict(settings.database_url)
    parameters['dbname']=TEST_DB
    return make_conninfo(**parameters)

def main():
    assert TEST_DB.endswith('_test')
    parameters=conninfo_to_dict(settings.database_url)
    parameters['dbname']='postgres'
    with psycopg.connect(make_conninfo(**parameters),autocommit=True,connect_timeout=5) as admin:
        if not admin.execute('SELECT 1 FROM pg_database WHERE datname=%s',(TEST_DB,)).fetchone():
            admin.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(TEST_DB)))
    with psycopg.connect(test_url(),autocommit=True) as db:
        db.execute('CREATE TABLE IF NOT EXISTS public.auth_v2_test_migrations(name text PRIMARY KEY)')
        for path in sorted((Path(__file__).resolve().parents[1]/'migrations').glob('*.sql')):
            if db.execute('SELECT 1 FROM public.auth_v2_test_migrations WHERE name=%s',(path.name,)).fetchone():
                continue
            with db.transaction():
                db.execute(path.read_text(encoding='utf-8'))
                db.execute('INSERT INTO public.auth_v2_test_migrations VALUES (%s)',(path.name,))
            print('Applied to dedicated test database:',path.name)
    print('Ready:',TEST_DB,'(application database unchanged)')

if __name__=='__main__':
    main()
