"""Disposable historical schemas for replayable migration regression tests."""
from contextlib import contextmanager
from pathlib import Path
from uuid import uuid4
import os
import psycopg
from psycopg import sql
from psycopg.conninfo import conninfo_to_dict,make_conninfo


@contextmanager
def historical_auth_database(through):
    source=os.environ.get('AUTH_MIGRATION_TEST_DATABASE_URL') or os.environ.get('AUTH_TEST_DATABASE_URL')
    if not source:
        raise RuntimeError('Dedicated migration test database URL required')
    params=conninfo_to_dict(source)
    assert params['dbname'].endswith('_test')
    name='auth_compact_'+str(through)+'_'+uuid4().hex+'_test'
    url=make_conninfo(source,dbname=name)
    with psycopg.connect(source,autocommit=True,connect_timeout=5) as owner:
        owner.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
        try:
            with psycopg.connect(url,autocommit=True) as db:
                db.execute("SET app.auth_025_approved='true'")
                for path in sorted((Path(__file__).parents[1]/'migrations').glob('*.sql')):
                    if int(path.name.split('_',1)[0])>through:
                        continue
                    with db.transaction():
                        db.execute(path.read_text(encoding='utf-8'),prepare=False)
            yield url
        finally:
            assert name.startswith('auth_compact_') and name.endswith('_test')
            owner.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(name)))
