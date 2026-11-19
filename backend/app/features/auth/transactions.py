"""Short-lived server-owned capabilities. Callers own the PostgreSQL transaction."""
import hashlib
import hmac
import json
import secrets
import sqlite3
from datetime import timedelta
from pathlib import Path
from uuid import uuid4
from psycopg.types.json import Jsonb

from app.core import security as sec
from app.core.config import settings
from app.features.auth.errors import AuthFailure, failure
from app.features.auth.registration import legal, configured
from app.features.auth import sms, rate_limit
from app.features.auth import storage_validation as shapes


def ready():
    if not settings.auth_v2_enabled:
        return failure(503, 'AUTH_V2_UNAVAILABLE')
    if len(settings.auth_secret) < 32 or (settings.app_env != 'local' and len(settings.auth_otp_secret) < 32):
        return failure(503, 'AUTH_NOT_CONFIGURED')
    try:
        if not Path(settings.auth_password_blocklist_path).read_text(encoding='utf-8').strip():
            raise ValueError()
    except (OSError, ValueError):
        return failure(503, 'PASSWORD_POLICY_UNAVAILABLE')
    if settings.app_env!='local':
        try:
            manifest=json.loads(Path(settings.auth_password_blocklist_path).with_name('blocklist-manifest.json').read_text(encoding='utf-8'))
            raw=Path(settings.auth_password_blocklist_path).read_bytes()
            if manifest['entries']<10000 or not hmac.compare_digest(manifest['sha256'],hashlib.sha256(raw).hexdigest()):
                raise ValueError()
        except (OSError,ValueError,TypeError,KeyError):
            return failure(503,'PASSWORD_POLICY_UNAVAILABLE')


def quota(key, limit, seconds):
    try:
        wait = rate_limit.consume('v2:' + key, limit, seconds)
        return failure(429, 'RATE_LIMITED', retry=wait) if wait else None
    except (OSError, sqlite3.Error):
        return failure(503, 'RATE_LIMIT_UNAVAILABLE')


def documents():
    docs = legal()
    if isinstance(docs, AuthFailure):
        return docs
    snapshot = [{'type': d['docType'], 'version': d['version'],
                 'sha256': sec.secret_hash(d['content'])} for d in docs]
    snapshot.sort(key=lambda d: d['type'])
    if not shapes.valid_documents(snapshot):
        return failure(503, 'LEGAL_DOCUMENTS_UNAVAILABLE')
    return snapshot, sec.secret_hash(json.dumps(snapshot, sort_keys=True, ensure_ascii=False))


def consent(db, user_id, tx_id, digest, accepted):
    current = documents()
    if isinstance(current, AuthFailure):
        return current
    snapshot, expected = current
    if not accepted:
        return failure(422, 'LEGAL_CONSENT_REQUIRED')
    if not hmac.compare_digest(digest, expected):
        return failure(409, 'LEGAL_DOCUMENTS_CHANGED')
    db.execute('''INSERT INTO account.auth_consent_receipts(user_id,transaction_id,documents)
                  VALUES (%s,%s,%s)''', (user_id, tx_id, Jsonb(snapshot)))


def create(db, purpose, *, user_id=None, session_id=None, target=None, channel=None, metadata=None, minutes=10):
    shapes.validate_metadata(purpose, {} if metadata is None else metadata)
    if session_id:
        owner = db.execute('SELECT user_id FROM account.user_sessions WHERE id=%s', (session_id,)).fetchone()
        if not owner or str(owner['user_id']) != str(user_id):
            raise ValueError('Auth transaction session owner mismatch')
    token = secrets.token_urlsafe(48)
    row = db.execute('''INSERT INTO account.auth_transactions
        (purpose,user_id,session_id,target,channel,secret_hash,metadata,expires_at,created_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *''',
        (purpose,user_id,session_id,target,channel,sec.secret_hash(token),Jsonb(metadata or {}),
         sec.now()+timedelta(minutes=minutes),sec.now())).fetchone()
    return row, token


