"""Explicit provider changes, account deletion and signed Apple events."""
import json
import math
from datetime import timedelta
import jwt
import psycopg
from psycopg.types.json import Jsonb
from app.core import security as sec
from app.core.config import settings
from app.features.auth import transactions as tx,social,account_security as security
from app.features.auth.errors import AuthFailure,failure
from app.features.auth.notices import enqueue

def proof(db,user,data,provider):
    if not data or data.provider!=provider:
        return failure(401,'SOCIAL_REAUTH_REQUIRED')
    claims=social.verify_identity(data)
    if isinstance(claims,AuthFailure):
        return claims
    if not security.fresh_provider(claims):
        return failure(401,'SOCIAL_REAUTH_REQUIRED')
    from app.features.auth.flows import consume_apple_challenge
    error=consume_apple_challenge(db,data)
    return error or claims

def link(db,request,data):
    provider=data.credential.provider
    pair=security.grant(db,request,data,'link_'+provider)
    if isinstance(pair,AuthFailure):return pair
    user,sid,row=pair
    claims=proof(db,user,data.credential,provider)
    if isinstance(claims,AuthFailure):return claims
    try:
        with db.transaction():
            existing=db.execute('SELECT subject FROM account.social_identities WHERE user_id=%s AND provider=%s',(user['id'],provider)).fetchone()
            if existing:
                return failure(409,'PROVIDER_ALREADY_LINKED')
            db.execute('INSERT INTO account.social_identities(provider,subject,user_id) VALUES (%s,%s,%s)',(provider,claims['sub'],user['id']))
    except psycopg.errors.UniqueViolation:
        return failure(409,'SOCIAL_ACCOUNT_CONFLICT')
    tx.consume(db,row);security.changed(db,user['id'],row['id']);enqueue(db,user,'provider_changed')
    return {'linked':True}

def unlink(db,request,data):
    pair=security.grant(db,request,data,'unlink_'+data.provider)
    if isinstance(pair,AuthFailure):return pair
    user,sid,row=pair
    links=db.execute('SELECT * FROM account.social_identities WHERE user_id=%s',(user['id'],)).fetchall()
    linked=next((v for v in links if v['provider']==data.provider),None)
    if not linked:return failure(409,'PROVIDER_NOT_LINKED')
    usable_password=not user['password_hash'].startswith('!') and bool(user['email_verified_at'] or user['phone_verified_at'])
    if not usable_password and len(links)<=1:return failure(409,'LAST_LOGIN_METHOD')
    if data.provider=='apple':
        claims=proof(db,user,data.credential,'apple')
        if isinstance(claims,AuthFailure):return claims
        if claims['sub']!=linked['subject']:return failure(401,'SOCIAL_TOKEN_INVALID')
        error=social.revoke_apple(claims)
        if error:return error
    db.execute('DELETE FROM account.social_identities WHERE user_id=%s AND provider=%s',(user['id'],data.provider))
    tx.consume(db,row);security.changed(db,user['id'],row['id']);enqueue(db,user,'provider_changed')
    db.execute('UPDATE account.user_sessions SET revoked_at=%s WHERE user_id=%s AND id<>%s',(sec.now(),user['id'],sid))
    return {'unlinked':True}

def delete(db,request,data):
    # Serialize ownership creation/transfers with the final ownership check.
    db.execute('LOCK TABLE child.children IN SHARE ROW EXCLUSIVE MODE NOWAIT')
    pair=security.grant(db,request,data,'delete_account')
    if isinstance(pair,AuthFailure):return pair
    user,sid,row=pair
    if db.execute('SELECT id FROM child.children WHERE owner_user_id=%s AND deleted_at IS NULL LIMIT 1',(user['id'],)).fetchone():
        return failure(409,'CHILD_OWNERSHIP_REQUIRED')
    apple=db.execute("SELECT subject FROM account.social_identities WHERE user_id=%s AND provider='apple'",(user['id'],)).fetchone()
    if apple:
        claims=proof(db,user,data.appleCredential,'apple')
        if isinstance(claims,AuthFailure):return claims
        if claims['sub']!=apple['subject']:return failure(401,'SOCIAL_TOKEN_INVALID')
        error=social.revoke_apple(claims)
        if error:return error
    # Existing database function enforces ownership again and anonymizes user data.
    db.execute('SELECT account.anonymize_user(%s)',(user['id'],))
    db.execute('DELETE FROM account.social_identities WHERE user_id=%s',(user['id'],))
    db.execute('DELETE FROM account.auth_transactions WHERE user_id=%s',(user['id'],))
    db.execute("UPDATE account.users SET auth_known_devices='[]'::jsonb,deleted_at=%s WHERE id=%s",(sec.now(),user['id']))
    return {'deleted':True}

