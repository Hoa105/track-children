"""PostgreSQL auth operations. Lock order: user -> challenge/OTP/session.

Expected failures are returned, not raised, so attempts, throttles and revocations
commit before a route sends an error response.
"""
import hmac
import secrets
from datetime import timedelta
from uuid import uuid4

import httpx
from fastapi.responses import JSONResponse

from app.core import security as sec
from app.core.config import settings


def failure(status, code, *, details=None, retry=None, fields=None):
    headers = {'Cache-Control': 'no-store'}
    if retry is not None:
        headers['Retry-After'] = str(max(1, retry))
    return JSONResponse(status_code=status, content={'error': {
        'code': code, 'message': code, 'fields': fields or {}, 'details': details or {}}}, headers=headers)


def one(db, sql, args=()):
    return db.execute(sql, args).fetchone()


def quota(db, key, limit, seconds, code='RATE_LIMITED'):
    t = sec.now()
    row = one(db, '''INSERT INTO account.auth_rate_limits(key,attempts,resets_at)
        VALUES (%s,1,%s) ON CONFLICT(key) DO UPDATE SET
        attempts=CASE WHEN auth_rate_limits.resets_at<=%s THEN 1 ELSE auth_rate_limits.attempts+1 END,
        resets_at=CASE WHEN auth_rate_limits.resets_at<=%s THEN EXCLUDED.resets_at ELSE auth_rate_limits.resets_at END
        RETURNING *''', (key, t + timedelta(seconds=seconds), t, t))
    if row['attempts'] > limit:
        return failure(429, code, retry=int((row['resets_at']-t).total_seconds())+1)


def legal(db):
    rows = db.execute('''SELECT DISTINCT ON(doc_type) * FROM account.legal_documents
        WHERE doc_type IN ('terms','privacy','data_policy') AND effective_at<=%s
        ORDER BY doc_type,effective_at DESC,created_at DESC,id''', (sec.now(),)).fetchall()
    if {r['doc_type'] for r in rows} != {'terms', 'privacy', 'data_policy'}:
        return failure(503, 'LEGAL_DOCUMENTS_UNAVAILABLE')
    return rows


def public_user(u):
    names = {'id':'id','email':'email','phone':'phone','username':'username','fullName':'full_name',
             'relationship':'relationship','avatarUrl':'avatar_url','status':'status',
             'emailVerifiedAt':'email_verified_at','phoneVerifiedAt':'phone_verified_at'}
    return {k: u[v] for k,v in names.items()}


def new_session(db, user, device, remember, ip=None):
    t = sec.now()
    raw = secrets.token_urlsafe(48)
    row = one(db, '''INSERT INTO account.user_sessions
        (user_id,refresh_token_hash,device_id,device_name,platform,expires_at,ip_address,created_at,last_used_at)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *''',
        (user['id'], sec.secret_hash(raw), device.deviceId, device.deviceName,
         device.platform, t+timedelta(days=30 if remember else 1),ip,t,t))
    db.execute('UPDATE account.users SET last_login_at=%s,failed_login_attempts=0,locked_until=NULL WHERE id=%s', (t,user['id']))
    return token_result(row, raw)


def token_result(session, raw):
    t = sec.now()
    exp = min(session['expires_at'], t+timedelta(minutes=15))
    return {'tokenType':'Bearer', 'accessToken':sec.access_token(session['user_id'],session['id'],exp),
            'expiresIn':max(1,int((exp-t).total_seconds())), 'refreshToken':raw,
            'sessionExpiresAt':session['expires_at']}


def revoke(db, sid):
    db.execute('UPDATE account.user_sessions SET revoked_at=COALESCE(revoked_at,%s) WHERE id=%s', (sec.now(),sid))
    db.execute('UPDATE account.device_tokens SET is_active=false WHERE session_id=%s', (sid,))


