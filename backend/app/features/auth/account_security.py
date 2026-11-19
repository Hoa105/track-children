"""Password/reauth changes; always lock user before session/transaction rows."""
from datetime import timedelta
import secrets
import psycopg
from psycopg.types.json import Jsonb
from app.core import security as sec
from app.features.auth import transactions as tx, social
from app.features.auth.dependencies import token_identity, current_user
from app.core.config import settings
from app.features.auth.errors import AuthFailure, failure
from app.features.auth.notices import enqueue


def fresh_provider(claims):
    issued=claims.get('iat')
    return isinstance(issued,(int,float)) and 0 <= sec.now().timestamp()-issued <= 600


def lock_user(db,request):
    identity = token_identity(request,settings.auth_audience)
    if isinstance(identity,AuthFailure):
        return identity
    user = db.execute('SELECT * FROM account.users WHERE id=%s FOR UPDATE',(identity[0],)).fetchone()
    checked = current_user(request,db,identity=identity)
    return checked if isinstance(checked,AuthFailure) else (user,identity[1])


def revoke_all(db,user_id):
    db.execute('UPDATE account.user_sessions SET revoked_at=COALESCE(revoked_at,%s) WHERE user_id=%s',(sec.now(),user_id))
    db.execute('UPDATE account.device_tokens SET is_active=false WHERE user_id=%s',(user_id,))


def changed(db,user_id,except_tx=None):
    tx.invalidate_other(db,user_id,except_tx)


def change_password(db,request,data):
    from app.features.auth.service import new_session,public_user
    pair = lock_user(db,request)
    if isinstance(pair,AuthFailure):
        return pair
    user,sid = pair
    if not (user['email_verified_at'] or user['phone_verified_at']):
        return failure(403,'VERIFIED_IDENTIFIER_REQUIRED')
    error = tx.quota('reauth:'+str(user['id']),10,900)
    if error:
        return error
    if not sec.verify_password(data.currentPassword,user['password_hash']):
        return failure(401,'CURRENT_PASSWORD_INVALID')
    if sec.verify_password(data.newPassword,user['password_hash']):
        return failure(422,'PASSWORD_UNCHANGED')
    session = db.execute('SELECT * FROM account.user_sessions WHERE id=%s FOR UPDATE',(sid,)).fetchone()
    previous=user.copy()
    user = db.execute('UPDATE account.users SET password_hash=%s,password_changed_at=%s WHERE id=%s RETURNING *',
                      (sec.password_hasher.hash(data.newPassword),sec.now(),user['id'])).fetchone()
    revoke_all(db,user['id'])
    changed(db,user['id'])
    enqueue(db,previous,'password_changed')
    result = new_session(db,user,data.device,session['remember_me'])
    return {**result,'user':public_user(user)}


def reauth(db,request,data,ip):
    pair = lock_user(db,request)
    if isinstance(pair,AuthFailure):
        return pair
    user,sid = pair
    if data.action not in ('change_email','change_phone','set_password') and not (user['email_verified_at'] or user['phone_verified_at']):
        return failure(403,'VERIFIED_IDENTIFIER_REQUIRED')
    error = tx.quota('reauth:'+str(user['id']),10,900) or tx.quota('reauth-ip:'+ip,30,900)
    if error:
        return error
    if data.currentPassword is not None:
        if not sec.verify_password(data.currentPassword,user['password_hash']):
            return failure(401,'CURRENT_PASSWORD_INVALID')
        method = 'password'
    else:
        claims = social.verify_identity(data.providerCredential)
        if isinstance(claims,AuthFailure):
            return claims
        if not fresh_provider(claims):
            return failure(401,'SOCIAL_REAUTH_REQUIRED')
        provider = data.providerCredential.provider
        linked = db.execute('SELECT user_id FROM account.social_identities WHERE provider=%s AND subject=%s',
                            (provider,claims['sub'])).fetchone()
        if not linked or linked['user_id'] != user['id']:
            return failure(401,'SOCIAL_TOKEN_INVALID')
        from app.features.auth.flows import consume_apple_challenge
        error = consume_apple_challenge(db,data.providerCredential)
        if error:
            return error
        method = provider
    row,token = tx.create(db,'reauth',user_id=user['id'],session_id=sid,target=data.target,
                          metadata={'action':data.action,'method':method})
    return tx.ticket(row,token)


