"""HTTP transport for admin auth; business rules and SQL live in sibling modules."""
from fastapi import APIRouter, Depends, Request
from fastapi.responses import Response

from app.core import security as sec
from app.core.config import settings
from app.core.database import transaction
from app.features.auth.admin import repository, service
from app.features.auth.admin.schemas import AdminLogin, AdminPasswordChange, AdminProfileUpdate
from app.features.auth.dependencies import AuthenticationRequired, ready, client_ip
from app.features.auth.errors import AuthFailure, failure
from app.features.auth.presenters import output

COOKIE = 'tc_admin_refresh'
COOKIE_PATH = '/'


def browser_request(request: Request):
    if request.method != 'GET' and request.headers.get('x-requested-with') != 'TrackChildrenAdmin':
        raise AuthenticationRequired(output(failure(403,'CSRF_REJECTED')))
    if err := ready():
        raise AuthenticationRequired(output(err))


router = APIRouter(prefix='/admin/auth',tags=['Admin Auth'],dependencies=[Depends(browser_request)])


def clear_cookie(response):
    response.delete_cookie(COOKIE,path=COOKIE_PATH,httponly=True,
                           secure=settings.app_env != 'local',samesite='strict')
    return response


def session_response(result):
    if isinstance(result,AuthFailure):
        return output(result)
    public = {key:value for key,value in result.items() if key not in ('refreshToken','sessionExpiresAt')}
    response = output(public)
    response.set_cookie(COOKIE,result['refreshToken'],httponly=True,
        secure=settings.app_env != 'local',samesite='strict',path=COOKIE_PATH,
        max_age=max(1,int((result['sessionExpiresAt']-sec.now()).total_seconds())))
    return response


@router.post('/login')
def login(data: AdminLogin, request: Request):
    with transaction() as db:
        result = service.login(db,data,client_ip(request))
    return session_response(result)


@router.post('/refresh')
def refresh(request: Request):
    with transaction() as db:
        result = service.refresh(db,request.cookies.get(COOKIE,''))
    response = session_response(result)
    return clear_cookie(response) if isinstance(result,AuthFailure) else response


@router.get('/me')
def me(request: Request):
    with transaction() as db:
        result = service.me(db,request)
    return output(result)


@router.patch('/me')
def update_profile(data: AdminProfileUpdate, request: Request):
    with transaction() as db:
        result = service.update_profile(db, request, data)
    return output(result)


@router.post('/logout',status_code=204)
def logout(request: Request):
    with transaction() as db:
        repository.revoke_cookie(db,sec.secret_hash(request.cookies.get(COOKIE,'')))
    return clear_cookie(Response(status_code=204,headers={'Cache-Control':'no-store'}))


@router.post('/change-password',status_code=204)
def change_password(data: AdminPasswordChange, request: Request):
    with transaction() as db:
        result = service.change_password(db,request,data)
    if isinstance(result,AuthFailure):
        return output(result)
    return clear_cookie(Response(status_code=204,headers={'Cache-Control':'no-store'}))
