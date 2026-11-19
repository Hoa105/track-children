"""SMS-only recovery with server-owned risk gates and independent proof."""
from datetime import timedelta,datetime
from psycopg.types.json import Jsonb
from app.core import security as sec
from app.core.config import settings
from app.features.auth import transactions as tx, validation, social
from app.features.auth.errors import AuthFailure, failure
from app.features.auth.account_security import revoke_all,changed,fresh_provider

MESSAGE = 'Nếu thông tin đủ điều kiện, mã xác minh sẽ được gửi đến bạn.'
SUPPORT = 'Yêu cầu này cần được kiểm tra thêm để bảo vệ tài khoản. Bạn có thể dùng phương thức đã liên kết hoặc liên hệ hỗ trợ.'


def eligible(user,identifier):
    if not user or user['status'] != 'active' or not user['password_hash'] or user['password_hash'].startswith('!'):
        return False
    return bool(user['email_verified_at'] if '@' in identifier else user['phone_verified_at'])


def risk_reasons(*,new_device,last_activity,security_changed,failures,now):
    if not new_device:
        return []
    reasons=[]
    if last_activity and now-last_activity >= timedelta(days=settings.auth_recovery_inactive_days):
        reasons.append('inactive_90d')
    if failures >= settings.auth_recovery_failure_limit:
        reasons.append('recovery_failures_30m')
    if security_changed and now-security_changed < timedelta(hours=settings.auth_recovery_security_hours):
        reasons.append('security_change_24h')
    return reasons


def assess(db,user,device):
    known = tx.known_devices(user)
    # An unknown baseline is not proof of a familiar device. It still takes a
    # second signal (inactivity/failures/change) to require independent proof.
    new = sec.secret_hash(device.deviceId or '') not in known
    failures = recent_failures(db,user['id'])
    return risk_reasons(new_device=new,last_activity=user['last_login_at'],
        security_changed=security_changed_at(db,user),failures=failures,now=sec.now())


def security_changed_at(db,user):
    latest=db.execute('''SELECT max(consumed_at) AS latest FROM account.auth_transactions
        WHERE user_id=%s AND purpose IN ('change_email','change_phone') AND consumed_at IS NOT NULL
        AND verified_at IS NOT NULL AND metadata->>'applied'='true' ''',(user['id'],)).fetchone()['latest']
    return max((value for value in (latest,user.get('password_changed_at')) if value is not None),default=None)


def recent_failures(db,user_id):
    rows=db.execute('''SELECT metadata FROM account.auth_transactions WHERE purpose='password_reset'
       AND user_id=%s AND created_at >= %s''',(user_id,sec.now()-timedelta(minutes=90))).fetchall()
    return sum(1 for row in rows for value in row['metadata'].get('failureTimes',[])
               if datetime.fromisoformat(value)>sec.now()-timedelta(minutes=settings.auth_recovery_failure_minutes))


def start(db,data,ip):
    for key,limit,window in [('reset-ip:'+ip,20,3600),('reset-id:'+sec.secret_hash(data.identifier),5,3600)]:
        error = tx.quota(key,limit,window)
        if error:
            return error
    field = 'email' if '@' in data.identifier else 'phone'
    user = db.execute(f'SELECT * FROM account.users WHERE {field}=%s',(data.identifier,)).fetchone()
    allowed = eligible(user,data.identifier)
    row,token = tx.create(db,'password_reset',user_id=user['id'] if allowed else None,
        target=data.identifier,channel='email' if field=='email' else 'sms',
        metadata={'deviceHash':sec.secret_hash(data.device.deviceId or ''),'requiresExtra':False,
                  'delivery':{'state':'pending','attempts':0,'nextAttemptAt':sec.now().isoformat(),
                              'ipHash':sec.secret_hash(ip)}},minutes=5)
    # Return identical public state before any outbound provider call. A task
    # runs for both eligible and dummy requests, after the response is sent.
    row=db.execute('''UPDATE account.auth_transactions SET code_hash=%s,resend_at=%s
       WHERE id=%s RETURNING *''',(sec.secret_hash(__import__('secrets').token_urlsafe(32)),sec.now()+timedelta(seconds=60),row['id'])).fetchone()
    return {**tx.ticket(row,token),'message':MESSAGE}


