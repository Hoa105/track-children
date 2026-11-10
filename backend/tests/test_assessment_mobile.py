import datetime as dt
from uuid import uuid4
import pytest
from fastapi import HTTPException,FastAPI
from fastapi.testclient import TestClient
from .test_assessment_admin import db,actor,small_workspace
from app.features.assessment import service as m
from app.features.assessment.admin import service as admin
from app.features.assessment.router import router,SaveBody
from app.features.auth.dependencies import current_user_id
from app.core.database import get_db

@pytest.fixture
def workspace(db,actor,monkeypatch):
    monkeypatch.setattr(m,'today',lambda offset=420:dt.date(2026,1,15))
    qs,item=small_workspace(db,actor,True)
    for tip in admin.list_content(db,kind='advice'):admin.release_content(db,actor,tip['id'],tip['current_revision'])
    admin.release_question_set(db,actor,qs['id'])
    user=uuid4();child=uuid4()
    with db,db.cursor() as cur:
        cur.execute('ALTER TABLE child.children ADD COLUMN IF NOT EXISTS date_of_birth date,ADD COLUMN IF NOT EXISTS gestational_weeks smallint,ADD COLUMN IF NOT EXISTS owner_user_id uuid,ADD COLUMN IF NOT EXISTS deleted_at timestamptz')
        cur.execute("CREATE TABLE IF NOT EXISTS child.child_members(id uuid,child_id uuid,user_id uuid,status text);CREATE TABLE IF NOT EXISTS child.child_member_permissions(member_id uuid,data_scope text,access_level text)")
        cur.execute('INSERT INTO account.users(id) VALUES (%s)',(user,))
        cur.execute('INSERT INTO child.children(id,date_of_birth,owner_user_id,gestational_weeks) VALUES (%s,%s,%s,40)',(child,dt.date(2025,11,15),user))
    return {'id':child,'date_of_birth':dt.date(2025,11,15),'access':'edit'},user,qs,item

def answer(db,child,a,value='achieved'):
    return m.save(db,child,a['id'],SaveBody(expected_version=a['version'],answers={q['code']:value for q in a['questions']},regression='no',caregiver_concern='no'))

def test_parent_flow_pins_content_saves_completes_and_freezes_history(db,actor,workspace):
    child,user,qs,item=workspace
    attempt_id=uuid4();a=m.start(db,child,user,attempt_id)
    assert a['answers']=={} and a['regression'] is None and a['caregiver_concern'] is None
    assert m.start(db,child,user,uuid4())['id']==attempt_id
    a=answer(db,child,a,'not_yet');done=m.complete(db,child,a['id'],a['version'])
    assert done['status']=='completed' and done['result']['release_status']=='published'
    assert 'preview_diagnostics' not in done['result']
    assert m.complete(db,child,a['id'],1)['result']==done['result']
    admin.create_content_revision(db,actor,item['id'],__import__('app.features.assessment.admin.schema',fromlist=['AdminContentRevisionCreate']).AdminContentRevisionCreate(expectedRevision=1,payload={**item['payload'],'question_vi':'Updated question text after completion'},sourceRefs=item['source_refs']))
    admin.delete_content(db,actor,item['id'])
    loaded=m.load(db,child,a['id'])
    assert loaded['result']==done['result'] and loaded['questions']==done['questions']
    assert m.history(db,child)['items'][0]['summary']['not_yet']==1
    assert m.overview(db,child)['completed_milestones']==[2]
    with pytest.raises(HTTPException):answer(db,child,loaded)

def test_current_milestone_never_requires_old_attempt(db,workspace,monkeypatch):
    child,user,qs,item=workspace;a=m.start(db,child,user,uuid4())
    monkeypatch.setattr(m,'today',lambda offset=420:dt.date(2026,3,15))
    state=m.overview(db,child)
    assert state['age_months']==4 and state['draft'] is None and len(state['past_drafts'])==1
    assert not m.load(db,child,a['id'])['editable']
    with pytest.raises(HTTPException) as rejected:answer(db,child,a)
    assert rejected.value.status_code==409
    # A missing published new set cannot make the API silently open an old set.
    with pytest.raises(HTTPException) as missing:m.start(db,child,user,uuid4())
    assert missing.value.status_code==503

def test_incomplete_stale_and_unpublished_content_fail_without_partial_results(db,workspace):
    child,user,qs,item=workspace;a=m.start(db,child,user,uuid4())
    with pytest.raises(HTTPException):m.complete(db,child,a['id'],1)
    a=answer(db,child,a)
    with pytest.raises(HTTPException):m.save(db,child,a['id'],SaveBody(expected_version=1,answers={}))
    with pytest.raises(HTTPException):m.save(db,child,a['id'],SaveBody(expected_version=a['version'],answers={'outside':'achieved'}))
    tip=admin.list_content(db,kind='advice')[0]
    admin.lifecycle(db,None,'content_item',tip['id'],'availability',False)
    with pytest.raises(HTTPException) as unavailable:m.complete(db,child,a['id'],a['version'])
    assert unavailable.value.status_code==503
    assert m.load(db,child,a['id'])['status']=='in_progress'
    with db.cursor() as cur:
        cur.execute('SELECT count(*) AS count FROM assessment.assessment_results WHERE assessment_id=%s',(a['id'],))
        assert cur.fetchone()['count']==0

def test_child_access_is_enforced_for_every_parent_endpoint(db,workspace):
    child,user,qs,item=workspace
    app=FastAPI();app.include_router(router);identity={'id':user}
    app.dependency_overrides[current_user_id]=lambda:identity['id']
    def connection():yield db
    app.dependency_overrides[get_db]=connection
    base='/api/v1/children/'+str(child['id'])+'/assessment'
    with TestClient(app) as client:
        assert client.get(base+'/overview').status_code==200
        a=client.post(base+'/assessments',json={'id':str(uuid4())});assert a.status_code==200,a.text
        attempt=a.json();identity['id']=uuid4()
        paths=[('GET','/overview',None),('GET','/assessments',None),('GET','/assessments/'+attempt['id'],None),('POST','/assessments',{'id':str(uuid4())}),('PATCH','/assessments/'+attempt['id'],{'expected_version':1,'answers':{}}),('POST','/assessments/'+attempt['id']+'/complete',{'expected_version':1})]
        for method,path,body in paths:assert client.request(method,base+path,json=body).status_code==404

def test_preterm_requires_explicit_guidance_and_no_auto_correction(db,workspace):
    child,user,qs,item=workspace
    with db,db.cursor() as cur:cur.execute('UPDATE child.children SET gestational_weeks=32 WHERE id=%s',(child['id'],))
    assert m.overview(db,child)['guidance_required']
    with pytest.raises(HTTPException):m.start(db,child,user,uuid4())
    assert m.start(db,child,user,uuid4(),guidance=True)['age_months']==2

@pytest.mark.parametrize('day,expected',[(dt.date(2026,1,14),None),(dt.date(2026,1,15),2),(dt.date(2026,3,14),2),(dt.date(2026,3,15),4),(dt.date(2030,11,15),60),(dt.date(2030,12,14),60),(dt.date(2030,12,15),None)])
def test_open_window_uses_calendar_milestones_and_full_sixtieth_month(day,expected):
    assert m.age_for(dt.date(2025,11,15),day)==expected