def ticket(row, token):
    result = {'transactionId': str(row['id']), 'transactionToken': token,
              'expiresAt': row['expires_at'], 'resendAvailableAt': row['resend_at']}
    if row['target']:
        target = row['target']
        result['targetMasked'] = (target[:1]+'***@'+target.split('@',1)[1]) if '@' in target else target[:3]+'******'+target[-3:]
    return result


def load(db, data, purpose, *, allow_expired=False, allow_consumed=False):
    row = db.execute('SELECT * FROM account.auth_transactions WHERE id=%s FOR UPDATE', (data.transactionId,)).fetchone()
    if (not row or row['purpose'] != purpose or shapes.SYSTEM_KEYS.intersection(row['metadata'])
            or row['metadata'].get('legacyCode') or (row['consumed_at'] and not allow_consumed) or row['invalidated_at']
            or (row['expires_at'] <= sec.now() and not allow_expired)
            or row['created_at']+timedelta(minutes=30) <= sec.now()
            or not hmac.compare_digest(row['secret_hash'], sec.secret_hash(data.transactionToken))):
        return failure(401, 'TRANSACTION_INVALID')
    return row


def consume(db, row):
    db.execute('UPDATE account.auth_transactions SET consumed_at=%s WHERE id=%s', (sec.now(), row['id']))


def request_digest(data):
    payload=data.model_dump(mode='json',exclude={'transactionToken'})
    return hmac.new(settings.auth_secret.encode(),
                    ('auth-completion:'+json.dumps(payload,sort_keys=True,ensure_ascii=False)).encode(),
                    hashlib.sha256).hexdigest()


def mark_completed(db,row,data,user_id):
    metadata={**row['metadata'],'completion':{'digest':request_digest(data),'userId':str(user_id)}}
    db.execute('UPDATE account.auth_transactions SET metadata=%s,consumed_at=%s WHERE id=%s',
               (Jsonb(metadata),sec.now(),row['id']))


def replay_result(db,row,data,*,reset=False):
    completion=row['metadata'].get('completion',{})
    if not row['consumed_at'] or not hmac.compare_digest(completion.get('digest',''),request_digest(data)):
        return failure(401,'TRANSACTION_INVALID')
    owner=db.execute('SELECT status FROM account.users WHERE id=%s',(completion.get('userId'),)).fetchone()
    if not owner or owner['status']!='active':
        return failure(401,'TRANSACTION_INVALID')
    # Report the previous commit; never replay credentials or undo newer changes.
    return {'reset':True,'alreadyCompleted':True} if reset else {'completed':True,'requiresLogin':True}


def hash_code(raw, tx_id):
    return hmac.new((settings.auth_otp_secret or settings.auth_secret).encode(),
                    f'{tx_id}:{raw}'.encode(), hashlib.sha256).hexdigest()


def send(db, row, token, ip, *, ip_is_hash=False):
    if row['channel']=='email' and row['user_id']:
        from app.features.auth.notices import relay_disabled
        if relay_disabled(db,row['user_id'],row['target']):
            return failure(503,'OTP_DELIVERY_UNAVAILABLE')
    if not configured(row['channel']):
        return failure(503, 'OTP_DELIVERY_UNAVAILABLE')
    if row['resend_at'] and row['resend_at'] > sec.now():
        return failure(429,'RATE_LIMITED',retry=max(1,int((row['resend_at']-sec.now()).total_seconds())+1))
    error=quota('otp-cooldown:'+row['purpose']+':'+sec.secret_hash(row['target']),1,60)
    if error:
        return error
    for key, limit, window in [('otp-target:'+sec.secret_hash(row['target']),settings.auth_otp_target_limit,3600),
                                ('otp-ip:'+(ip if ip_is_hash else sec.secret_hash(ip)),settings.auth_otp_ip_limit,3600), ('otp-global',settings.auth_otp_global_limit,3600)]:
        error = quota(key,limit,window)
        if error:
            return error
    raw = f'{secrets.randbelow(1000000):06d}'
    preview = settings.auth_otp_preview and settings.app_env == 'local'
    # Delivery acceptance precedes replacing the old code. A failed/uncertain
    # send never makes the new code valid; the old code retains its deadline.
    if not preview and not sms.send_code(row['channel'],row['target'],raw):
        return failure(503,'OTP_DELIVERY_UNAVAILABLE')
    row = db.execute('''UPDATE account.auth_transactions SET code_hash=%s,attempt_count=0,
        verified_at=NULL,metadata=metadata-'verifiedCodeHash',expires_at=%s,resend_at=%s WHERE id=%s RETURNING *''',
        (hash_code(raw,row['id']),sec.now()+timedelta(minutes=5),sec.now()+timedelta(seconds=60),row['id'])).fetchone()
    result = ticket(row,token) if token is not None else {'expiresAt':row['expires_at'],'resendAvailableAt':row['resend_at']}
    result['deliveryStatus'] = 'preview' if preview else 'sent'
    if preview:
        result['devOtp'] = raw
    return result


