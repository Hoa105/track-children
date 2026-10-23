"""Outbound SMS webhook adapter."""

import httpx
from app.core.config import settings


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
