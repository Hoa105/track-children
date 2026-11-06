"""Assessment over a real local HTTP socket, JWT/session checks and PostgreSQL.

Run via run_assessment_admin_tests.py with this file as its argument. The runner
creates and drops a disposable database; no application data is modified.
"""
import datetime as dt
import os
import socket
import threading
import time
from uuid import uuid4

import httpx
import pytest
import uvicorn
from fastapi import FastAPI

from app.core import database, security
from app.core.config import settings
from app.features.assessment.router import router
from app.features.auth.setup import install_auth
from .test_assessment_admin import db, actor
from .test_assessment_mobile import workspace


@pytest.fixture
def live_api(db, workspace, monkeypatch):
    monkeypatch.setattr(settings, 'database_url', os.environ['ASSESSMENT_TEST_DATABASE_URL'])
    monkeypatch.setattr(settings, 'auth_secret', 'assessment-live-test-only-secret-123456789012345')
    # Minimal auth tables alongside the runner's isolated assessment schema.
    with db, db.cursor() as cur:
        cur.execute("ALTER TABLE account.users ADD COLUMN IF NOT EXISTS status text DEFAULT 'active'")
        cur.execute('''CREATE TABLE IF NOT EXISTS account.user_sessions(
            id uuid PRIMARY KEY, user_id uuid REFERENCES account.users(id),
            expires_at timestamptz NOT NULL, revoked_at timestamptz)''')
    app = FastAPI()
    app.include_router(router)
    install_auth(app)
    listener = socket.socket()
    listener.bind(('127.0.0.1', 0))
    port = listener.getsockname()[1]
    server = uvicorn.Server(uvicorn.Config(app, host='127.0.0.1', port=port, log_level='error'))
    thread = threading.Thread(target=server.run, kwargs={'sockets': [listener]}, daemon=True)
    thread.start()
    try:
        deadline = time.monotonic() + 10
        while not server.started and thread.is_alive() and time.monotonic() < deadline:
            time.sleep(0.05)
        assert server.started, 'Local HTTP test server failed to start'
        with httpx.Client(base_url=f'http://127.0.0.1:{port}', timeout=10, trust_env=False) as client:
            yield client
    finally:
        server.should_exit = True
        thread.join(timeout=10)
        listener.close()
        if database._pool is not None:
            database._pool.closeall()
            database._pool = None


def token_for(db, user_id):
    session = uuid4()
    expiry = security.now() + dt.timedelta(hours=1)
    with db, db.cursor() as cur:
        cur.execute('INSERT INTO account.user_sessions(id,user_id,expires_at) VALUES (%s,%s,%s)',
                    (session, user_id, expiry))
    return {'Authorization': 'Bearer ' + security.access_token(user_id, session, expiry)}, session


def test_live_assessment_flow_and_access_controls(db, workspace, live_api):
    child, owner, _, _ = workspace
    client = live_api
    base = f'/api/v1/children/{child["id"]}/assessment'
    auth, session = token_for(db, owner)
    assert client.get(base + '/overview').status_code == 401
    response = client.get(base + '/overview', headers=auth)
    assert response.status_code == 200, response.text
    assert response.json()['set']['count'] > 0
    request_id = str(uuid4())
    response = client.post(base + '/assessments', headers=auth, json={'id': request_id})
    assert response.status_code == 200, response.text
    attempt = response.json()
    assert attempt['id'] == request_id and attempt['status'] == 'in_progress'
    attempt_url = base + '/assessments/' + request_id
    assert client.post(base + '/assessments', headers=auth, json={'id': request_id}).json()['id'] == request_id
    assert client.post(attempt_url + '/complete', headers=auth,
                       json={'expected_version': attempt['version']}).status_code == 422
    body = {'expected_version': attempt['version'],
            'answers': {q['code']: 'not_yet' for q in attempt['questions']},
            'regression': 'no', 'caregiver_concern': 'no'}
    response = client.patch(attempt_url, headers=auth, json=body)
    assert response.status_code == 200, response.text
    saved = response.json()
    assert saved['version'] == attempt['version'] + 1
    assert client.patch(attempt_url, headers=auth, json=body).status_code == 409
    response = client.post(attempt_url + '/complete', headers=auth,
                           json={'expected_version': saved['version']})
    assert response.status_code == 200, response.text
    completed = response.json()
    assert completed['status'] == 'completed' and not completed['editable']
    assert completed['result']['release_status'] == 'published'
    assert completed['result']['sections']['overview']['not_yet'] == len(attempt['questions'])
    assert client.post(attempt_url + '/complete', headers=auth,
                       json={'expected_version': 1}).json() == completed
    assert client.get(attempt_url, headers=auth).json() == completed
    history = client.get(base + '/assessments', headers=auth)
    assert history.status_code == 200 and history.json()['items'][0]['id'] == request_id
    assert client.get(base + '/overview', headers=auth).json()['completed_milestones'] == [2]
    assert client.patch(attempt_url, headers=auth,
                        json={**body, 'expected_version': completed['version']}).status_code == 409
    with db.cursor() as cur:
        cur.execute('SELECT count(*) AS count FROM assessment.assessment_results WHERE assessment_id=%s', (request_id,))
        assert cur.fetchone()['count'] == 1
    # Real JWT for a second account: no membership hides the child, view permits
    # reading but forbids edits; revoking the owner's session invalidates its JWT.
    viewer, member = uuid4(), uuid4()
    with db, db.cursor() as cur:
        cur.execute('INSERT INTO account.users(id) VALUES (%s)', (viewer,))
    viewer_auth, _ = token_for(db, viewer)
    assert client.get(base + '/overview', headers=viewer_auth).status_code == 404
    with db, db.cursor() as cur:
        cur.execute("INSERT INTO child.child_members(id,child_id,user_id,status) VALUES (%s,%s,%s,'active')",
                    (member, child['id'], viewer))
        cur.execute("INSERT INTO child.child_member_permissions(member_id,data_scope,access_level) VALUES (%s,'assessment','view')", (member,))
    assert client.get(attempt_url, headers=viewer_auth).status_code == 200
    assert client.patch(attempt_url, headers=viewer_auth, json=body).status_code == 403
    with db, db.cursor() as cur:
        cur.execute('UPDATE account.user_sessions SET revoked_at=now() WHERE id=%s', (session,))
    assert client.get(base + '/overview', headers=auth).status_code == 401