def verify(db, row, code):
    if row['verified_at']:
        if hmac.compare_digest(row['metadata'].get('verifiedCodeHash',''),hash_code(code,row['id'])):
            return row
        return failure(401,'TRANSACTION_INVALID')
    if not row['code_hash']:
        return failure(401,'TRANSACTION_INVALID')
    if row['attempt_count'] >= 5:
        return failure(429,'OTP_ATTEMPTS_EXCEEDED')
    if not hmac.compare_digest(hash_code(code,row['id']),row['code_hash']):
        metadata={**row['metadata'],'failureTimes':[*row['metadata'].get('failureTimes',[]),sec.now().isoformat()]}
        db.execute('UPDATE account.auth_transactions SET attempt_count=attempt_count+1,metadata=%s WHERE id=%s', (Jsonb(metadata),row['id']))
        left = 4-row['attempt_count']
        return failure(400 if left else 429,'OTP_INVALID' if left else 'OTP_ATTEMPTS_EXCEEDED',details={'attemptsRemaining':left})
    metadata={**row['metadata'],'verifiedCodeHash':row['code_hash']}
    return db.execute('''UPDATE account.auth_transactions SET verified_at=%s,code_hash=NULL,
       metadata=%s,expires_at=%s WHERE id=%s RETURNING *''', (sec.now(),Jsonb(metadata),sec.now()+timedelta(minutes=10),row['id'])).fetchone()


def invalidate_other(db, user_id, exclude=None):
    db.execute('''UPDATE account.auth_transactions SET invalidated_at=%s
        WHERE user_id=%s AND consumed_at IS NULL AND invalidated_at IS NULL
        AND (%s::uuid IS NULL OR id<>%s::uuid)''', (sec.now(),user_id,exclude,exclude))


def record_device(db, user_id, device):
    if device.deviceId:
        # Lock the owning row: concurrent logins cannot overwrite each other's
        # MRU updates. This bounded cache is a risk signal, never authentication.
        user=db.execute('SELECT auth_known_devices FROM account.users WHERE id=%s FOR UPDATE', (user_id,)).fetchone()
        if not shapes.valid_devices(user['auth_known_devices']):
            raise ValueError('Invalid existing auth device cache; review before updating')
        digest=sec.secret_hash(device.deviceId)
        previous=[entry for entry in user['auth_known_devices'] if entry['hash'] != digest]
        known=[{'hash':digest,'lastAuthenticatedAt':sec.now().isoformat()},*previous][:16]
        db.execute('UPDATE account.users SET auth_known_devices=%s WHERE id=%s', (Jsonb(known),user_id))


def known_devices(user):
    from datetime import datetime
    if not shapes.valid_devices(user['auth_known_devices']):
        return set()  # Malformed history never establishes a familiar device.
    return {entry['hash'] for entry in user['auth_known_devices']
            if datetime.fromisoformat(entry['lastAuthenticatedAt'])>sec.now()-timedelta(days=90)}
