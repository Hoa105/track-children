"""Registration against the consolidated 009 schema.

Lock order is subject -> code. Signed, purpose-scoped challenges replace the
removed registration_challenges table; only hashes of OTPs are persisted.
"""
import hmac
import json
import secrets
from datetime import timedelta, datetime
from pathlib import Path
from uuid import UUID, uuid4

import jwt
import psycopg

from app.core import security as sec
from app.core.config import settings
from app.features.auth.errors import AuthFailure, failure


def legal():
    # Reviewed content is deployed as a file, not reconstructed from deleted tables.
    try:
        docs = json.loads(Path(settings.legal_documents_path).read_text(encoding="utf-8"))
        if not isinstance(docs, list) or len(docs) != 3 or {d['docType'] for d in docs} != {'terms', 'privacy', 'data_policy'}:
            raise ValueError()
        for d in docs:
            if not d['content'].strip() or not d['version'].strip() or d['isRequired'] is not True:
                raise ValueError()
            effective = datetime.fromisoformat(d['effectiveAt'].replace('Z', '+00:00'))
            if effective.tzinfo is None or effective > sec.now():
                raise ValueError()
        return docs
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return failure(503, 'LEGAL_DOCUMENTS_UNAVAILABLE')


def configured(channel):
    if settings.auth_otp_preview and settings.app_env == 'local':
        return True
    if channel == 'email' and settings.email_provider == 'brevo':
        return bool(settings.brevo_api_key and settings.brevo_sender_email)
    if channel == 'email' and settings.email_provider == 'smtp2go':
        return bool(settings.smtp2go_api_key and settings.smtp2go_sender_email)
    if channel == 'email' and settings.email_provider != 'webhook':
        return False
    url = getattr(settings, channel + '_webhook_url' if channel == 'email' else 'sms_webhook_url')
    token = getattr(settings, channel + '_webhook_token' if channel == 'email' else 'sms_webhook_token')
    return url.startswith('https://') and bool(token)


def challenge(user, code):
    token = jwt.encode({
        'sub': str(user['id']), 'vid': str(code['id']), 'purpose': 'verify_contact',
        'iat': sec.now(), 'exp': sec.now() + timedelta(minutes=30),
        'iss': settings.auth_issuer, 'aud': 'track-children-registration',
    }, settings.auth_secret, algorithm='HS256')
    target = code['target']
    masked = (target[:1] + '***@' + target.split('@', 1)[1]) if code['channel'] == 'email' else target[:3] + '******' + target[-3:]
    return {'requiresOtp': True, 'verificationId': str(code['id']),
            'registrationToken': token, 'channel': code['channel'], 'targetMasked': masked,
            'expiresAt': code['expires_at'],
            'resendAvailableAt': code['created_at'] + timedelta(seconds=60), 'deliveryStatus': 'sent'}


def issue(db, user):
    channel = 'email' if user['email'] else 'sms'
    target = str(user['email'] or user['phone'])
    if not configured(channel):
        return failure(503, 'OTP_DELIVERY_UNAVAILABLE'), None
    # Transaction-scoped lock makes limits consistent across API workers. The
    # global hourly ceiling bounds abuse without a new rate-limit table.
    db.execute("SELECT pg_advisory_xact_lock(hashtextextended('registration-issuance',0))")
    recent = db.execute("""SELECT count(*) AS total,
        count(*) FILTER (WHERE target=%s) AS contact,
        max(created_at) FILTER (WHERE target=%s) AS latest
        FROM account.auth_codes WHERE purpose='verify_contact'
        AND created_at > %s""", (target, target, sec.now()-timedelta(hours=1))).fetchone()
    if recent['latest'] and recent['latest'] + timedelta(seconds=60) > sec.now():
        return failure(429, 'RATE_LIMITED', retry=max(1, int((recent['latest']+timedelta(seconds=60)-sec.now()).total_seconds())+1)), None
    if recent['contact'] >= 5 or recent['total'] >= 100:
        return failure(429, 'RATE_LIMITED', retry=3600), None
    db.execute("""UPDATE account.auth_codes SET consumed_at=%s
        WHERE user_id=%s AND purpose='verify_contact' AND consumed_at IS NULL""", (sec.now(), user['id']))
    vid, raw = uuid4(), f'{secrets.randbelow(1000000):06d}'
    code = db.execute("""INSERT INTO account.auth_codes
        (id,user_id,purpose,channel,target,code_hash,expires_at)
        VALUES (%s,%s,'verify_contact',%s,%s,%s,%s) RETURNING *""",
        (vid,user['id'],channel,target,sec.otp_hash(raw,str(vid)),sec.now()+timedelta(minutes=5))).fetchone()
    result = challenge(user, code)
    if settings.auth_otp_preview and settings.app_env == 'local':
        result.update(deliveryStatus='preview', devOtp=raw)
        return result, None
    return result, (channel, target, raw)


