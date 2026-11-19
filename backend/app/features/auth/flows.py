"""OTP-first registration and provider completion; legacy routes stay separate."""
import hmac
from datetime import timedelta
import psycopg
from psycopg.types.json import Jsonb
from app.core import security as sec
from app.features.auth import transactions as tx, social, validation
from app.features.auth.errors import AuthFailure, failure


def lock(db, key):
    db.execute('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', (key,))


def checked_documents(data):
    docs = tx.documents()
    if isinstance(docs,AuthFailure):
        return docs
    snapshot,digest = docs
    if not data.acceptedTerms:
        return failure(422,'LEGAL_CONSENT_REQUIRED')
    if not hmac.compare_digest(data.documentsDigest,digest):
        return failure(409,'LEGAL_DOCUMENTS_CHANGED')
    return snapshot


def receipt(db, user, row, documents):
    db.execute('INSERT INTO account.auth_consent_receipts(user_id,transaction_id,documents) VALUES (%s,%s,%s)',
               (user['id'],row['id'],Jsonb(documents)))


def signup_start(db, data, ip):
    documents = tx.documents()
    if isinstance(documents,AuthFailure):
        return documents
    error = tx.quota('signup-start-ip:'+ip,20,3600)
    if error:
        return error
    # No lookup of account presence until ownership of the number is verified.
    lock(db,'v2-signup:'+data.phone)
    row,token = tx.create(db,'phone_signup',target=data.phone,channel='sms',metadata={
        'documentsDigest':documents[1],'deviceHash':sec.secret_hash(data.device.deviceId or '')})
    result = tx.send(db,row,token,ip)
    if not isinstance(result,AuthFailure):
        db.execute('''UPDATE account.auth_transactions SET invalidated_at=%s
          WHERE purpose='phone_signup' AND target=%s AND id<>%s
          AND consumed_at IS NULL AND invalidated_at IS NULL''',(sec.now(),data.phone,row['id']))
    else:
        tx.consume(db,row)
    if not isinstance(result,AuthFailure):
        result['documentsDigest']=documents[1]
    return result


def signup_resend(db,data,ip):
    row = tx.load(db,data,'phone_signup',allow_expired=True)
    if isinstance(row,AuthFailure):
        return row
    if row['verified_at']:
        return failure(401,'TRANSACTION_INVALID')
    return tx.send(db,row,data.transactionToken,ip)


def signup_verify(db,data,ip):
    row = tx.load(db,data,'phone_signup')
    if isinstance(row,AuthFailure):
        return row
    error = tx.quota('signup-verify:'+sec.secret_hash(row['target']),20,3600)
    if error:
        return error
    row = tx.verify(db,row,data.code)
    if isinstance(row,AuthFailure):
        return row
    if db.execute('SELECT id FROM account.users WHERE phone=%s',(row['target'],)).fetchone():
        tx.consume(db,row)
        return failure(409,'ACCOUNT_CONFLICT')
    return {**tx.ticket(row,data.transactionToken),'documentsDigest':row['metadata']['documentsDigest']}


def signup_complete(db,data,ip):
    from app.features.auth.service import new_session,public_user
    # Identity advisory lock before row locks serializes complete with start.
    candidate = db.execute('SELECT target FROM account.auth_transactions WHERE id=%s',(data.transactionId,)).fetchone()
    if candidate:
        lock(db,'v2-signup:'+candidate['target'])
    row = tx.load(db,data,'phone_signup',allow_consumed=True)
    if isinstance(row,AuthFailure):
        return row
    if row['consumed_at']:
        return tx.replay_result(db,row,data)
    if not row['verified_at']:
        return failure(401,'TRANSACTION_INVALID')
    if row['metadata']['deviceHash'] != sec.secret_hash(data.device.deviceId or ''):
        return failure(401,'TRANSACTION_INVALID')
    documents = checked_documents(data)
    if isinstance(documents,AuthFailure):
        return documents
    if db.execute('SELECT id FROM account.users WHERE phone=%s',(row['target'],)).fetchone():
        return failure(409,'ACCOUNT_CONFLICT')
    try:
        with db.transaction():
            user = db.execute('''INSERT INTO account.users
              (phone,password_hash,display_name,default_relationship,status,consented_at,phone_verified_at)
              VALUES (%s,%s,%s,%s,'active',%s,%s) RETURNING *''',
              (row['target'],sec.password_hasher.hash(data.password),data.displayName,
               data.defaultRelationship,sec.now(),sec.now())).fetchone()
            receipt(db,user,row,documents)
            tx.mark_completed(db,row,data,user['id'])
            result = new_session(db,user,data.device,data.rememberMe,ip)
            return {**result,'user':public_user(user),'isNewUser':True}
    except psycopg.errors.UniqueViolation:
        return failure(409,'ACCOUNT_CONFLICT')