def otp_delivery(db, user, ip, *, allow_deferred=False):
    t = sec.now()
    last = one(db, '''SELECT * FROM account.verification_codes WHERE user_id=%s AND purpose='register'
        ORDER BY created_at DESC,id DESC LIMIT 1''', (user['id'],))
    if last and last['created_at']+timedelta(seconds=60)>t:
        if allow_deferred:
            return last, 'deferred', None
        return failure(429,'RATE_LIMITED',retry=int((last['created_at']+timedelta(seconds=60)-t).total_seconds())+1)
    for key,limit in [('sms-phone:'+user['phone'],5),('sms-ip:'+ip,20)]:
        err = quota(db,key,limit,3600)
        if err: return err
    vid = uuid4()
    code = f'{secrets.randbelow(1000000):06d}'
    db.execute("UPDATE account.verification_codes SET expires_at=LEAST(expires_at,%s) WHERE user_id=%s AND purpose='register' AND used_at IS NULL", (t,user['id']))
    row = one(db, '''INSERT INTO account.verification_codes(id,user_id,target,purpose,code_hash,expires_at,created_at)
        VALUES (%s,%s,%s,'register',%s,%s,%s) RETURNING *''',
        (vid,user['id'],user['phone'],sec.otp_hash(code,str(vid)),t+timedelta(minutes=5),t))
    return row, 'sent', (user['phone'],code)


def challenge(db, user, otp, delivery, *, raw=None):
    raw = raw or secrets.token_urlsafe(48)
    if not one(db, 'SELECT id FROM account.registration_challenges WHERE token_hash=%s', (sec.secret_hash(raw),)):
        db.execute('UPDATE account.registration_challenges SET revoked_at=%s WHERE user_id=%s AND revoked_at IS NULL', (sec.now(),user['id']))
        db.execute('''INSERT INTO account.registration_challenges(user_id,target,token_hash,expires_at)
            VALUES (%s,%s,%s,%s)''', (user['id'],user['phone'],sec.secret_hash(raw),sec.now()+timedelta(minutes=30)))
    return {'verificationId':str(otp['id']),'registrationToken':raw,
            'targetMasked':user['phone'][:3]+'******'+user['phone'][-3:],
            'expiresAt':otp['expires_at'],'resendAvailableAt':otp['created_at']+timedelta(seconds=60),
            'deliveryStatus':delivery}


def send_sms(phone, code):
    """Production adapter: HTTPS webhook must return 2xx after accepting delivery.

    No console OTP fallback. Tests replace this function with a private harness.
    """
    if not settings.sms_webhook_url.startswith('https://') or not settings.sms_webhook_token:
        return False
    try:
        with httpx.Client(timeout=10, follow_redirects=False) as client:
            response = client.post(settings.sms_webhook_url, json={'to':phone,'message':f'Track Children OTP: {code}'},
                                   headers={'Authorization':'Bearer '+settings.sms_webhook_token})
        return 200 <= response.status_code < 300
    except httpx.HTTPError:
        return False


def register(db, data, ip):
    docs = legal(db)
    if isinstance(docs,JSONResponse): return docs,None
    accepted = {c.documentId for c in data.consents if c.isAccepted}
    if not {d['id'] for d in docs if d['is_required']} <= accepted or any(c.documentId not in {d['id'] for d in docs} for c in data.consents):
        return failure(409,'LEGAL_CONSENT_REQUIRED'),None
    err = quota(db,'register-ip:'+ip,20,3600)
    if err: return err,None
    # A savepoint converts unique-constraint races without aborting the outer transaction.
    import psycopg
    try:
        with db.transaction():
            u = one(db, '''INSERT INTO account.users(email,phone,username,password_hash,full_name,relationship)
                VALUES (%s,%s,%s,%s,%s,%s) RETURNING *''',
                (str(data.email),data.phone,data.username,sec.password_hasher.hash(data.password),data.fullName,data.relationship))
    except psycopg.errors.UniqueViolation:
        return failure(409,'ACCOUNT_CONFLICT'),None
    for c in data.consents:
        db.execute('INSERT INTO account.user_consents(user_id,document_id,is_accepted,ip_address) VALUES (%s,%s,%s,%s)',
                   (u['id'],c.documentId,c.isAccepted,ip))
    delivery = otp_delivery(db,u,ip)
    if isinstance(delivery,JSONResponse):
        # Preserve quota counters but do not strand a newly created pending user.
        db.execute('DELETE FROM account.users WHERE id=%s',(u['id'],))
        return delivery,None
    otp,status,sms = delivery
    return challenge(db,u,otp,status),sms


