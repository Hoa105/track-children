"""Local-only live Flutter test server. Never provisions production accounts."""
import os
import psycopg
from argon2 import PasswordHasher
import uvicorn


def main():
    url = os.environ['GROWTH_TEST_DATABASE_URL']
    if not psycopg.conninfo.conninfo_to_dict(url).get('dbname','').endswith('_growth_test'):
        raise RuntimeError('A dedicated _growth_test database is required')
    os.environ['DATABASE_URL'] = url
    os.environ.setdefault('AUTH_SECRET','local-growth-live-test-secret-01234567890123456789')
    with psycopg.connect(url) as db:
        db.execute('''INSERT INTO account.users (email,password_hash,full_name,status)
            VALUES ('growth-live@example.test',%s,'Growth live fixture','active')
            ON CONFLICT (email) DO UPDATE SET password_hash=excluded.password_hash,status='active',deleted_at=NULL''',
            (PasswordHasher().hash('Growth-live-test-123'),))
    uvicorn.run('app.main:app',host='127.0.0.1',port=8009,log_level='warning')


if __name__=='__main__': main()
