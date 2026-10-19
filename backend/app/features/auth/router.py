from typing import Literal

from fastapi import APIRouter, Request, Depends
from fastapi.responses import Response

from app.core.database import transaction
from app.features.auth import schemas, service
from app.features.auth.dependencies import require_user, ready, client_ip
from app.features.auth.errors import AuthFailure
from app.features.auth.presenters import output

router = APIRouter(prefix="/api/v1", tags=["Mobile Auth"])


@router.get("/legal-documents")
def documents(context: Literal["registration"]):
    with transaction() as db:
        rows = service.legal(db)
    if isinstance(rows, AuthFailure):
        return output(rows)
    return {
        "documents": [
            {
                "id": r["id"],
                "docType": r["doc_type"],
                "version": r["version"],
                "content": r["content"],
                "isRequired": r["is_required"],
                "effectiveAt": r["effective_at"],
            }
            for r in rows
        ]
    }


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
