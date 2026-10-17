import os
import hashlib
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4
import jwt
import psycopg
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.features.growth import service


@pytest.fixture(scope='session')
def database():
    url = os.environ.get('GROWTH_TEST_DATABASE_URL')
    if not url:
        pytest.skip('GROWTH_TEST_DATABASE_URL required for PostgreSQL integration tests')
    name = psycopg.conninfo.conninfo_to_dict(url).get('dbname', '')
    if not name.endswith('_growth_test'):
        pytest.fail('Only an explicit database ending in _growth_test may be used')
    with psycopg.connect(url) as db:
        db.execute('CREATE TABLE IF NOT EXISTS public.schema_migrations (version text PRIMARY KEY)')
        for file in sorted((Path(__file__).parents[2] / 'migrations').glob('*.sql')):
            if not db.execute('SELECT 1 FROM public.schema_migrations WHERE version=%s', (file.stem,)).fetchone():
                db.execute(file.read_text(encoding='utf-8'), prepare=False)
                db.execute('INSERT INTO public.schema_migrations VALUES (%s)', (file.stem,))
    return url


@pytest.fixture
def env(database, monkeypatch):
    monkeypatch.setenv('DATABASE_URL', database)
    monkeypatch.setenv('AUTH_SECRET', 'growth-test-secret-only-01234567890123456789')
    monkeypatch.setattr(service, 'today', lambda: date(2026, 10, 17))
    from psycopg.rows import dict_row
    with psycopg.connect(database, row_factory=dict_row) as db:
        db.execute('TRUNCATE account.users CASCADE')
        db.execute('TRUNCATE account.mobile_login_limits')
        users, tokens = {}, {}
        for name in ['owner', 'other', 'view', 'edit', 'none', 'revoked', 'left']:
            uid, sid = uuid4(), uuid4()
            db.execute('''INSERT INTO account.users (id,email,password_hash,full_name,status)
                VALUES (%s,%s,'not-a-password-hash',%s,'active')''', (uid,name+'@example.test',name))
            db.execute('''INSERT INTO account.user_sessions (id,user_id,refresh_token_hash,expires_at)
                VALUES (%s,%s,%s,%s)''', (sid,uid,hashlib.sha256(str(sid).encode()).hexdigest(),
                datetime.now(timezone.utc)+timedelta(hours=1)))
            users[name] = uid
            tokens[name] = jwt.encode({'sub': str(uid),'sid': str(sid),'iss':'track-children-mobile',
                'aud':'mobile','iat':datetime.now(timezone.utc),'exp':datetime.now(timezone.utc)+timedelta(minutes=15)},
                os.environ['AUTH_SECRET'], algorithm='HS256')
        child = uuid4()
        db.execute('''INSERT INTO child.children (id,owner_user_id,full_name,date_of_birth,gender)
            VALUES (%s,%s,'Same name','2026-02-17','male')''', (child,users['owner']))
        for name, level in [('view','view'),('edit','edit'),('none','none'),('revoked','edit'),('left','edit')]:
            member = uuid4()
            db.execute('INSERT INTO child.child_members (id,child_id,user_id,status) VALUES (%s,%s,%s,%s)',
                (member,child,users[name],name if name in ('revoked','left') else 'active'))
            db.execute("INSERT INTO child.child_member_permissions VALUES (%s,'growth',%s)", (member,level))
    client = TestClient(app)
    return {'client':client,'users':users,'tokens':tokens,'child':str(child), 'url':database}