def deliver(data,ip=None):
    from app.core.database import transaction
    with transaction() as db:
        reference=db.execute('SELECT user_id FROM account.auth_transactions WHERE id=%s',(data['transactionId'],)).fetchone()
        if reference and reference['user_id']:
            db.execute('SELECT id FROM account.users WHERE id=%s FOR UPDATE',(reference['user_id'],))
        row=db.execute('SELECT * FROM account.auth_transactions WHERE id=%s FOR UPDATE SKIP LOCKED',(data['transactionId'],)).fetchone()
        if not row or not root_ticket(row):
            return
        job=row['metadata'].get('delivery',{})
        if job.get('state')!='pending' or datetime.fromisoformat(job['nextAttemptAt'])>sec.now():
            return
        def finish(state,**extra):
            db.execute("UPDATE account.auth_transactions SET metadata=jsonb_set(metadata,'{delivery}',%s) WHERE id=%s",
                       (Jsonb({**job,'state':state,**extra}),row['id']))
        if row['consumed_at'] or row['invalidated_at'] or row['verified_at'] or row['expires_at']<=sec.now():
            finish('cancelled');return
        user=db.execute('SELECT * FROM account.users WHERE id=%s',(row['user_id'],)).fetchone() if row['user_id'] else None
        if not eligible(user,row['target']):
            finish('cancelled');return
        row['resend_at']=None
        result=tx.send(db,row,None,job['ipHash'],ip_is_hash=True)
        attempts=job['attempts']+1
        if not isinstance(result,AuthFailure):
            # Keep the deadline already shown to the caller. Delayed delivery
            # must not silently extend a recovery ticket or reveal eligibility.
            db.execute('UPDATE account.auth_transactions SET expires_at=%s WHERE id=%s',(row['expires_at'],row['id']))
            finish('delivered',attempts=attempts)
            db.execute('''UPDATE account.auth_transactions SET invalidated_at=%s
               WHERE purpose='password_reset' AND target=%s AND id<>%s
               AND created_at<=%s
               AND verified_at IS NULL AND consumed_at IS NULL AND invalidated_at IS NULL''',
               (sec.now(),row['target'],row['id'],row['created_at']))
        else:
            wait=max(60, result.retry or 60*(2**(attempts-1)))
            finish('failed' if attempts>=3 else 'pending',attempts=attempts,
                   nextAttemptAt=(sec.now()+timedelta(seconds=wait)).isoformat())


def process_pending(limit=50):
    """Periodic worker resumes committed jobs after process loss; no raw OTP/token stored."""
    from app.core.database import transaction
    with transaction() as db:
        jobs=db.execute('''SELECT id FROM account.auth_transactions
            WHERE purpose='password_reset' AND metadata->'delivery'->>'state'='pending'
            AND (metadata->'delivery'->>'nextAttemptAt')::timestamptz<=%s
            ORDER BY created_at LIMIT %s''',(sec.now(),limit)).fetchall()
    for job in jobs:
        deliver({'transactionId':job['id']})
    return len(jobs)


def root_ticket(row):
    return not row['metadata'].get('parent') and isinstance(row['metadata'].get('deviceHash'),str)


def verification_options(db,user,row):
    options=[]
    if ('@' not in row['target'] and user['email_verified_at'] and
            user['email_verified_at']<row['created_at'] and
            sec.now()-user['email_verified_at']>=timedelta(hours=settings.auth_recovery_security_hours)):
        options.append('email')
    links=db.execute('SELECT provider,created_at FROM account.social_identities WHERE user_id=%s',(user['id'],)).fetchall()
    options += [link['provider'] for link in links if link['created_at']<row['created_at']
                and sec.now()-link['created_at']>=timedelta(hours=settings.auth_recovery_security_hours)]
    return [*options,'support']


