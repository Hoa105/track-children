from typing import Literal
from uuid import UUID
from fastapi import APIRouter,Depends,Query
from pydantic import BaseModel,Field
from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.shared.access import require_child_access
from . import service

router=APIRouter(prefix='/api/v1/children/{child_id}/assessment',tags=['mobile: assessment'])
class StartBody(BaseModel):
    id:UUID
    chronological_guidance_confirmed:bool=False
class SaveBody(BaseModel):
    expected_version:int=Field(ge=1)
    answers:dict[str,Literal['achieved','not_yet','not_observed']]
    regression:Literal['yes','no','unsure']|None=None
    caregiver_concern:Literal['yes','no']|None=None
class CompleteBody(BaseModel):
    expected_version:int=Field(ge=1)

def access(conn,child,user,edit=False):return require_child_access(conn,child,user,'assessment','edit' if edit else 'view')

@router.get('/overview')
def overview(child_id:UUID,tz:int=Query(420,ge=-720,le=840),user=Depends(current_user_id),conn=Depends(get_db)):
    return service.overview(conn,access(conn,child_id,user),tz)
@router.get('/assessments')
def history(child_id:UUID,age:int|None=None,offset:int=Query(0,ge=0),limit:int=Query(20,ge=1,le=50),user=Depends(current_user_id),conn=Depends(get_db)):
    return service.history(conn,access(conn,child_id,user),age,offset,limit)
@router.post('/assessments')
def start(child_id:UUID,body:StartBody,tz:int=Query(420,ge=-720,le=840),user=Depends(current_user_id),conn=Depends(get_db)):
    return service.start(conn,access(conn,child_id,user,True),user,body.id,body.chronological_guidance_confirmed,tz)
@router.get('/assessments/{attempt_id}')
def load(child_id:UUID,attempt_id:UUID,tz:int=Query(420,ge=-720,le=840),user=Depends(current_user_id),conn=Depends(get_db)):
    return service.load(conn,access(conn,child_id,user),attempt_id,tz)
@router.patch('/assessments/{attempt_id}')
def save(child_id:UUID,attempt_id:UUID,body:SaveBody,tz:int=Query(420,ge=-720,le=840),user=Depends(current_user_id),conn=Depends(get_db)):
    return service.save(conn,access(conn,child_id,user,True),attempt_id,body,tz)
@router.post('/assessments/{attempt_id}/complete')
def complete(child_id:UUID,attempt_id:UUID,body:CompleteBody,tz:int=Query(420,ge=-720,le=840),user=Depends(current_user_id),conn=Depends(get_db)):
    return service.complete(conn,access(conn,child_id,user,True),attempt_id,body.expected_version,tz)
