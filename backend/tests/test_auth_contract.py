import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import password_hasher,verify_password


@pytest.mark.parametrize('password,valid', [
    ('abcdefgh', True), ('a' * 64, True), ('a password 123', True),
    ('a' * 7, False), ('a' * 65, False), ('', False),
])
def test_registration_password_policy(password, valid):
    from pydantic import ValidationError
    from app.features.auth.schemas import Register
    body = dict(displayName='Test Parent', email='parent@example.com',
                password=password, defaultRelationship='mother', acceptedTerms=True)
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


@pytest.mark.parametrize('status,accepted',[(202,True),(500,False)])
def test_email_adapter_payload_and_failure(monkeypatch,status,accepted):
    import httpx
    from app.core.config import settings
    from app.features.auth import sms
    monkeypatch.setattr(settings,'email_provider','webhook')
    monkeypatch.setattr(settings,'email_webhook_url','https://example.com/otp')
    monkeypatch.setattr(settings,'email_webhook_token','test-token')
    original=httpx.Client
    def receive(request):
        assert request.headers['Authorization']=='Bearer test-token'
        body=json.loads(request.content)
        assert body['to']=='parent@example.com' and '123456' in body['message']
        assert body['subject']
        return httpx.Response(status)
    monkeypatch.setattr(sms.httpx,'Client',lambda **kwargs: original(transport=httpx.MockTransport(receive),**kwargs))
    assert sms.send_code('email','parent@example.com','123456') is accepted
