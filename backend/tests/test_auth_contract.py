import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import password_hasher,verify_password


def test_password_hash():
    hashed=password_hasher.hash('real-password-123')
    assert verify_password('real-password-123',hashed)
    assert not verify_password('bad',hashed)
    assert not verify_password('anything','!deleted')


def test_openapi_document():
    from openapi_spec_validator import validate
    doc=json.loads((Path(__file__).parents[2]/'docs/api/mobile-auth.openapi.json').read_text(encoding='utf-8'))
    validate(doc)
    actual=app.openapi()['paths']
    for path,ops in doc['paths'].items():
        for method in ops:assert method in actual['/api/v1'+path]


@pytest.mark.parametrize('path',['register','register/verify','register/resend','login','refresh','logout'])
def test_validation_envelope(path):
    r=TestClient(app).post('/api/v1/auth/'+path,json={})
    assert r.status_code==422
    assert r.json()['error']['code']=='VALIDATION_ERROR'
    assert isinstance(r.json()['error']['fields'],dict)