def apple_event(db,data):
    from app.features.auth import simulation
    simulated=simulation.enabled()
    if not settings.apple_client_ids and not simulated:return failure(503,'SOCIAL_AUTH_NOT_CONFIGURED')
    try:
        if simulated:
            claims=simulation.decode(data.payload,'simulation-apple-event')
        else:
            key=social.keys('apple').get_signing_key_from_jwt(data.payload)
            claims=jwt.decode(data.payload,key.key,algorithms=['RS256'],issuer='https://appleid.apple.com',
                audience=settings.apple_client_ids,options={'require':['iss','aud','iat','jti','events']},leeway=30)
        event=claims['events']
        if isinstance(event,str):event=json.loads(event)
        if (not isinstance(claims['jti'],str) or not 1<=len(claims['jti'])<=255
                or not isinstance(event,dict) or not isinstance(event.get('sub'),str)
                or not 1<=len(event['sub'])<=255 or not isinstance(event.get('event_time'),(int,float))):
            raise ValueError()
        if (not isinstance(claims['iat'],(int,float)) or not math.isfinite(claims['iat'])
            or claims['iat']<sec.now().timestamp()-7*86400
            or not math.isfinite(event['event_time']) or event['event_time']>sec.now().timestamp()+30
            or event['event_time']<sec.now().timestamp()-7*86400):
            raise ValueError()
    except jwt.PyJWKClientConnectionError:return failure(503,'SOCIAL_PROVIDER_UNAVAILABLE')
    except (jwt.PyJWTError,ValueError,TypeError,KeyError):return failure(401,'SOCIAL_TOKEN_INVALID')
    if event.get('type') not in ('consent-revoked','account-deleted','email-enabled','email-disabled'):
        return {'received':True}
    user=db.execute("""SELECT u.* FROM account.users u JOIN account.social_identities i ON i.user_id=u.id
        WHERE i.provider='apple' AND i.subject=%s FOR UPDATE OF u""",(event['sub'],)).fetchone()
    if not user:return {'received':True}
    digest=sec.secret_hash('apple-event:'+claims['jti'])
    if db.execute('SELECT 1 FROM account.auth_transactions WHERE secret_hash=%s',(digest,)).fetchone():
        return {'received':True}
    previous=db.execute("SELECT metadata FROM account.auth_transactions WHERE user_id=%s AND metadata ? 'appleEvent' ORDER BY (metadata->>'eventTime')::numeric DESC LIMIT 1",(user['id'],)).fetchone()
    row,_=tx.create(db,'reauth',user_id=user['id'],minutes=8*1440,metadata={'appleEvent':event['type'],
        'eventTime':event['event_time'],'relayHash':sec.secret_hash(str(event.get('email','')).lower())})
    db.execute('UPDATE account.auth_transactions SET secret_hash=%s,consumed_at=%s WHERE id=%s',(digest,sec.now(),row['id']))
    if (event['type'] in ('email-enabled','email-disabled') and
        (not previous or previous['metadata']['eventTime']<=event['event_time']) and
        str(user['email']).lower()==str(event.get('email','')).lower() and
        str(user['email']).endswith('@privaterelay.appleid.com')):
        db.execute('UPDATE account.users SET email_verified_at=%s WHERE id=%s',
                   (sec.now() if event['type']=='email-enabled' else None,user['id']))
    if event['type'] in ('consent-revoked','account-deleted'):
        from datetime import datetime,timezone
        cutoff=datetime.fromtimestamp(event['event_time'],timezone.utc)
        if cutoff>sec.now()+timedelta(seconds=30):return failure(401,'SOCIAL_TOKEN_INVALID')
        db.execute('UPDATE account.user_sessions SET revoked_at=COALESCE(revoked_at,%s) WHERE user_id=%s AND created_at<=%s',(sec.now(),user['id'],cutoff))
        db.execute('UPDATE account.device_tokens SET is_active=false WHERE user_id=%s AND session_id IN (SELECT id FROM account.user_sessions WHERE user_id=%s AND revoked_at IS NOT NULL)',(user['id'],user['id']))
        db.execute('UPDATE account.auth_transactions SET invalidated_at=%s WHERE user_id=%s AND consumed_at IS NULL AND created_at<=%s',(sec.now(),user['id'],cutoff))
    # Provider deletion is not permission to destroy child records or the app account.
    return {'received':True}
