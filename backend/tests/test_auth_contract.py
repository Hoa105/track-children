import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import password_hasher,verify_password


@pytest.mark.parametrize('password,valid', [
    ('Aa1!aa', True), ('Aa1!' + 'a' * 124, True),
    ('Aa1!a', False), ('Aa1!' + 'a' * 125, False),
    ('AA1!AA', False), ('aa1!aa', False), ('Aaa!aa', False),
    ('Aa1234', False), ('Aa1   ', False),
    ('123456', False), ('abcdef', False), ('12345', False), ('', False),
])
def test_registration_password_policy(password, valid):
    from pydantic import ValidationError
    from app.features.auth.schemas import Register
    body = dict(fullName='Test Parent', username='parent_test',
                email='parent@example.com', phone='0912345678',
                password=password, relationship='mother', consents=[])
    if valid:
        assert Register(**body).password == password
    else:
        with pytest.raises(ValidationError):
            Register(**body)


def test_password_hash():
    hashed=password_hasher.hash('real-password-123')
    assert verify_password('real-password-123',hashed)
    assert not verify_password('bad',hashed)
    assert not verify_password('anything','!deleted')


def test_auth_setup_preserves_other_features_validation():
    from fastapi import FastAPI
    from pydantic import BaseModel
    from app.features.auth.setup import install_auth

    isolated_app = FastAPI()
    install_auth(isolated_app)

    class OtherRequest(BaseModel):
        value: int

    @isolated_app.post('/other-feature')
    def other_feature(data: OtherRequest):
        return data

    client = TestClient(isolated_app)
    response = client.post('/other-feature', json={})
    assert response.status_code == 422
    assert 'detail' in response.json() and 'error' not in response.json()
    auth_response = client.post('/api/v1/auth/register', json={})
    assert auth_response.status_code == 422
    assert auth_response.json()['error']['code'] == 'VALIDATION_ERROR'


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
