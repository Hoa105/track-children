"""Read-only rollout diagnostics. Never print credentials or send provider requests."""
import json
import sys
import os
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
os.chdir(Path(__file__).resolve().parents[1])
from app.core.config import settings
from app.features.auth import transactions as tx,social
from app.features.auth.registration import configured
from app.core.database import transaction

def report():
    state={'v2Enabled':settings.auth_v2_enabled,'productionEnvironment':settings.app_env=='production',
           'secretsConfigured':len(settings.auth_secret)>=32 and len(settings.auth_otp_secret)>=32,
           'otpPreviewDisabled':not settings.auth_otp_preview and not settings.auth_skip_otp,
           'googleAudiencesConfigured':bool(settings.google_client_ids),'appleConfigured':social.apple_configured(),
           'smsConfigured':bool(settings.sms_webhook_url.startswith('https://') and settings.sms_webhook_token),
           'emailConfigured':configured('email') and not settings.auth_otp_preview,
           'securityNoticeConfigured':bool(settings.auth_security_webhook_url.startswith('https://') and settings.auth_security_webhook_token),
           'sharedLimiter':settings.auth_rate_limit_backend=='postgres'}
    try:
        lines=Path(settings.auth_password_blocklist_path).read_text(encoding='utf-8').splitlines()
        state['passwordBlocklistEntries']=len(set(lines))
    except (OSError,ValueError):state['passwordBlocklistEntries']=0
    docs=tx.documents();state['legalDocumentsConfigured']=not hasattr(docs,'code')
    try:
        with transaction() as db:
            db.execute('SET TRANSACTION READ ONLY')
            state['authTablesReady']=all(db.execute('SELECT to_regclass(%s) AS t',(name,)).fetchone()['t'] is not None
                for name in ('account.auth_transactions','account.auth_consent_receipts','account.auth_refresh_history'))
            state['deviceColumnReady']=bool(db.execute("SELECT 1 FROM information_schema.columns WHERE table_schema='account' AND table_name='users' AND column_name='auth_known_devices'").fetchone())
            if state['authTablesReady']:
                state['failedJobs']=db.execute("SELECT count(*) AS n FROM account.auth_transactions WHERE metadata->'notice'->>'state'='failed' OR metadata->'delivery'->>'state'='failed'").fetchone()['n']
    except Exception:state['databaseReachable']=False
    else:state['databaseReachable']=True
    # Config checks are not evidence of delivery, legal review or physical-device E2E.
    return state

if __name__=='__main__':print(json.dumps(report(),indent=2))