def get_challenge(db, data):
    c = one(db,'SELECT * FROM account.registration_challenges WHERE token_hash=%s',(sec.secret_hash(data.registrationToken),))
    if not c: return failure(401,'REGISTRATION_CHALLENGE_INVALID')
    u = one(db,'SELECT * FROM account.users WHERE id=%s FOR UPDATE',(c['user_id'],))
    c = one(db,'SELECT * FROM account.registration_challenges WHERE id=%s',(c['id'],))
    if not u or c['revoked_at'] or c['expires_at']<=sec.now() or c['target']!=u['phone']:
        return failure(401,'REGISTRATION_CHALLENGE_INVALID')
    if u['status']!='pending':return failure(403,'ACCOUNT_UNAVAILABLE')
    otp = one(db,"SELECT * FROM account.verification_codes WHERE id=%s AND user_id=%s AND purpose='register' AND target=%s FOR UPDATE",
              (data.verificationId,u['id'],u['phone']))
    if not otp:return failure(401,'REGISTRATION_CHALLENGE_INVALID')
    return u,otp


def verify(db,data,ip=None):
    pair = get_challenge(db,data)
    if isinstance(pair,JSONResponse):return pair
    u,otp = pair
    if otp['used_at']:return failure(409,'OTP_ALREADY_USED')
    if otp['expires_at']<=sec.now():return failure(410,'OTP_EXPIRED')
    if otp['attempts']>=5:return failure(429,'OTP_ATTEMPTS_EXCEEDED',retry=60)
    if not hmac.compare_digest(otp['code_hash'],sec.otp_hash(data.code,str(otp['id']))):
        db.execute('UPDATE account.verification_codes SET attempts=attempts+1 WHERE id=%s',(otp['id'],))
        return failure(400,'OTP_INVALID',details={'attemptsRemaining':4-otp['attempts']})
    t = sec.now()
    db.execute('UPDATE account.verification_codes SET used_at=%s WHERE id=%s',(t,otp['id']))
    u = one(db,"UPDATE account.users SET status='active',phone_verified_at=%s WHERE id=%s RETURNING *",(t,u['id']))
    return {**new_session(db,u,data.device,data.rememberMe,ip),'user':public_user(u),'deletionRequestCancelled':False}


def resend(db,data,ip):
    pair=get_challenge(db,data)
    if isinstance(pair,JSONResponse):return pair,None
    u,_=pair
    delivery=otp_delivery(db,u,ip)
    if isinstance(delivery,JSONResponse):return delivery,None
    otp,status,sms=delivery
    return challenge(db,u,otp,status,raw=data.registrationToken),sms


