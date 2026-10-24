"""Outbound OTP email and SMS adapters."""

from email.utils import formataddr

import httpx
from app.core.config import settings


def send_code(channel, target, code):
    if channel == 'sms':
        return send_sms(target, code)
    if channel == 'email' and settings.email_provider == 'brevo':
        return send_brevo(target, code)
    if channel == 'email' and settings.email_provider == 'smtp2go':
        return send_smtp2go(target, code)
    if settings.email_provider != 'webhook':
        return False
    if channel != 'email' or not settings.email_webhook_url.startswith('https://') or not settings.email_webhook_token:
        return False
    try:
        with httpx.Client(timeout=10, follow_redirects=False) as client:
            response = client.post(settings.email_webhook_url,
                json={'to': target, 'subject': 'Track Children: xác minh tài khoản',
                      'message': f'Mã xác minh Track Children: {code}. Mã có hiệu lực 5 phút.'},
                headers={'Authorization': 'Bearer ' + settings.email_webhook_token})
        return 200 <= response.status_code < 300
    except httpx.HTTPError:
        return False


def send_smtp2go(target, code):
    """Accept only an explicit successful single-recipient API response."""
    if not settings.smtp2go_api_key or not settings.smtp2go_sender_email:
        return False
    try:
        with httpx.Client(timeout=10, follow_redirects=False) as client:
            response = client.post(
                'https://api.smtp2go.com/v3/email/send',
                headers={'X-Smtp2go-Api-Key': settings.smtp2go_api_key,
                         'accept': 'application/json'},
                json={
                    'sender': formataddr((settings.smtp2go_sender_name, settings.smtp2go_sender_email)),
                    'to': [target],
                    'subject': 'Track Children: xác minh tài khoản',
                    'text_body': f'Mã xác minh Track Children: {code}. Mã có hiệu lực 5 phút. Không chia sẻ mã này với người khác.',
                },
            )
        if response.status_code != 200:
            return False
        result = response.json()
        data = result.get('data') if isinstance(result, dict) else None
        return (isinstance(data, dict) and data.get('succeeded') == 1
                and data.get('failed') == 0 and not data.get('error')
                and not data.get('error_code') and not data.get('failures'))
    except (httpx.HTTPError, ValueError):
        return False


def send_brevo(target, code):
    """Send via Brevo using an already verified sender; never log credentials/OTP."""
    if not settings.brevo_api_key or not settings.brevo_sender_email:
        return False
    try:
        with httpx.Client(timeout=10, follow_redirects=False) as client:
            response = client.post(
                'https://api.brevo.com/v3/smtp/email',
                headers={'api-key': settings.brevo_api_key, 'accept': 'application/json'},
                json={
                    'sender': {'email': settings.brevo_sender_email, 'name': settings.brevo_sender_name},
                    'to': [{'email': target}],
                    'subject': 'Track Children: xác minh tài khoản',
                    'textContent': f'Mã xác minh Track Children: {code}. Mã có hiệu lực 5 phút. Không chia sẻ mã này với người khác.',
                },
            )
        return response.status_code == 201
    except httpx.HTTPError:
        return False


def send_sms(phone, code):
    """Production adapter: HTTPS webhook must return 2xx after accepting delivery.

    No console OTP fallback. Tests replace this function with a private harness.
    """
    if (
        not settings.sms_webhook_url.startswith("https://")
        or not settings.sms_webhook_token
    ):
        return False
    try:
        with httpx.Client(timeout=10, follow_redirects=False) as client:
            response = client.post(
                settings.sms_webhook_url,
                json={"to": phone, "message": f"Track Children OTP: {code}"},
                headers={"Authorization": "Bearer " + settings.sms_webhook_token},
            )
        return 200 <= response.status_code < 300
    except httpx.HTTPError:
        return False
