from typing import Literal

from fastapi import APIRouter, Request, Depends
from fastapi.responses import Response
from fastapi.responses import RedirectResponse
from urllib.parse import parse_qs, urlencode
import re

from app.core.database import transaction
from app.features.auth import schemas, service
from app.features.auth.dependencies import require_user, ready, client_ip
from app.features.auth.errors import AuthFailure
from app.features.auth.presenters import output

router = APIRouter(prefix="/api/v1", tags=["Mobile Auth"])


@router.post('/auth/social/apple/callback')
async def apple_android_callback(request: Request):
    from app.core.config import settings
    # The destination is deployment configuration, never a caller-provided redirect.
    package = settings.apple_android_package
    if not package or not re.fullmatch(r'[a-zA-Z0-9_.]+', package):
        return output(AuthFailure(503,'SOCIAL_AUTH_NOT_CONFIGURED'))
    raw = await request.body()
    if len(raw) > 32768:
        return Response(status_code=413)
    try:
        fields = parse_qs(raw.decode('utf-8'), max_num_fields=20)
    except (ValueError, UnicodeError):
        return Response(status_code=400)
    allowed = {key: values[0] for key,values in fields.items()
               if key in ('code','id_token','state','user','error','error_description') and len(values)==1}
    return RedirectResponse('intent://callback?'+urlencode(allowed)+
        '#Intent;package='+package+';scheme=signinwithapple;end', status_code=303,
        headers={'Cache-Control':'no-store','Referrer-Policy':'no-referrer'})


@router.post('/auth/social/apple/challenge')
def apple_social_challenge():
    from app.features.auth.social import apple_challenge
    if err := ready():
        return output(err)
    return output(apple_challenge())


@router.post('/auth/social')
def social_register(data: schemas.SocialRegister):
    from app.features.auth import social
    if err := ready():
        return output(err)
    if not data.acceptedTerms:
        return output(AuthFailure(422,'LEGAL_CONSENT_REQUIRED'))
    claims = social.verify_identity(data)
    if isinstance(claims, AuthFailure):
        return output(claims)
    with transaction() as db:
        result = social.register(db,data,claims)
    return output(result)


@router.get("/legal-documents")
def documents(context: Literal["registration"]):
    with transaction() as db:
        rows = service.legal(db)
    if isinstance(rows, AuthFailure):
        return output(rows)
    return {"documents": rows}


@router.post("/auth/register", status_code=201)
def register(data: schemas.Register, request: Request):
    if err := ready():
        return output(err)
    with transaction() as db:
        result, sms = service.register(db, data, client_ip(request))
    return output(result, 201, sms)


@router.post("/auth/register/verify")
def verify(data: schemas.Verify, request: Request):
    if err := ready():
        return output(err)
    with transaction() as db:
        result = service.verify(db, data, client_ip(request))
    return output(result)


@router.post("/auth/register/resend")
def resend(data: schemas.Challenge, request: Request):
    if err := ready():
        return output(err)
    with transaction() as db:
        result, sms = service.resend(db, data, client_ip(request))
    return output(result, sms=sms)


@router.post("/auth/login")
def login(data: schemas.Login, request: Request):
    if err := ready():
        return output(err)
    with transaction() as db:
        result, sms = service.login(db, data, client_ip(request))
    return output(result, sms=sms)


@router.post("/auth/refresh")
def refresh(data: schemas.Refresh):
    if err := ready():
        return output(err)
    with transaction() as db:
        result = service.refresh(db, data.refreshToken)
    return output(result)


@router.post("/auth/logout", status_code=204)
def logout(data: schemas.Refresh):
    if err := ready():
        return output(err)
    with transaction() as db:
        service.logout(db, data.refreshToken)
    return Response(status_code=204)


@router.get("/auth/me")
def me(user: dict = Depends(require_user)):
    return output(service.public_user(user))


@router.patch("/auth/me")
def update_profile(data: schemas.ProfileUpdate, request: Request):
    if err := ready():
        return output(err)
    from app.features.auth import account_service

    with transaction() as db:
        result = account_service.update_profile(db, request, data)
    return output(result)


@router.post("/auth/change-password", status_code=204)
def change_password(data: schemas.PasswordChange, request: Request):
    if err := ready():
        return output(err)
    from app.features.auth import account_service

    with transaction() as db:
        result = account_service.change_password(db, request, data)
    if isinstance(result, AuthFailure):
        return output(result)
    return Response(status_code=204, headers={"Cache-Control": "no-store"})
