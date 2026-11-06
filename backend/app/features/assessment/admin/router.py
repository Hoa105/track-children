from typing import Any
from uuid import UUID
from typing import Literal
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from psycopg2.extensions import connection as Connection
from app.core.database import get_db
from app.features.auth.dependencies import require_admin_user
from . import service, transfer
from .schema import (AdminContentCreate,AdminContentRow,AdminContentRevision,AdminContentRevisionCreate,
 AdminQuestionSet,AdminQuestionSetCreate,AdminQuestionSetUpdate,AdminReviewCreate,AdminReviewRow,AvailabilityUpdate,QuestionOrder,PublishRevision)

admin_router=APIRouter(prefix='/admin/assessment',tags=['admin: assessment'])
# All active admins share the same rights; identity is retained for audit.
admin=require_admin_user('development.read')

class ImportBody(BaseModel):
    rows: list[dict[str,Any]] = Field(max_length=500)
    fingerprint: str | None = None

@admin_router.get('/question-sets',response_model=list[AdminQuestionSet])
def sets(status: str|None=None,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.list_question_sets(conn,status)

@admin_router.post('/question-sets',response_model=AdminQuestionSet,status_code=201)
def create_set(body:AdminQuestionSetCreate,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.create_question_set(conn,actor,body)

@admin_router.get('/question-sets/{set_id}',response_model=AdminQuestionSet)
def get_set(set_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.get_question_set(conn,set_id)

@admin_router.patch('/question-sets/{set_id}',response_model=AdminQuestionSet)
def update_set(set_id:UUID,body:AdminQuestionSetUpdate,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.update_question_set(conn,actor,set_id,body)

@admin_router.patch('/question-sets/{set_id}/availability')
def set_availability(set_id:UUID,body:AvailabilityUpdate,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.lifecycle(conn,actor,'question_set',set_id,'availability',body.is_active)

@admin_router.delete('/question-sets/{set_id}')
def delete_set(set_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.lifecycle(conn,actor,'question_set',set_id,'delete')

@admin_router.post('/question-sets/{set_id}/restore')
def restore_set(set_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.lifecycle(conn,actor,'question_set',set_id,'restore')

@admin_router.get('/question-sets/{set_id}/content',response_model=list[AdminContentRow])
def set_content(set_id:UUID,kind:str|None=Query(None,pattern='^(skill|advice)$'),active_only:bool=Query(False,alias='activeOnly'),actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.list_content(conn,set_id,kind,active_only)

@admin_router.post('/question-sets/{set_id}/content',response_model=AdminContentRow,status_code=201)
def create_content(set_id:UUID,body:AdminContentCreate,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.create_content(conn,actor,set_id,body)

@admin_router.put('/question-sets/{set_id}/order')
def order(set_id:UUID,body:QuestionOrder,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.reorder(conn,actor,set_id,body.content_ids)

@admin_router.post('/question-sets/{set_id}/publish')
def publish_set(set_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.publish_question_set(conn,actor,set_id)

@admin_router.post('/question-sets/{set_id}/release',response_model=AdminQuestionSet)
def release_set(set_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.release_question_set(conn,actor,set_id)

@admin_router.get('/content',response_model=list[AdminContentRow])
def all_content(kind:str=Query('advice',pattern='^(skill|advice)$'),actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.list_content(conn,kind=kind)

@admin_router.get('/content/{item_id}',response_model=AdminContentRow)
def content(item_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.get_content(conn,item_id)

@admin_router.get('/content/{item_id}/revisions',response_model=list[AdminContentRevision])
def revisions(item_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.list_content_revisions(conn,item_id)

@admin_router.post('/content/{item_id}/revisions',response_model=AdminContentRow)
def revise(item_id:UUID,body:AdminContentRevisionCreate,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.create_content_revision(conn,actor,item_id,body)

@admin_router.get('/content/{item_id}/gate')
def gate(item_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.get_gate(conn,item_id)

@admin_router.post('/content/{item_id}/reviews',status_code=201)
def review(item_id:UUID,body:AdminReviewCreate,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.create_review(conn,actor['id'],actor,item_id,body)

@admin_router.post('/content/{item_id}/publish',response_model=AdminContentRow)
def publish(item_id:UUID,body:PublishRevision,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.publish_content(conn,actor,item_id,body.expected_revision)

@admin_router.post('/content/{item_id}/release',response_model=AdminContentRow)
def release_content(item_id:UUID,body:PublishRevision,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.release_content(conn,actor,item_id,body.expected_revision)

@admin_router.patch('/content/{item_id}/availability')
def availability(item_id:UUID,body:AvailabilityUpdate,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.lifecycle(conn,actor,'content_item',item_id,'availability',body.is_active)

@admin_router.delete('/content/{item_id}')
def delete(item_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.delete_content(conn,actor,item_id)

@admin_router.post('/content/{item_id}/restore')
def restore(item_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.restore_content(conn,actor,item_id)

@admin_router.get('/audit/{item_id}')
def audit(item_id:UUID,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.audit_rows(conn,item_id)

@admin_router.get('/review-queue', response_model=list[AdminReviewRow])
def queue(question_set_id:UUID|None=Query(None,alias='questionSetId'),review_type:str|None=Query(None,alias='reviewType'),actor=Depends(admin),conn:Connection=Depends(get_db)):
    return service.list_review_queue(conn,question_set_id,review_type)

@admin_router.get('/export')
def export(set_id:UUID|None=None,kind:str|None=Query(None,pattern='^(skill|advice)$'),set_ids:list[UUID]|None=Query(None),actor=Depends(admin),conn:Connection=Depends(get_db)):
    return transfer.exported(conn,set_id,kind,set_ids)

@admin_router.get('/import/template')
def import_template(kind:str=Query('skill',pattern='^(skill|advice)$'),actor=Depends(admin)):
    return transfer.template(kind)

@admin_router.get('/seed-preview')
def seed_preview(actor=Depends(admin),conn:Connection=Depends(get_db)):
    return transfer.preview(conn,transfer.bundled())

@admin_router.post('/import/preview')
def import_preview(body:ImportBody,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return transfer.preview(conn,body.rows)

@admin_router.post('/import/commit')
def import_commit(body:ImportBody,actor=Depends(admin),conn:Connection=Depends(get_db)):
    return transfer.commit(conn,actor,body.rows,body.fingerprint)

class PreviewBody(BaseModel):
    question_set_id: UUID
    answers: dict[str,Literal['achieved','not_yet','not_observed']]
    regression: Literal['yes','no','unsure']
    caregiver_concern: Literal['yes','no']

@admin_router.post('/preview-result')
def preview_result(body:PreviewBody,actor=Depends(admin),conn:Connection=Depends(get_db)):
    from ..rule_engine import evaluate
    from ..advice_resolver import resolve_advice, VERSION
    from ..result_presenter import build_result_view_model
    qs=service.get_question_set(conn,body.question_set_id)
    if qs['deleted_at']: service.fail('Khôi phục bộ câu hỏi trước khi thử kết quả',409)
    skills=[x for x in service.list_content(conn,body.question_set_id,kind='skill') if not x['deleted_at']]
    if not skills: service.fail('Thêm ít nhất một câu hỏi trước khi thử kết quả')
    expected={x['stable_code'] for x in skills}
    missing=expected-set(body.answers);extra=set(body.answers)-expected
    if missing or extra:
        service.fail(f'Đáp án không khớp bộ câu hỏi: thiếu {len(missing)} câu, thừa {len(extra)} câu. Tải lại bộ và chọn đủ đáp án')
    advice=[{**x['payload'],'content_version':VERSION} for x in service.list_content(conn,kind='advice') if not x['deleted_at']]
    if len(advice)!=6 or {x.get('variant_id') for x in advice}!=set(service.VARIANTS):
        service.fail('Cần đủ 6 mẫu lời khuyên chưa xóa để thử kết quả')
    try:
        engine=evaluate(expected_question_ids=[x['stable_code'] for x in skills],answers=body.answers,
          regression=body.regression,caregiver_concern=body.caregiver_concern,question_set_age_months=qs['age_months'],
          domain_by_question={x['stable_code']:x['app_domain'] for x in skills},environment='sandbox')
        resolved=resolve_advice(step1_result=engine,regression=body.regression,caregiver_concern=body.caregiver_concern,advice_rows=advice,environment='sandbox')
        mapped={x['stable_code']:{**x['payload'],'app_domain':x['app_domain'],'age_months':qs['age_months'],'content_id':str(x['id']),'revision':x['current_revision'],'source_refs':x['source_refs']} for x in skills}
        for skill in mapped.values():
            if any(not isinstance(skill.get(k),str) or not skill[k].strip() for k in ('skill_name','not_yet_comment','not_observed_comment','observation_guide')): service.fail('Bổ sung tên kỹ năng, nhận xét và cách quan sát cho câu '+skill['content_id']+' trước khi thử kết quả')
        return build_result_view_model(step1_result=engine,step3_advice=resolved,skills_by_id=mapped)
    except (ValueError,KeyError) as error:
        service.fail('Không dựng được kết quả thử: kiểm tra đủ câu trả lời, 6 lời khuyên và nội dung kỹ năng')
