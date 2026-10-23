import json

import httpx
import pytest

from app.core.config import settings
from app.features.auth import sms, registration


@pytest.fixture
def configured(monkeypatch):
    monkeypatch.setattr(settings, 'email_provider', 'smtp2go')
    monkeypatch.setattr(settings, 'smtp2go_api_key', 'test-key')
    monkeypatch.setattr(settings, 'smtp2go_sender_email', 'student@example.edu.vn')
    monkeypatch.setattr(settings, 'smtp2go_sender_name', 'Track Children')
    monkeypatch.setattr(settings, 'auth_otp_preview', False)


@pytest.mark.parametrize('status,body,accepted', [
    (200, {'data': {'succeeded': 1, 'failed': 0, 'failures': []}}, True),
    (200, {'data': {'succeeded': 0, 'failed': 1}}, False),
    (200, {'data': {'error': 'sender not verified'}}, False),
    (200, {'data': {'succeeded': 1, 'failed': 1}}, False),
    (200, [], False),
    (200, {'data': None}, False),
    (401, {'data': {'error': 'invalid key'}}, False),
    (429, {}, False),
    (500, {}, False),
])
def test_send(configured, monkeypatch, status, body, accepted):
    original = httpx.Client

    def receive(request):
        assert str(request.url) == 'https://api.smtp2go.com/v3/email/send'
        assert request.headers['X-Smtp2go-Api-Key'] == 'test-key'
        data = json.loads(request.content)
        assert data['sender'] == 'Track Children <student@example.edu.vn>'
        assert data['to'] == ['parent@example.com']
        assert '123456' in data['text_body']
        assert 'api_key' not in data
        return httpx.Response(status, json=body)

    monkeypatch.setattr(sms.httpx, 'Client', lambda **kwargs: original(transport=httpx.MockTransport(receive), **kwargs))
    assert registration.configured('email') is True
    assert sms.send_code('email', 'parent@example.com', '123456') is accepted


@pytest.mark.parametrize('missing', ['smtp2go_api_key', 'smtp2go_sender_email'])
def test_missing_configuration(configured, monkeypatch, missing):
    monkeypatch.setattr(settings, missing, '')
    assert registration.configured('email') is False
    assert sms.send_code('email', 'parent@example.com', '123456') is False


@pytest.mark.parametrize('failure', ['timeout', 'invalid_json'])
def test_transport_failure(configured, monkeypatch, failure):
    original = httpx.Client

    def receive(request):
        if failure == 'timeout':
            raise httpx.ReadTimeout('test timeout', request=request)
        return httpx.Response(200, text='not JSON')

    monkeypatch.setattr(sms.httpx, 'Client', lambda **kwargs: original(transport=httpx.MockTransport(receive), **kwargs))
    assert sms.send_code('email', 'parent@example.com', '123456') is False