def grant(db,request,data,action):
    pair = lock_user(db,request)
    if isinstance(pair,AuthFailure):
        return pair
    user,sid = pair
    row = tx.load(db,data,'reauth')
    if isinstance(row,AuthFailure):
        return row
    if row['user_id'] != user['id'] or row['session_id'] != sid or row['metadata'].get('action') != action:
        return failure(401,'TRANSACTION_INVALID')
    return user,sid,row


def setup_password(db,request,data):
    from app.features.auth.service import public_user,new_session
    pair = grant(db,request,data,'set_password')
    if isinstance(pair,AuthFailure):
        return pair
    user,sid,row = pair
    if not str(user['password_hash']).startswith('!social') or row['metadata'].get('method') not in ('google','apple'):
        return failure(409,'PASSWORD_SETUP_NOT_ALLOWED')
    if not (user['email_verified_at'] or user['phone_verified_at']):
        return failure(403,'VERIFIED_IDENTIFIER_REQUIRED')
    session = db.execute('SELECT * FROM account.user_sessions WHERE id=%s',(sid,)).fetchone()
    user = db.execute('UPDATE account.users SET password_hash=%s,password_changed_at=%s WHERE id=%s RETURNING *',
                      (sec.password_hasher.hash(data.newPassword),sec.now(),user['id'])).fetchone()
    tx.consume(db,row)
    db.execute('UPDATE account.auth_transactions SET metadata=metadata || %s WHERE id=%s',
               (Jsonb({'applied':True}),row['id']))
    changed(db,user['id'],row['id'])
    revoke_all(db,user['id'])
    enqueue(db,user,'password_changed')
    return {**new_session(db,user,data.device,session['remember_me']),'user':public_user(user)}


def identifier_start(db,request,data,action,ip):
    pair = grant(db,request,data,action)
    if isinstance(pair,AuthFailure):
        return pair
    user,sid,proof = pair
    row,token = tx.create(db,action,user_id=user['id'],session_id=sid,target=proof['target'],
                          channel='email' if action=='change_email' else 'sms')
    result = tx.send(db,row,token,ip)
    if isinstance(result,AuthFailure):
        tx.consume(db,row)
        return result
    tx.consume(db,proof)
    return result


def identifier_commit(db,request,data,action):
    from app.features.auth.service import public_user,token_result
    pair = lock_user(db,request)
    if isinstance(pair,AuthFailure):
        return pair
    user,sid = pair
    row = tx.load(db,data,action)
    if isinstance(row,AuthFailure):
        return row
    if row['user_id'] != user['id'] or row['session_id'] != sid:
        return failure(401,'TRANSACTION_INVALID')
    row = tx.verify(db,row,data.code)
    if isinstance(row,AuthFailure):
        return row
    field = 'email' if action=='change_email' else 'phone'
    previous=user.copy()
    # Server-selected identifier, never an interpolated request field.
    try:
        with db.transaction():
            user = db.execute(f'UPDATE account.users SET {field}=%s,{field}_verified_at=%s WHERE id=%s RETURNING *',
                              (row['target'],sec.now(),user['id'])).fetchone()
    except psycopg.errors.UniqueViolation:
        tx.consume(db,row)
        return failure(409,'ACCOUNT_CONFLICT')
    tx.consume(db,row)
    db.execute('UPDATE account.auth_transactions SET metadata=metadata || %s WHERE id=%s',
               (Jsonb({'applied':True}),row['id']))
    changed(db,user['id'],row['id'])
    enqueue(db,previous,'identifier_changed')
    db.execute('UPDATE account.user_sessions SET revoked_at=COALESCE(revoked_at,%s) WHERE user_id=%s AND id<>%s',
               (sec.now(),user['id'],sid))
    raw = secrets.token_urlsafe(48)
    session = db.execute('UPDATE account.user_sessions SET refresh_token_hash=%s WHERE id=%s RETURNING *',
                         (sec.secret_hash(raw),sid)).fetchone()
    return {**token_result(session,raw),'user':public_user(user)}


def identifier_resend(db,request,data,action,ip):
    pair=lock_user(db,request)
    if isinstance(pair,AuthFailure):
        return pair
    user,sid=pair
    row=tx.load(db,data,action,allow_expired=True)
    if isinstance(row,AuthFailure):
        return row
    if row['user_id']!=user['id'] or row['session_id']!=sid or row['verified_at']:
        return failure(401,'TRANSACTION_INVALID')
    return tx.send(db,row,data.transactionToken,ip)
