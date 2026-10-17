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
    service.send_sms=fake_sms
    with transaction() as db:
        for kind in ['terms','privacy','data_policy']:
            db.execute("""INSERT INTO account.legal_documents(doc_type,version,content,effective_at)
                VALUES (%s,'live-test','Local integration test terms',now()-interval '1 day')
                ON CONFLICT(doc_type,version) DO NOTHING""",(kind,))
    uvicorn.run(app,host='127.0.0.1',port=8009,access_log=False)


if __name__=='__main__':main()
