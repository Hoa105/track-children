"""Local-only harness for Flutter -> real HTTP -> FastAPI -> PostgreSQL smoke.

Not imported by the application. OTP is available only in a private test file,
never via an API endpoint or normal server logs. Use only the dedicated test DB.
"""
import json
import os
from pathlib import Path
from urllib.parse import urlparse

import uvicorn

from app.core.config import settings
from app.core.database import transaction
from app.features.auth import service
from app.features.auth import sms as sms_gateway
from app.main import app


def main():
    url=os.environ['AUTH_TEST_DATABASE_URL']
    if not urlparse(url).path.endswith('_test'):
        raise RuntimeError('Live harness requires a dedicated *_test database')
    settings.database_url=url
    settings.auth_secret='local-live-test-secret-only-12345678901234567890'
    sms_file=Path(__file__).resolve().parents[3]/'.auth-test-logs/sms.json'
    sms_file.parent.mkdir(exist_ok=True)
    def fake_sms(phone,code):
        temporary=sms_file.with_suffix('.tmp')
        temporary.write_text(json.dumps({'phone':phone,'code':code}),encoding='utf-8')
        temporary.replace(sms_file)
        return True
    sms_gateway.send_sms=fake_sms
    sms_gateway.send_code=lambda channel,target,code:fake_sms(target,code)
    settings.auth_v2_enabled=False
    settings.app_env='local'
    settings.auth_skip_otp=False
    settings.auth_otp_preview=False
    settings.email_provider='webhook'
    settings.email_webhook_url='https://email.test.invalid'
    settings.email_webhook_token='test-only'
    settings.legal_documents_path=str(Path(__file__).parents[2]/'legal-documents.local.json')
    settings.auth_rate_limit_path=str(sms_file.parent/'live-limits.sqlite3')
    uvicorn.run(app,host='127.0.0.1',port=8009,access_log=False)


if __name__=='__main__':main()
