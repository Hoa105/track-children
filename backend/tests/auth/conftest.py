"""Integration tests use only a dedicated, explicitly named *_test database."""
import os
from pathlib import Path
from urllib.parse import urlparse

import psycopg
import pytest
from fastapi.testclient import TestClient
from psycopg.rows import dict_row

from app.core.config import settings
from app.features.auth import service
from app.main import app


@pytest.fixture(scope='session')
def database_url():
    url=os.environ.get('AUTH_TEST_DATABASE_URL')
    if not url:pytest.skip('AUTH_TEST_DATABASE_URL is required for PostgreSQL integration tests')
    name=urlparse(url).path.lstrip('/')
    if not name.endswith('_test'):raise RuntimeError('Test database name must end with _test')
    with psycopg.connect(url,autocommit=True) as db:
        db.execute('CREATE TABLE IF NOT EXISTS public.auth_test_migrations(name text PRIMARY KEY)')
        for file in sorted((Path(__file__).parents[2]/'migrations').glob('*.sql')):
            if not db.execute('SELECT 1 FROM public.auth_test_migrations WHERE name=%s',(file.name,)).fetchone():
                with db.transaction():
                    db.execute(file.read_text(encoding='utf-8'))
                    db.execute('INSERT INTO public.auth_test_migrations VALUES (%s)',(file.name,))
    return url


@pytest.fixture
def env(database_url,monkeypatch):
    monkeypatch.setattr(settings,'database_url',database_url)
    monkeypatch.setattr(settings,'auth_secret','test-secret-only-not-for-production-123456789')
    sms=[]
    monkeypatch.setattr(service,'send_sms',lambda phone,code: sms.append((phone,code)) or True)
    with psycopg.connect(database_url,row_factory=dict_row,autocommit=True) as db:
        # CASCADE is restricted to the dedicated *_test database guarded above.
        db.execute('TRUNCATE account.users,account.legal_documents,account.auth_rate_limits CASCADE')
        for kind in ['terms','privacy','data_policy']:
            db.execute("INSERT INTO account.legal_documents(doc_type,version,content,effective_at) VALUES (%s,'1','test legal text',now()-interval '1 day')",(kind,))
        yield TestClient(app,client=('127.0.0.1',50000)),db,sms


@pytest.fixture
def payload(env):
    client,db,_=env
    docs=client.get('/api/v1/legal-documents?context=registration').json()['documents']
    return {'fullName':'Test Parent','username':'parent_test','email':'parent@example.com',
            'phone':'0912345678','password':'Password12345!', 'relationship':'mother',
            'consents':[{'documentId':str(d['id']),'isAccepted':True} for d in docs]}


DEVICE={'deviceId':'installation-1','platform':'android'}


def register_and_verify(env,payload,remember=True):
    client,_,sms=env
    response=client.post('/api/v1/auth/register',json=payload)
    assert response.status_code==201,response.text
    c=response.json()
    response=client.post('/api/v1/auth/register/verify',json={
        'verificationId':c['verificationId'],'registrationToken':c['registrationToken'],
        'code':sms[-1][1],'device':DEVICE,'rememberMe':remember})
    assert response.status_code==200,response.text
    return response.json()
