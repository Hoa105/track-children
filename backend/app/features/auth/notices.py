"""Durable security messages in existing auth transactions; never contain secrets."""
from datetime import timedelta
import httpx
from psycopg.types.json import Jsonb
from app.core import security as sec
from app.core.config import settings
from app.features.auth import transactions as tx

MESSAGES = {
    'password_changed': 'Mật khẩu Bé Lớn Khôn đã thay đổi.',
    'password_reset': 'Mật khẩu Bé Lớn Khôn đã được khôi phục.',
    'identifier_changed': 'Email hoặc số điện thoại Bé Lớn Khôn đã thay đổi.',
    'provider_changed': 'Phương thức đăng nhập Bé Lớn Khôn đã thay đổi.',
}

def relay_disabled(db,user_id,target):
    if not target.endswith('@privaterelay.appleid.com'):return False
    user=db.execute('SELECT email,email_verified_at FROM account.users WHERE id=%s',(user_id,)).fetchone()
    if user and str(user['email']).lower()==target.lower() and not user['email_verified_at']:
        return True
    row=db.execute("""SELECT metadata FROM account.auth_transactions WHERE user_id=%s
        AND metadata->>'appleEvent' IN ('email-enabled','email-disabled')
        AND metadata->>'relayHash'=%s ORDER BY (metadata->>'eventTime')::numeric DESC LIMIT 1""",
        (user_id,sec.secret_hash(target.lower()))).fetchone()
    return bool(row and row['metadata']['appleEvent']=='email-disabled')

def enqueue(db,user,event):
    contacts=[{'channel':channel,'target':str(user[field])} for channel,field in [('email','email'),('sms','phone')]
              if user.get(field) and user.get(field+'_verified_at')
              and not (channel=='email' and relay_disabled(db,user['id'],str(user[field])))]
    if not contacts:
        return
    recent=db.execute("""SELECT count(*) AS n FROM account.auth_transactions WHERE user_id=%s
        AND metadata ? 'notice' AND created_at>%s""",(user['id'],sec.now()-timedelta(hours=1))).fetchone()['n']
    if recent>=5:
        return
    row,_=tx.create(db,'reauth',user_id=user['id'],minutes=1440,
        metadata={'notice':{'event':event,'contacts':contacts,'state':'pending','attempts':0,
                            'nextAttemptAt':sec.now().isoformat()}})
    tx.consume(db,row)

def process_pending(limit=50):
    from app.core.database import transaction
    from app.features.auth import simulation
    simulated=simulation.enabled()
    if not simulated and (not settings.auth_security_webhook_url.startswith('https://') or not settings.auth_security_webhook_token):
        return 0
    processed=0
    for _ in range(limit):
        with transaction() as db:
            row=db.execute("""SELECT * FROM account.auth_transactions
                WHERE metadata->'notice'->>'state'='pending' AND expires_at>%s
                AND (metadata->'notice'->>'nextAttemptAt')::timestamptz<=%s
                ORDER BY created_at FOR UPDATE SKIP LOCKED LIMIT 1""",(sec.now(),sec.now())).fetchone()
            if not row:
                break
            job=row['metadata']['notice'];attempts=job['attempts']+1
            recipients=[contact for contact in job['contacts'] if contact['channel']!='email'
                        or not relay_disabled(db,row['user_id'],contact['target'])]
            if not recipients:
                job={**job,'state':'cancelled'}
                db.execute("UPDATE account.auth_transactions SET metadata=jsonb_set(metadata,'{notice}',%s) WHERE id=%s",(Jsonb(job),row['id']))
                processed+=1
                continue
            try:
                if simulated:
                    simulation.record('security-notice',event=job['event'],recipients=recipients,message=MESSAGES[job['event']])
                    delivered=True
                else:
                    with httpx.Client(timeout=10,follow_redirects=False) as client:
                        result=client.post(settings.auth_security_webhook_url,headers={
                            'Authorization':'Bearer '+settings.auth_security_webhook_token,
                            'Idempotency-Key':str(row['id'])},json={
                            'eventId':str(row['id']),'event':job['event'],'recipients':recipients,
                            'message':MESSAGES[job['event']]+' Nếu không phải bạn, hãy liên hệ belonkhon@gmail.com.'})
                    delivered=200<=result.status_code<300
            except httpx.HTTPError:
                delivered=False
            job={**job,'state':'delivered' if delivered else 'failed' if attempts>=5 else 'pending',
                 'attempts':attempts,'nextAttemptAt':(sec.now()+timedelta(seconds=60*2**(attempts-1))).isoformat()}
            db.execute("UPDATE account.auth_transactions SET metadata=jsonb_set(metadata,'{notice}',%s) WHERE id=%s",(Jsonb(job),row['id']))
            processed+=1
    return processed