def locked(db,data,*,allow_consumed=False):
    # Lock identity first; all commit/reset/password flows use the same order.
    reference = db.execute('SELECT user_id FROM account.auth_transactions WHERE id=%s',(data.transactionId,)).fetchone()
    user = None
    if reference and reference['user_id']:
        user = db.execute('SELECT * FROM account.users WHERE id=%s FOR UPDATE',(reference['user_id'],)).fetchone()
    row = tx.load(db,data,'password_reset',allow_consumed=allow_consumed)
    return row if isinstance(row,AuthFailure) else (user,row)


def resend(db,data,ip):
    from app.features.auth.schemas_v2 import RecoveryStart
    reference=db.execute('SELECT user_id FROM account.auth_transactions WHERE id=%s',(data.transactionId,)).fetchone()
    if reference and reference['user_id']:
        db.execute('SELECT id FROM account.users WHERE id=%s FOR UPDATE',(reference['user_id'],))
    row=tx.load(db,data,'password_reset',allow_expired=True)
    if isinstance(row,AuthFailure):
        return row
    if not root_ticket(row) or row['verified_at'] or row['metadata']['deviceHash']!=sec.secret_hash(data.device.deviceId or ''):
        return failure(401,'TRANSACTION_INVALID')
    if row['resend_at'] and row['resend_at']>sec.now():
        return failure(429,'RATE_LIMITED',retry=max(1,int((row['resend_at']-sec.now()).total_seconds())+1))
    return start(db,RecoveryStart(identifier=row['target'],device=data.device),ip)


def verify(db,data,ip):
    error=tx.quota('reset-verify-ip:'+ip,60,3600)
    if error:
        return error
    pair=locked(db,data)
    if isinstance(pair,AuthFailure):
        return pair
    user,row=pair
    if not root_ticket(row) or row['metadata']['deviceHash'] != sec.secret_hash(data.device.deviceId or ''):
        return failure(401,'TRANSACTION_INVALID')
    row=tx.verify(db,row,data.code)
    if isinstance(row,AuthFailure):
        return row
    if not eligible(user,row['target']):
        return failure(400,'OTP_INVALID')
    reasons=assess(db,user,data.device)
    meta={**row['metadata'],'requiresExtra':bool(reasons),'reasons':reasons,'riskVersion':'1',
          'requestedAt':row['created_at'].isoformat()}
    row=db.execute('UPDATE account.auth_transactions SET metadata=%s WHERE id=%s RETURNING *',
                   (Jsonb(meta),row['id'])).fetchone()
    return {**tx.ticket(row,data.transactionToken),'requiresAdditionalVerification':bool(reasons) and not meta.get('extraVerified',False),
            'verificationOptions':verification_options(db,user,row) if reasons else [],
            **({'message':SUPPORT} if reasons else {})}


def email_start(db,data,ip):
    pair=locked(db,data)
    if isinstance(pair,AuthFailure):
        return pair
    user,parent=pair
    if not user or not root_ticket(parent) or not parent['verified_at'] or not parent['metadata'].get('requiresExtra'):
        return failure(401,'TRANSACTION_INVALID')
    # Independent email only for a phone recovery, verified before request and
    # outside the recent security-change window.
    if ('@' in parent['target'] or not user['email_verified_at'] or
            user['email_verified_at'] >= parent['created_at'] or
            sec.now()-user['email_verified_at'] < timedelta(hours=settings.auth_recovery_security_hours)):
        return failure(403,'RECOVERY_SUPPORT_REQUIRED',details={'message':SUPPORT})
    row,token=tx.create(db,'password_reset',user_id=user['id'],target=str(user['email']),channel='email',
                      metadata={'parent':str(parent['id'])},minutes=5)
    return tx.send(db,row,token,ip)


