from pathlib import Path
from urllib.parse import urlsplit,urlunsplit
from uuid import uuid4

import psycopg
from psycopg import sql


def test_upgrade_preserves_existing_account(database_url):
    # A separate disposable test DB verifies migration 007 against populated 001-006.
    name='auth_upgrade_'+uuid4().hex+'_test'
    assert name.startswith('auth_upgrade_') and name.endswith('_test')
    parts=urlsplit(database_url)
    target=urlunsplit(parts._replace(path='/'+name))
    files=sorted((Path(__file__).parents[2]/'migrations').glob('*.sql'))
    with psycopg.connect(database_url,autocommit=True) as admin:
        admin.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
        try:
            with psycopg.connect(target) as db:
                for file in files:
                    if file.name.startswith('007'):break
                    db.execute(file.read_text(encoding='utf-8'))
                uid=db.execute("INSERT INTO account.users(email,password_hash,full_name,status) VALUES ('existing@example.com','existing-hash','Existing Parent','active') RETURNING id").fetchone()[0]
                db.execute("INSERT INTO account.user_sessions(user_id,refresh_token_hash,expires_at) VALUES (%s,'existing-session',now()+interval '1 day')",(uid,))
                db.execute(next(f for f in files if f.name.startswith('007')).read_text(encoding='utf-8'))
                assert db.execute('SELECT password_hash,status,failed_login_attempts FROM account.users WHERE id=%s',(uid,)).fetchone()==('existing-hash','active',0)
                assert db.execute('SELECT last_used_at IS NOT NULL FROM account.user_sessions').fetchone()[0]
        finally:
            admin.execute(sql.SQL('DROP DATABASE {}').format(sql.Identifier(name)))
