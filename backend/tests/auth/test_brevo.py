import json

import httpx
import pytest

from app.core.config import settings
from app.features.auth import sms, registration


@pytest.mark.parametrize('status,accepted', [(201, True), (400, False), (401, False), (429, False), (500, False)])
def test_brevo_request(monkeypatch, status, accepted):
    monkeypatch.setattr(settings, 'email_provider', 'brevo')
    monkeypatch.setattr(settings, 'brevo_api_key', 'test-key')
    monkeypatch.setattr(settings, 'brevo_sender_email', 'student@example.edu.vn')
    original = httpx.Client

    def receive(request):
        assert str(request.url) == 'https://api.brevo.com/v3/smtp/email'
        assert request.headers['api-key'] == 'test-key'
        data = json.loads(request.content)
        assert data['sender']['email'] == 'student@example.edu.vn'
        assert data['to'] == [{'email': 'parent@example.com'}]
        assert '123456' in data['textContent']
        return httpx.Response(status)

    monkeypatch.setattr(sms.httpx, 'Client', lambda **kwargs: original(transport=httpx.MockTransport(receive), **kwargs))
    assert sms.send_code('email', 'parent@example.com', '123456') is accepted


def test_brevo_missing_credentials(monkeypatch):
    monkeypatch.setattr(settings, 'auth_otp_preview', False)
    monkeypatch.setattr(settings, 'email_provider', 'brevo')
    monkeypatch.setattr(settings, 'brevo_api_key', '')
    assert registration.configured('email') is False
    assert sms.send_code('email', 'parent@example.com', '123456') is False


def test_brevo_timeout(monkeypatch):
    monkeypatch.setattr(settings, 'brevo_api_key', 'test-key')
    monkeypatch.setattr(settings, 'brevo_sender_email', 'student@example.edu.vn')
    original = httpx.Client

    def timeout(request):
        raise httpx.ReadTimeout('test timeout', request=request)

    monkeypatch.setattr(sms.httpx, 'Client', lambda **kwargs: original(transport=httpx.MockTransport(timeout), **kwargs))
    assert sms.send_brevo('parent@example.com', '123456') is False