def consume_apple_challenge(db,data):
    if data.provider != 'apple':
        return None
    used = db.execute('''INSERT INTO account.social_challenge_uses(token_hash,expires_at)
       VALUES (%s,%s) ON CONFLICT DO NOTHING RETURNING token_hash''',
       (sec.secret_hash(data.challenge),sec.now()+timedelta(minutes=10))).fetchone()
    return None if used else failure(401,'SOCIAL_TOKEN_INVALID')


def trusted_email(provider,claims):
    if claims.get('email_verified') not in (True,'true'):
        return False
    if provider == 'apple':
        return True
    address = str(claims.get('email','')).lower()
    return address.endswith('@gmail.com') or bool(claims.get('hd'))


def social_start(db,data,ip):
    from app.features.auth.service import new_session,public_user
    error = tx.quota('social-ip:'+ip,30,60)
    if error:
        return error
    claims = social.verify_identity(data)
    if isinstance(claims,AuthFailure):
        return claims
    lock(db,'social:'+data.provider+':'+claims['sub'])
    error = consume_apple_challenge(db,data)
    if error:
        return error
    user = db.execute('''SELECT u.* FROM account.users u JOIN account.social_identities i ON i.user_id=u.id
       WHERE i.provider=%s AND i.subject=%s FOR UPDATE OF u''',(data.provider,claims['sub'])).fetchone()
    if user:
        if user['status'] != 'active':
            return failure(403,'ACCOUNT_UNAVAILABLE')
        return {**new_session(db,user,data.device,data.rememberMe,ip),'user':public_user(user),'isNewUser':False}
    try:
        email = validation.email(claims.get('email',''))
    except (ValueError,AttributeError):
        return failure(403,'SOCIAL_EMAIL_NOT_VERIFIED')
    if claims.get('email_verified') not in (True,'true'):
        return failure(403,'SOCIAL_EMAIL_NOT_VERIFIED')
    if db.execute('SELECT id FROM account.users WHERE email=%s',(email,)).fetchone():
        return failure(409,'SOCIAL_ACCOUNT_CONFLICT')
    row,token = tx.create(db,'social_signup',target=email,metadata={
        'provider':data.provider,'subject':claims['sub'],'trustedEmail':trusted_email(data.provider,claims),
        'deviceHash':sec.secret_hash(data.device.deviceId or ''),
    })
    docs = tx.documents()
    if isinstance(docs,AuthFailure):
        return docs
    return {**tx.ticket(row,token),'requiresProfile':True,
            'displayName':str(claims.get('name') or data.displayName or ''),
            'documentsDigest':docs[1]}


def social_complete(db,data,ip):
    from app.features.auth.service import new_session,public_user
    row = tx.load(db,data,'social_signup',allow_consumed=True)
    if isinstance(row,AuthFailure):
        return row
    if row['consumed_at']:
        return tx.replay_result(db,row,data)
    meta = row['metadata']
    if meta['deviceHash'] != sec.secret_hash(data.device.deviceId or ''):
        return failure(401,'TRANSACTION_INVALID')
    documents = checked_documents(data)
    if isinstance(documents,AuthFailure):
        return documents
    lock(db,'social:'+meta['provider']+':'+meta['subject'])
    lock(db,'registration:'+row['target'])
    if db.execute('SELECT id FROM account.users WHERE email=%s',(row['target'],)).fetchone():
        return failure(409,'SOCIAL_ACCOUNT_CONFLICT')
    try:
        with db.transaction():
            user = db.execute('''INSERT INTO account.users
               (email,password_hash,display_name,default_relationship,status,consented_at,email_verified_at)
               VALUES (%s,'!social',%s,%s,'active',%s,%s) RETURNING *''',
               (row['target'],data.displayName,data.defaultRelationship,sec.now(),sec.now() if meta['trustedEmail'] else None)).fetchone()
            db.execute('INSERT INTO account.social_identities(provider,subject,user_id) VALUES (%s,%s,%s)',
                       (meta['provider'],meta['subject'],user['id']))
            receipt(db,user,row,documents)
            tx.mark_completed(db,row,data,user['id'])
            return {**new_session(db,user,data.device,data.rememberMe,ip),'user':public_user(user),'isNewUser':True}
    except psycopg.errors.UniqueViolation:
        return failure(409,'SOCIAL_ACCOUNT_CONFLICT')