def register(db, data, ip):
    if not data.acceptedTerms:
        return failure(422, 'LEGAL_CONSENT_REQUIRED', fields={'acceptedTerms': 'required'}), None
    docs = legal()
    if isinstance(docs, AuthFailure):
        return docs, None
    channel = 'email' if data.email else 'sms'
    if not configured(channel):
        return failure(503, 'OTP_DELIVERY_UNAVAILABLE'), None
    email = str(data.email).lower() if data.email else None
    contact = email or data.phone
    # Serialize same-contact registration, including the initially absent row.
    db.execute('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', ('registration:'+contact,))
    user = db.execute('SELECT * FROM account.users WHERE email=%s OR phone=%s FOR UPDATE', (email,data.phone)).fetchone()
    if user:
        if user['status'] != 'pending' or not sec.verify_password(data.password,user['password_hash']):
            return failure(409, 'ACCOUNT_CONFLICT'), None
        # Resume only with the existing password; never overwrite a pending identity.
        return issue(db,user)
    try:
        with db.transaction():
            user = db.execute('''INSERT INTO account.users
                (email,phone,password_hash,display_name,default_relationship,consented_at)
                VALUES (%s,%s,%s,%s,%s,%s) RETURNING *''',
                (email,data.phone,sec.password_hasher.hash(data.password),data.displayName,data.defaultRelationship,sec.now())).fetchone()
            result, delivery = issue(db,user)
            if isinstance(result, AuthFailure):
                db.execute('DELETE FROM account.users WHERE id=%s', (user['id'],))
            return result, delivery
    except psycopg.errors.UniqueViolation:
        return failure(409,'ACCOUNT_CONFLICT'), None


def subject(db, data):
    try:
        claims = jwt.decode(data.registrationToken,settings.auth_secret,algorithms=['HS256'],
            issuer=settings.auth_issuer,audience='track-children-registration',
            options={'require':['sub','vid','purpose','exp','iat']})
        if claims['purpose'] != 'verify_contact' or UUID(claims['vid']) != data.verificationId:
            raise ValueError()
        uid = UUID(claims['sub'])
    except (jwt.PyJWTError, ValueError, TypeError, KeyError):
        return failure(401,'REGISTRATION_CHALLENGE_INVALID')
    user = db.execute('SELECT * FROM account.users WHERE id=%s FOR UPDATE',(uid,)).fetchone()
    code = db.execute("""SELECT * FROM account.auth_codes WHERE id=%s AND user_id=%s
        AND purpose='verify_contact' FOR UPDATE""",(data.verificationId,uid)).fetchone()
    if not user or user['status'] != 'pending' or not code or code['consumed_at']:
        return failure(401,'REGISTRATION_CHALLENGE_INVALID')
    if code['target'] != str(user['email'] if code['channel']=='email' else user['phone']):
        return failure(401,'REGISTRATION_CHALLENGE_INVALID')
    return user, code


def verify(db, data, ip):
    from app.features.auth.service import new_session, public_user
    pair = subject(db,data)
    if isinstance(pair,AuthFailure):
        return pair
    user,code = pair
    if code['expires_at'] <= sec.now():
        return failure(400,'OTP_EXPIRED')
    if code['attempt_count'] >= 5:
        return failure(429,'OTP_ATTEMPTS_EXCEEDED')
    if not hmac.compare_digest(code['code_hash'],sec.otp_hash(data.code,str(code['id']))):
        db.execute('UPDATE account.auth_codes SET attempt_count=attempt_count+1 WHERE id=%s',(code['id'],))
        remaining = 4-code['attempt_count']
        return failure(400 if remaining else 429,'OTP_INVALID' if remaining else 'OTP_ATTEMPTS_EXCEEDED', details={'attemptsRemaining':remaining})
    db.execute('UPDATE account.auth_codes SET verified_at=%s,consumed_at=%s WHERE id=%s',(sec.now(),sec.now(),code['id']))
    column = 'email_verified_at' if code['channel']=='email' else 'phone_verified_at'
    user = db.execute(f"UPDATE account.users SET status='active',{column}=%s WHERE id=%s RETURNING *",(sec.now(),user['id'])).fetchone()
    return {**new_session(db,user,data.device,data.rememberMe,ip),'user':public_user(user)}


def resend(db, data, ip):
    pair = subject(db,data)
    if isinstance(pair,AuthFailure):
        return pair,None
    return issue(db,pair[0])