def login(db,data,ip):
    err=quota(db,'login-ip:'+ip,30,60)
    if err:return err,None
    err=quota(db,'login-id:'+sec.secret_hash(str(data.email).lower()),5,900,'LOGIN_TEMPORARILY_LOCKED')
    u=one(db,'SELECT * FROM account.users WHERE email=%s FOR UPDATE',(str(data.email),))
    t=sec.now()
    if err:return err,None
    if u and u['locked_until'] and u['locked_until']>t:
        return failure(429,'LOGIN_TEMPORARILY_LOCKED',retry=int((u['locked_until']-t).total_seconds())+1),None
    valid=sec.verify_password(data.password,u['password_hash'] if u else sec.dummy_hash)
    if not valid:
        if u:
            attempts=(u['failed_login_attempts'] if not u['locked_until'] or u['locked_until']>t else 0)+1
            db.execute('UPDATE account.users SET failed_login_attempts=%s,locked_until=%s WHERE id=%s',
                       (attempts,t+timedelta(minutes=15) if attempts>=5 else None,u['id']))
        return failure(401,'INVALID_CREDENTIALS'),None
    # Reset identifier throttle on successful password verification, but never SMS quota.
    db.execute('DELETE FROM account.auth_rate_limits WHERE key=%s',('login-id:'+sec.secret_hash(str(data.email).lower()),))
    db.execute('UPDATE account.users SET failed_login_attempts=0,locked_until=NULL WHERE id=%s',(u['id'],))
    if u['status']=='pending':
        delivery=otp_delivery(db,u,ip,allow_deferred=True)
        if isinstance(delivery,JSONResponse):return delivery,None
        otp,status,sms=delivery
        return failure(403,'VERIFICATION_REQUIRED',details={'registration':_json(challenge(db,u,otp,status))}),sms
    if u['status']=='locked':return failure(403,'ACCOUNT_LOCKED'),None
    cancelled=False
    if u['status']=='pending_deletion':
        r=one(db,"SELECT * FROM account.data_deletion_requests WHERE user_id=%s AND status IN ('pending','processing') FOR UPDATE",(u['id'],))
        if not r or r['status']!='pending' or not r['scheduled_at'] or r['scheduled_at']<=t:
            return failure(403,'ACCOUNT_DELETION_IN_PROGRESS'),None
        db.execute("UPDATE account.data_deletion_requests SET status='cancelled',cancelled_at=%s WHERE id=%s",(t,r['id']))
        u=one(db,"UPDATE account.users SET status='active' WHERE id=%s RETURNING *",(u['id'],))
        cancelled=True
    if u['status']!='active':return failure(403,'ACCOUNT_UNAVAILABLE'),None
    return {**new_session(db,u,data.device,data.rememberMe,ip),'user':public_user(u),'deletionRequestCancelled':cancelled},None


def _json(value):
    from fastapi.encoders import jsonable_encoder
    return jsonable_encoder(value)


def session_by_token(db,raw):
    hashed=sec.secret_hash(raw)
    found=one(db,'''SELECT user_id,id FROM account.user_sessions WHERE refresh_token_hash=%s
        UNION SELECT s.user_id,s.id FROM account.user_sessions s JOIN account.refresh_token_history h ON h.session_id=s.id
        WHERE h.token_hash=%s LIMIT 1''',(hashed,hashed))
    if not found:return None
    u=one(db,'SELECT * FROM account.users WHERE id=%s FOR UPDATE',(found['user_id'],))
    s=one(db,'SELECT * FROM account.user_sessions WHERE id=%s FOR UPDATE',(found['id'],))
    return (u,s) if s else None


def refresh(db,raw):
    pair=session_by_token(db,raw)
    if not pair:return failure(401,'REFRESH_TOKEN_INVALID')
    u,s=pair
    if s['revoked_at']:return failure(401,'SESSION_REVOKED')
    if s['expires_at']<=sec.now():return failure(401,'SESSION_EXPIRED')
    if s['refresh_token_hash']!=sec.secret_hash(raw):
        revoke(db,s['id'])
        return failure(401,'REFRESH_TOKEN_REUSED')
    if u['status']!='active':return failure(403,'ACCOUNT_UNAVAILABLE')
    new=secrets.token_urlsafe(48)
    db.execute('INSERT INTO account.refresh_token_history(token_hash,session_id,used_at) VALUES (%s,%s,%s)',(s['refresh_token_hash'],s['id'],sec.now()))
    db.execute('UPDATE account.user_sessions SET refresh_token_hash=%s,last_used_at=%s WHERE id=%s',(sec.secret_hash(new),sec.now(),s['id']))
    return token_result(s,new)