def email_verify(db,data):
    pair=locked(db,data,allow_consumed=True)
    if isinstance(pair,AuthFailure):
        return pair
    user,row=pair
    parent_id=row['metadata'].get('parent')
    if not parent_id or not user:
        return failure(401,'TRANSACTION_INVALID')
    parent=db.execute('SELECT * FROM account.auth_transactions WHERE id=%s FOR UPDATE',(parent_id,)).fetchone()
    if (not parent or not root_ticket(parent) or parent['consumed_at'] or parent['invalidated_at'] or parent['expires_at']<=sec.now()
            or not parent['verified_at'] or parent['user_id']!=user['id']):
        return failure(401,'TRANSACTION_INVALID')
    row=tx.verify(db,row,data.code)
    if isinstance(row,AuthFailure):
        return row
    tx.consume(db,row)
    db.execute("UPDATE account.auth_transactions SET metadata=metadata || %s WHERE id=%s",
               (Jsonb({'extraVerified':True}),parent_id))
    return {'verified':True}


def provider(db,data):
    pair=locked(db,data)
    if isinstance(pair,AuthFailure):
        return pair
    user,row=pair
    if not user or not root_ticket(row) or not row['verified_at'] or not row['metadata'].get('requiresExtra'):
        return failure(401,'TRANSACTION_INVALID')
    if row['metadata'].get('extraVerified'):
        return {'verified':True}
    claims=social.verify_identity(data)
    if isinstance(claims,AuthFailure):
        return claims
    if not fresh_provider(claims):
        return failure(401,'SOCIAL_REAUTH_REQUIRED')
    link=db.execute('SELECT * FROM account.social_identities WHERE provider=%s AND subject=%s AND user_id=%s',
                    (data.provider,claims['sub'],user['id'])).fetchone()
    if not link or link['created_at'] >= row['created_at'] or sec.now()-link['created_at'] < timedelta(hours=settings.auth_recovery_security_hours):
        return failure(401,'SOCIAL_TOKEN_INVALID')
    from app.features.auth.flows import consume_apple_challenge
    error=consume_apple_challenge(db,data)
    if error:
        return error
    db.execute('UPDATE account.auth_transactions SET metadata=metadata || %s WHERE id=%s',
               (Jsonb({'extraVerified':True}),row['id']))
    return {'verified':True}


def complete(db,data):
    pair=locked(db,data,allow_consumed=True)
    if isinstance(pair,AuthFailure):
        return pair
    user,row=pair
    if not root_ticket(row):
        return failure(401,'TRANSACTION_INVALID')
    if row['consumed_at']:
        return tx.replay_result(db,row,data,reset=True)
    if not eligible(user,row['target']) or not row['verified_at']:
        return failure(401,'TRANSACTION_INVALID')
    # Re-evaluate cumulative failures/security changes at commit. Device ID is
    # pinned at start, so a modified client cannot lower the risk here.
    known=tx.known_devices(user)
    failures=recent_failures(db,user['id'])
    reasons=risk_reasons(new_device=row['metadata']['deviceHash'] not in known,
        last_activity=user['last_login_at'],security_changed=security_changed_at(db,user),failures=failures,now=sec.now())
    if (row['metadata'].get('requiresExtra') or reasons) and not row['metadata'].get('extraVerified'):
        return failure(403,'RECOVERY_ADDITIONAL_VERIFICATION_REQUIRED',details={'message':SUPPORT,'verificationOptions':verification_options(db,user,row)})
    db.execute('UPDATE account.users SET password_hash=%s,password_changed_at=%s WHERE id=%s',
               (sec.password_hasher.hash(data.newPassword),sec.now(),user['id']))
    tx.mark_completed(db,row,data,user['id'])
    changed(db,user['id'],row['id'])
    revoke_all(db,user['id'])
    from app.features.auth.notices import enqueue
    enqueue(db,user,'password_reset')
    return {'reset':True}
