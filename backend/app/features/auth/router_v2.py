from fastapi import APIRouter,Depends,Request,BackgroundTasks
from app.core.database import transaction
from app.features.auth import schemas_v2 as s,transactions as tx,flows,account_security as security,recovery as recovery
from app.features.auth.dependencies import AuthenticationRequired,client_ip
from app.features.auth.errors import AuthFailure,failure
from app.features.auth.presenters import output


def require_ready():
    error=tx.ready()
    if error:
        raise AuthenticationRequired(output(error))


router=APIRouter(prefix='/api/v1/auth/v2',tags=['Mobile Auth v2'],dependencies=[Depends(require_ready)])

@router.get('/documents')
def documents():
    from app.features.auth.registration import legal
    docs=legal()
    snapshot=tx.documents()
    if isinstance(docs,AuthFailure):
        return output(docs)
    if isinstance(snapshot,AuthFailure):
        return output(snapshot)
    return output({'documents':docs,'documentsDigest':snapshot[1]})

@router.get('/security')
def security_state(request:Request):
    from app.features.auth.dependencies import current_user
    from app.features.auth.service import public_user
    with transaction() as db:
        user=current_user(request,db)
        if isinstance(user,AuthFailure):
            return output(user)
        providers=[r['provider'] for r in db.execute(
            'SELECT provider FROM account.social_identities WHERE user_id=%s ORDER BY provider',(user['id'],)).fetchall()]
        state=public_user(user)
        state['providers']=providers
        state['actions']={'changePassword':state['hasPassword'],
                          'setPassword':not state['hasPassword'] and bool(providers) and bool(user['email_verified_at'] or user['phone_verified_at']),
                          'changeEmail':True,'changePhone':True,'deleteAccount':True,
                          'linkProvider':True,'unlinkProvider':True}
        state['requiresIdentifierVerification']=not bool(user['email_verified_at'] or user['phone_verified_at'])
        state['ownedChildren']=db.execute('SELECT count(*) AS n FROM child.children WHERE owner_user_id=%s AND deleted_at IS NULL',(user['id'],)).fetchone()['n']
        return output(state)

@router.post('/signup/start')
def signup_start(data:s.Start,request:Request):
    with transaction() as db:
        result=flows.signup_start(db,data,client_ip(request))
    return output(result)

@router.post('/signup/resend')
def signup_resend(data:s.Ticket,request:Request):
    with transaction() as db:
        result=flows.signup_resend(db,data,client_ip(request))
    return output(result)

@router.post('/signup/verify')
def signup_verify(data:s.Verify,request:Request):
    with transaction() as db:
        result=flows.signup_verify(db,data,client_ip(request))
    return output(result)

@router.post('/signup/complete')
def signup_complete(data:s.Complete,request:Request):
    with transaction() as db:
        result=flows.signup_complete(db,data,client_ip(request))
    return output(result)

@router.post('/signup/invalidate')
def signup_invalidate(data:s.Ticket):
    with transaction() as db:
        row=tx.load(db,data,'phone_signup')
        if isinstance(row,AuthFailure):
            result=row
        else:
            db.execute('UPDATE account.auth_transactions SET invalidated_at=now() WHERE id=%s',(row['id'],))
            result={'invalidated':True}
    return output(result)

@router.post('/social/start')
def social_start(data:s.SocialStart,request:Request):
    with transaction() as db:
        result=flows.social_start(db,data,client_ip(request))
    return output(result)

@router.post('/social/complete')
def social_complete(data:s.SocialComplete,request:Request):
    with transaction() as db:
        result=flows.social_complete(db,data,client_ip(request))
    return output(result)

@router.post('/password/change')
def change_password(data:s.ChangePassword,request:Request):
    with transaction() as db:
        result=security.change_password(db,request,data)
    return output(result)

@router.post('/reauth')
def reauth(data:s.Reauth,request:Request):
    with transaction() as db:
        result=security.reauth(db,request,data,client_ip(request))
    return output(result)

