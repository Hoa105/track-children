"""Opt-in local test providers/outbox. Never accepts real provider credentials."""
from datetime import timedelta
from pathlib import Path
from typing import Literal
import json
import secrets
import threading
import jwt
from fastapi import APIRouter,Depends,HTTPException,Response
from fastapi.responses import HTMLResponse
from pydantic import BaseModel,Field
from psycopg.conninfo import conninfo_to_dict
from app.core.config import settings
from app.core import security as sec
from app.features.auth.errors import failure

_lock=threading.Lock()
_messages=[]

def enabled():
    return (settings.auth_simulation and settings.app_env=='local' and
        conninfo_to_dict(settings.database_url).get('dbname','').endswith('_test'))

def require():
    if not enabled():raise HTTPException(status_code=404)

def record(kind,**data):
    require()
    with _lock:
        _messages.append({'kind':kind,'at':sec.now().isoformat(),**data})
        _messages[:]=_messages[-100:]

def token(claims,audience):
    return jwt.encode({**claims,'iss':'belonkhon-local-simulation','aud':audience,
        'iat':sec.now(),'exp':sec.now()+timedelta(minutes=5)},settings.auth_secret,algorithm='HS256')

def decode(raw,audience):
    require()
    return jwt.decode(raw,settings.auth_secret,algorithms=['HS256'],issuer='belonkhon-local-simulation',
        audience=audience,options={'require':['iss','aud','iat','exp']})

def verify(data):
    try:
        claims=decode(data.idToken,'simulation-'+data.provider)
        if data.provider=='apple':
            challenge=jwt.decode(data.challenge or '',settings.auth_secret,algorithms=['HS256'],
                audience='track-children-apple-challenge',issuer=settings.auth_issuer)
            if claims.get('nonce')!=challenge['nonce'] or sec.secret_hash(data.authorizationCode or '')!=claims['codeHash']:
                raise ValueError()
        return claims
    except (jwt.PyJWTError,ValueError,KeyError,TypeError):return failure(401,'SOCIAL_TOKEN_INVALID')

def no_store(response:Response):
    response.headers['Cache-Control']='no-store'

router=APIRouter(prefix='/api/v1/auth/testing',dependencies=[Depends(require),Depends(no_store)],include_in_schema=False)

class Provider(BaseModel):
    provider:Literal['google','apple']
    account:str=Field(default='parent01',pattern=r'^[a-z0-9_-]{1,30}$')
    nonce:str|None=None

@router.post('/provider')
def provider(data:Provider):
    code=secrets.token_urlsafe(32)
    claims={'sub':f'simulation:{data.provider}:{data.account}','email':f'{data.provider}.{data.account}@example.com',
        'email_verified':True,'hd':'example.com','name':'Phụ huynh giả lập','nonce':data.nonce,'codeHash':sec.secret_hash(code)}
    return {'idToken':token(claims,'simulation-'+data.provider),'authorizationCode':code,
            'displayName':claims['name'],'email':claims['email']}

@router.get('/outbox')
def outbox():
    from app.features.auth import notices,recovery
    recovery.process_pending(limit=5)
    notices.process_pending(limit=5)
    with _lock:
        cutoff=(sec.now()-timedelta(minutes=15)).isoformat()
        _messages[:]=[m for m in _messages if m['at']>cutoff]
        return {'simulation':True,'messages':list(reversed(_messages))}

class Scenario(BaseModel):
    identifier:str=Field(min_length=1,max_length=254)
    scenario:Literal['normal','additional','apple-revoked','delivery-fails']

_delivery_fails=False
def delivery_fails():return enabled() and _delivery_fails

@router.post('/scenario')
def scenario(data:Scenario):
    global _delivery_fails
    from app.core.database import transaction
    from app.features.auth import provider_security
    from app.features.auth.presenters import output
    _delivery_fails=data.scenario=='delivery-fails'
    with transaction() as db:
        user=db.execute('SELECT * FROM account.users WHERE email=%s OR phone=%s FOR UPDATE',(data.identifier,data.identifier)).fetchone()
        if not user:return {'applied':False,'message':'Chưa có tài khoản test này.'}
        if data.scenario=='apple-revoked':
            identity=db.execute("SELECT subject FROM account.social_identities WHERE user_id=%s AND provider='apple'",(user['id'],)).fetchone()
            if not identity:return {'applied':False,'message':'Chưa liên kết Apple giả lập.'}
            event=token({'jti':secrets.token_urlsafe(32),'events':{'type':'consent-revoked','sub':identity['subject'],
                'event_time':sec.now().timestamp()}},'simulation-apple-event')
            return output(provider_security.apple_event(db,type('Event',(),{'payload':event})()))
        db.execute("UPDATE account.users SET password_changed_at=%s WHERE id=%s",
            (sec.now() if data.scenario=='additional' else sec.now()-timedelta(days=2),user['id']))
        if data.scenario=='normal':
            db.execute("UPDATE account.auth_transactions SET metadata=metadata-'failureTimes' WHERE user_id=%s AND purpose='password_reset'",(user['id'],))
        if data.scenario=='additional':
            db.execute("UPDATE account.users SET auth_known_devices='[]'::jsonb WHERE id=%s",(user['id'],))
        # Age existing trusted proofs to exercise the extra-verification branch.
        db.execute('UPDATE account.social_identities SET created_at=%s WHERE user_id=%s',(sec.now()-timedelta(days=2),user['id']))
        db.execute('UPDATE account.users SET email_verified_at=%s WHERE id=%s AND email_verified_at IS NOT NULL',(sec.now()-timedelta(days=2),user['id']))
    return {'applied':True,'message':'Đã cập nhật dữ liệu test. Đăng xuất rồi thử khôi phục.'}

@router.get('',response_class=HTMLResponse)
def dashboard():
    return '''<!doctype html><html lang="vi"><meta charset="utf-8"><title>Auth local simulation</title>
    <style>body{font:16px system-ui;max-width:900px;margin:30px auto;padding:20px}input,button,select{font:inherit;padding:10px;margin:5px}pre{white-space:pre-wrap;background:#eef5ef;padding:20px}</style>
    <h1>Auth giả lập — chỉ dữ liệu test</h1><p>OTP và cảnh báo bên dưới không được gửi SMS/email thật. Làm mới mỗi 2 giây.</p>
    <input id="account" placeholder="Email hoặc SĐT E.164 của tài khoản test"><select id="mode"><option value="normal">Bình thường</option><option value="additional">Yêu cầu xác minh bổ sung</option><option value="apple-revoked">Apple thu hồi quyền</option><option value="delivery-fails">Giả lập lỗi gửi OTP</option></select><button id="apply">Áp dụng kịch bản</button>
    <p id="result"></p><pre id="out">Đang tải…</pre><script>
    const base='/api/v1/auth/testing';async function refresh(){try{document.getElementById('out').textContent=JSON.stringify(await(await fetch(base+'/outbox')).json(),null,2)}catch{document.getElementById('out').textContent='Không kết nối được backend'}}
    document.getElementById('apply').onclick=async()=>{const r=await fetch(base+'/scenario',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({identifier:document.getElementById('account').value,scenario:document.getElementById('mode').value})});document.getElementById('result').textContent=JSON.stringify(await r.json())};refresh();setInterval(refresh,2000);
    </script></html>'''
