"""Run only the approved test DB; do not edit .env or migrate the application DB."""
import argparse
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import psycopg
from psycopg.rows import dict_row

root=Path(__file__).resolve().parents[1]
os.chdir(root);sys.path.insert(0,str(root));sys.path.insert(0,str(root/'scripts'))
from prepare_auth_v2_test_db import test_url

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8010);args=parser.parse_args()
    url=test_url()
    with psycopg.connect(url,row_factory=dict_row,connect_timeout=5) as db:
        if not db.execute("SELECT to_regclass('account.auth_transactions') AS t").fetchone()['t'] or not db.execute("SELECT 1 FROM information_schema.columns WHERE table_schema='account' AND table_name='users' AND column_name='auth_known_devices'").fetchone():
            raise SystemExit('Dedicated test DB requires approved migrations 023/024. Application DB was not changed.')
    runtime=root/'.runtime';runtime.mkdir(exist_ok=True)
    secret_file=runtime/'auth-simulation-secrets.json'
    if not secret_file.exists():
        secret_file.write_text(json.dumps({'auth':secrets.token_urlsafe(48),'otp':secrets.token_urlsafe(48)}),encoding='utf-8')
    local=json.loads(secret_file.read_text(encoding='utf-8'))
    env={**os.environ,'DATABASE_URL':url,'APP_ENV':'local','AUTH_V2_ENABLED':'true','AUTH_SIMULATION':'true',
         'DEV_AUTH':'false','AUTH_SKIP_OTP':'false','AUTH_OTP_PREVIEW':'false','AUTH_SECRET':local['auth'],'AUTH_OTP_SECRET':local['otp'],
         'AUTH_PASSWORD_BLOCKLIST_PATH':str(root/'data/auth/common-passwords.txt'),
         'LEGAL_DOCUMENTS_PATH':str(root/'legal-documents.local.json'),
         'AUTH_RATE_LIMIT_PATH':str(runtime/'auth-simulation-limits.sqlite3'),'AUTH_RATE_LIMIT_BACKEND':'sqlite'}
    print(f'Local test DB only. OTP/outbox: http://127.0.0.1:{args.port}/api/v1/auth/testing',flush=True)
    return subprocess.call([sys.executable,'-m','uvicorn','app.auth_simulation_app:app','--host','127.0.0.1','--port',str(args.port),'--no-access-log'],env=env)

if __name__=='__main__':sys.exit(main())
