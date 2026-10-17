from typing import Literal
from uuid import UUID

import jwt
from fastapi import APIRouter, Request, Depends
from fastapi.responses import JSONResponse, Response
from fastapi.encoders import jsonable_encoder

from app.core.config import settings
from app.core.database import transaction
from app.core import security as sec
from app.features.auth import schemas as m, service as s
from app.shared.access import require_user

router = APIRouter(prefix='/api/v1', tags=['Mobile Auth'])


def ready():
    if len(settings.auth_secret)<32:
        return s.failure(503,'AUTH_NOT_CONFIGURED')


def ip(request):
    from ipaddress import ip_address
    try:
        return str(ip_address(request.client.host)) if request.client else '127.0.0.1'
    except ValueError:
        return '127.0.0.1'


def output(result,status=200,sms=None):
    if sms and not s.send_sms(*sms):
        if isinstance(result,JSONResponse):
            import json
            body=json.loads(result.body)
            body['error']['details']['registration']['deliveryStatus']='failed'
            return JSONResponse(body,status_code=result.status_code,headers={k:v for k,v in result.headers.items() if k.lower()!='content-length'})
        result['deliveryStatus']='failed'
    if isinstance(result,Response):return result
    return JSONResponse(jsonable_encoder(result),status_code=status,headers={'Cache-Control':'no-store'})


@router.get('/legal-documents')
def documents(context: Literal['registration']):
    with transaction() as db:
        rows=s.legal(db)
    if isinstance(rows,Response):return rows
    return {'documents':[{'id':r['id'],'docType':r['doc_type'],'version':r['version'],
                          'content':r['content'],'isRequired':r['is_required'],'effectiveAt':r['effective_at']} for r in rows]}


@router.post('/auth/register',status_code=201)
def register(data:m.Register,request:Request):
    if err:=ready():return err
    with transaction() as db:result,sms=s.register(db,data,ip(request))
    return output(result,201,sms)


@router.post('/auth/register/verify')
def verify(data:m.Verify,request:Request):
    if err:=ready():return err
    with transaction() as db:result=s.verify(db,data,ip(request))
    return output(result)


@router.post('/auth/register/resend')
def resend(data:m.Challenge,request:Request):
    if err:=ready():return err
    with transaction() as db:result,sms=s.resend(db,data,ip(request))
    return output(result,sms=sms)


@router.post('/auth/login')
def login(data:m.Login,request:Request):
    if err:=ready():return err
    with transaction() as db:result,sms=s.login(db,data,ip(request))
    return output(result,sms=sms)


@router.post('/auth/refresh')
def refresh(data:m.Refresh):
    if err:=ready():return err
    with transaction() as db:result=s.refresh(db,data.refreshToken)
    return output(result)


@router.post('/auth/logout',status_code=204)
def logout(data:m.Refresh):
    if err:=ready():return err
    with transaction() as db:
        pair=s.session_by_token(db,data.refreshToken)
        if pair:s.revoke(db,pair[1]['id'])
    return Response(status_code=204)


def current_user(request,db):
    header=request.headers.get('authorization','')
    try:
        scheme,raw=header.split(' ',1)
        if scheme.lower()!='bearer':raise ValueError()
        claims=jwt.decode(raw,settings.auth_secret,algorithms=['HS256'],issuer=settings.auth_issuer,
                          audience=settings.auth_audience,options={'require':['sub','sid','exp','iat','iss','aud']})
        uid,sid=UUID(claims['sub']),UUID(claims['sid'])
    except jwt.ExpiredSignatureError:
        return s.failure(401,'ACCESS_TOKEN_EXPIRED')
    except (jwt.PyJWTError,ValueError,KeyError,TypeError):
        return s.failure(401,'ACCESS_TOKEN_INVALID')
    row=s.one(db,'''SELECT u.*,s.expires_at AS session_expiry,s.revoked_at AS session_revoked
        FROM account.users u JOIN account.user_sessions s ON s.user_id=u.id WHERE u.id=%s AND s.id=%s''',(uid,sid))
    if not row or row['session_revoked']:return s.failure(401,'SESSION_REVOKED')
    if row['session_expiry']<=sec.now():return s.failure(401,'SESSION_EXPIRED')
    if row['status']!='active':return s.failure(403,'ACCOUNT_UNAVAILABLE')
    return row


@router.get('/auth/me')
def me(user:dict=Depends(require_user)):
    return output(s.public_user(user))