@router.post('/password/setup')
def password_setup(data:s.SetupPassword,request:Request):
    with transaction() as db:
        result=security.setup_password(db,request,data)
    return output(result)

@router.post('/email/start')
def email_start(data:s.Ticket,request:Request):
    with transaction() as db:
        result=security.identifier_start(db,request,data,'change_email',client_ip(request))
    return output(result)

@router.post('/phone/start')
def phone_start(data:s.Ticket,request:Request):
    with transaction() as db:
        result=security.identifier_start(db,request,data,'change_phone',client_ip(request))
    return output(result)

@router.post('/email/verify')
def email_verify(data:s.IdentifierVerify,request:Request):
    with transaction() as db:
        result=security.identifier_commit(db,request,data,'change_email')
    return output(result)

@router.post('/email/resend')
def email_resend(data:s.Ticket,request:Request):
    with transaction() as db:
        result=security.identifier_resend(db,request,data,'change_email',client_ip(request))
    return output(result)

@router.post('/phone/resend')
def phone_resend(data:s.Ticket,request:Request):
    with transaction() as db:
        result=security.identifier_resend(db,request,data,'change_phone',client_ip(request))
    return output(result)

@router.post('/phone/verify')
def phone_verify(data:s.IdentifierVerify,request:Request):
    with transaction() as db:
        result=security.identifier_commit(db,request,data,'change_phone')
    return output(result)

@router.post('/recovery/start')
def recovery_start(data:s.RecoveryStart,request:Request,background:BackgroundTasks):
    with transaction() as db:
        result=recovery.start(db,data,client_ip(request))
    if not isinstance(result,AuthFailure):
        background.add_task(recovery.deliver,result,client_ip(request))
    return output(result)

@router.post('/recovery/verify')
def recovery_verify(data:s.RecoveryVerify,request:Request):
    with transaction() as db:
        result=recovery.verify(db,data,client_ip(request))
    return output(result)

@router.post('/recovery/resend')
def recovery_resend(data:s.RecoveryResend,request:Request,background:BackgroundTasks):
    with transaction() as db:
        result=recovery.resend(db,data,client_ip(request))
    if not isinstance(result,AuthFailure):
        background.add_task(recovery.deliver,result)
    return output(result)

@router.post('/recovery/email/start')
def recovery_email_start(data:s.RecoveryEmail,request:Request):
    with transaction() as db:
        result=recovery.email_start(db,data,client_ip(request))
    return output(result)

@router.post('/recovery/email/verify')
def recovery_email_verify(data:s.Verify):
    with transaction() as db:
        result=recovery.email_verify(db,data)
    return output(result)

@router.post('/recovery/provider')
def recovery_provider(data:s.RecoveryProvider):
    with transaction() as db:
        result=recovery.provider(db,data)
    return output(result)

@router.post('/recovery/complete')
def recovery_complete(data:s.RecoveryComplete):
    with transaction() as db:
        result=recovery.complete(db,data)
    return output(result)

@router.post('/account/delete')
def delete_account(data:s.DeleteAccount,request:Request):
    from app.features.auth import provider_security
    with transaction() as db:
        result=provider_security.delete(db,request,data)
    return output(result)

@router.post('/providers/link')
def provider_link(data:s.ProviderLink,request:Request):
    from app.features.auth import provider_security
    with transaction() as db:
        result=provider_security.link(db,request,data)
    return output(result)

@router.post('/providers/unlink')
def provider_unlink(data:s.ProviderUnlink,request:Request):
    from app.features.auth import provider_security
    with transaction() as db:
        result=provider_security.unlink(db,request,data)
    return output(result)

@router.post('/providers/apple/events')
def apple_event(data:s.AppleEvent):
    from app.features.auth import provider_security
    with transaction() as db:
        result=provider_security.apple_event(db,data)
    return output(result)
