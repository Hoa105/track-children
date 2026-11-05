"""Business regression tests; live cases use an explicitly disposable test DB."""
import copy
import os
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.features.development import service as s, transfer
from app.features.development.schema import AdminContentRevisionCreate, AdminReviewCreate


def test_bundled_drafts_have_159_skills_six_fixed_advice_variants():
    rows,errors=transfer.normalize(transfer.bundled())
    assert not errors, errors
    assert len(rows)==165
    assert sum(x['kind']=='skill' for x in rows)==159
    assert {x['stable_code'] for x in rows if x['kind']=='advice'}==set(s.VARIANTS)
    assert {x['age_months'] for x in rows if x['kind']=='skill'}==set(s.AGES)


def test_advice_conditions_are_locked():
    row=next(x for x in transfer.bundled() if x['kind']=='advice')
    payload=copy.deepcopy(row['payload']);payload['match_condition']='anything'
    with pytest.raises(HTTPException):s._validate_payload(payload,'advice',row['stable_code'])


@pytest.mark.parametrize('url',['https://user:secret@www.cdc.gov/a.png','http://www.cdc.gov/a.png','https://localhost/a.png','https://cdc.gov.attacker.example/a.png','https://127.0.0.1/a.png'])
def test_unsafe_media_rejected(url):
    with pytest.raises(HTTPException):s.validate_media({'type':'image','url':url})


def test_missing_alt_can_save_draft_but_cannot_publish_media():
    media={'type':'image','url':'https://www.cdc.gov/a.png'}
    s.validate_media(media)
    with pytest.raises(HTTPException):s.validate_media(media,strict=True)


def test_import_duplicate_codes_rejected_before_writes():
    row=transfer.bundled()[0]
    _,errors=transfer.normalize([row,row]);assert errors


@pytest.fixture
def db():
    import psycopg2
    url=os.environ.get('DEVELOPMENT_TEST_DATABASE_URL')
    if not url:pytest.skip('DEVELOPMENT_TEST_DATABASE_URL required')
    from psycopg2.extras import RealDictCursor
    conn=psycopg2.connect(url,cursor_factory=RealDictCursor)
    if not conn.info.dbname.startswith('development_admin_test_'):raise RuntimeError('Disposable development_admin_test_* database required')
    with conn,conn.cursor() as cur:
        cur.execute('TRUNCATE development.question_sets,development.content_items,admin.admin_users RESTART IDENTITY CASCADE')
    yield conn
    conn.close()


@pytest.fixture
def actor(db):
    uid=uuid4()
    with db,db.cursor() as cur:
        cur.execute('INSERT INTO admin.admin_users(id,full_name) VALUES (%s,%s)',(str(uid),'Admin kiểm thử'))
    return {'id':uid,'permission':'development.read'}


def seed(db,actor):
    p=transfer.preview(db,transfer.bundled());assert not p['errors'],p['errors']
    return transfer.commit(db,actor,p['rows'],p['fingerprint'])


def approve(db,actor,item):
    for kind in s.REVIEW_TYPES:s.create_review(db,actor['id'],actor,item['id'],AdminReviewCreate(revision=item['current_revision'],reviewType=kind,decision='approved',evidenceRef='Xác nhận giả lập trong CSDL kiểm thử'))


def test_live_import_idempotency_and_atomic_stale_preview(db,actor):
    result=seed(db,actor);assert result['created'] in (0,165)
    p=transfer.preview(db,transfer.bundled());assert not p['errors']
    result=transfer.commit(db,actor,p['rows'],p['fingerprint']);assert result=={'created':0,'revised':0,'unchanged':165}
    advice=s.list_content(db,kind='advice')[0]
    changed={**advice['payload'],'title':'Tiêu đề kiểm thử mới'}
    s.create_content_revision(db,actor,advice['id'],AdminContentRevisionCreate(expectedRevision=advice['current_revision'],payload=changed,sourceRefs=advice['source_refs']))
    with pytest.raises(HTTPException) as e:transfer.commit(db,actor,p['rows'],p['fingerprint'])
    assert e.value.status_code==409


def test_live_reviews_publish_revisions_and_restore_off(db,actor):
    seed(db,actor)
    item=s.list_content(db,kind='advice')[0]
    approve(db,actor,item)
    s.publish_content(db,actor,item['id'],item['current_revision'])
    s.lifecycle(db,actor,'content_item',item['id'],'availability',True)
    payload={**item['payload'],'title':'Bản sửa giữ lịch sử'}
    new=s.create_content_revision(db,actor,item['id'],AdminContentRevisionCreate(expectedRevision=item['current_revision'],payload=payload,sourceRefs=item['source_refs']))
    assert new['published_revision']==item['current_revision']
    assert not s.get_gate(db,item['id'])['blockers']
    with pytest.raises(HTTPException) as e:s.create_content_revision(db,actor,item['id'],AdminContentRevisionCreate(expectedRevision=item['current_revision'],payload=payload))
    assert e.value.status_code==409
    with pytest.raises(HTTPException):s.create_review(db,actor['id'],actor,item['id'],AdminReviewCreate(revision=item['current_revision'],reviewType='qa',decision='approved',evidenceRef='old'))
    s.delete_content(db,actor,item['id']);s.restore_content(db,actor,item['id'])
    restored=s.get_content(db,item['id']);assert not restored['is_active'];assert restored['published_revision']==item['current_revision']
    assert s.audit_rows(db,item['id'])[0]['actor']=='Admin kiểm thử'


def test_legacy_review_history_does_not_block_valid_content(db,actor):
    seed(db,actor);item=s.list_content(db,kind='advice')[1];approve(db,actor,item)
    s.create_review(db,actor['id'],actor,item['id'],AdminReviewCreate(revision=item['current_revision'],reviewType='qa',decision='rejected',note='Cần kiểm tra lại'))
    assert item['id'] in {r['content_item_id'] for r in s.list_review_queue(db,review_type='qa')}
    assert s.publish_content(db,actor,item['id'],item['current_revision'])['published_revision']==item['current_revision']


def test_live_order_validation_and_set_restore(db,actor):
    seed(db,actor);qs=s.list_question_sets(db)[0];items=s.list_content(db,qs['id']);ids=[x['id'] for x in items]
    with pytest.raises(HTTPException):s.reorder(db,actor,qs['id'],ids[:-1])
    s.reorder(db,actor,qs['id'],list(reversed(ids)))
    assert [x['id'] for x in s.list_content(db,qs['id'])]==list(reversed(ids))
    s.lifecycle(db,actor,'question_set',qs['id'],'delete');s.lifecycle(db,actor,'question_set',qs['id'],'restore')
    assert not s.get_question_set(db,qs['id'])['is_active']
    assert [x['id'] for x in s.list_content(db,qs['id'])]==list(reversed(ids))

def test_live_http_editor_and_sandbox_result(db,actor):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.features.development.router import admin_router,admin
    from app.core.database import get_db
    seed(db,actor)
    app=FastAPI();app.include_router(admin_router)
    app.dependency_overrides[admin]=lambda:actor
    def connection():yield db
    app.dependency_overrides[get_db]=connection
    with TestClient(app) as client:
        sets=client.get('/admin/development/question-sets');assert sets.status_code==200,sets.text
        qs=sets.json()[-1]
        response=client.get('/admin/development/question-sets/'+qs['id']+'/content');assert response.status_code==200,response.text
        rows=response.json();assert rows
        item=rows[0]
        response=client.get('/admin/development/content/'+item['id']+'/gate');assert response.status_code==200,response.text
        assert response.json()['blockers']
        # API serialization, pin validation and exact reference engine are exercised.
        answers={x['stableCode']:'achieved' for x in rows}
        for regression,concern,variant in [('no','no','CONTINUE_MONITORING'),('yes','no','CONTACT_REGRESSION_YES'),('unsure','no','CONTACT_REGRESSION_UNSURE'),('no','yes','CONTACT_CONCERN_ONLY')]:
            response=client.post('/admin/development/preview-result',json={'question_set_id':qs['id'],'answers':answers,'regression':regression,'caregiver_concern':concern})
            assert response.status_code==200,response.text
            view=response.json();assert view['release_status']=='sandbox_only'
            assert view['sections']['next_steps']['auto_play'] is False
            assert view['sections']['next_steps']['advice_items'][0]['variant_id']==variant
        keys=list(answers);answers[keys[0]]='not_yet';answers[keys[1]]='not_observed'
        response=client.post('/admin/development/preview-result',json={'question_set_id':qs['id'],'answers':answers,'regression':'no','caregiver_concern':'no'})
        assert response.status_code==200,response.text
        view=response.json();assert len(view['sections']['next_steps']['advice_items'])==2
        assert view['sections']['skills_to_note']['total']==2
        del answers[keys[0]]
        assert client.post('/admin/development/preview-result',json={'question_set_id':qs['id'],'answers':answers,'regression':'no','caregiver_concern':'no'}).status_code==422
        assert client.post('/admin/development/question-sets',json={'code':'bad-age','ageMonths':3,'version':'v1','sourceName':'Test'}).status_code==422


def test_live_unpublished_set_cannot_be_enabled(db,actor):
    seed(db,actor);qs=s.list_question_sets(db)[-1]
    with pytest.raises(HTTPException) as error:s.lifecycle(db,actor,'question_set',qs['id'],'availability',True)
    assert error.value.status_code==409

def test_live_http_review_queue_uses_frontend_contract(db,actor):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.features.development.router import admin_router,admin
    from app.core.database import get_db
    seed(db,actor)
    app=FastAPI();app.include_router(admin_router)
    app.dependency_overrides[admin]=lambda:actor
    def connection():yield db
    app.dependency_overrides[get_db]=connection
    with TestClient(app) as client:
        response=client.get('/admin/development/review-queue')
        assert response.status_code==200,response.text
        rows=response.json()
        assert len(rows)==165
        question=next(row for row in rows if row['kind']=='skill')
        assert question['contentItemId']
        assert question['stableCode'].startswith('CDC-')
        assert question['questionSetId']
        assert question['payload']['question_vi']
        assert 'content_item_id' not in question


def test_live_http_set_and_question_can_both_turn_on_and_off(db,actor):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.features.development.router import admin_router,admin
    from app.features.development.schema import AdminQuestionSetCreate,AdminContentCreate
    from app.core.database import get_db
    seed(db,actor)
    for advice in s.list_content(db,kind='advice'):
        approve(db,actor,advice)
        s.publish_content(db,actor,advice['id'],advice['current_revision'])
        s.lifecycle(db,actor,'content_item',advice['id'],'availability',True)
    qs=s.create_question_set(db,actor,AdminQuestionSetCreate(code='blk-test-12',ageMonths=12,version='test-v1',sourceName='Dữ liệu kiểm thử'))
    payload={**next(row['payload'] for row in transfer.bundled() if row['kind']=='skill'),'media':[],'source_name':'app_authored'}
    item=s.create_content(db,actor,qs['id'],AdminContentCreate(kind='skill',stableCode='BLK-12-TEST',sourceDomain='cognitive',appDomain='cognitive',orderIndex=1,payload=payload,sourceRefs=[{'document':'Nội dung kiểm thử giả lập'}]))
    released=s.release_question_set(db,actor,qs['id'])
    assert released['is_active'] is True
    assert released['status']=='published'
    assert s.get_content(db,item['id'])['is_active'] is True
    app=FastAPI();app.include_router(admin_router)
    app.dependency_overrides[admin]=lambda:actor
    def connection():yield db
    app.dependency_overrides[get_db]=connection
    with TestClient(app) as client:
        for path in [f"/content/{item['id']}",f"/question-sets/{qs['id']}"]:
            for active in (True,False,True):
                response=client.patch('/admin/development'+path+'/availability',json={'isActive':active})
                assert response.status_code==200,response.text
                row=client.get('/admin/development'+path).json()
                assert row['isActive'] is active
                listed=client.get('/admin/development/question-sets').json()
                summary=next(record for record in listed if record['id']==str(qs['id']))
                assert summary['visibleQuestionCount']==(int(active) if path.startswith('/content/') else 1)
        response=client.post(f"/admin/development/question-sets/{qs['id']}/release")
        assert response.status_code==200,response.text
        assert response.json()['isActive'] is True
        assert response.json()['status']=='published'
        client.patch(f"/admin/development/content/{item['id']}/availability",json={'isActive':False})
        rejected=client.post(f"/admin/development/question-sets/{qs['id']}/release")
        assert rejected.status_code==409,rejected.text
        assert client.get(f"/admin/development/content/{item['id']}").json()['isActive'] is False


def test_live_release_failure_preserves_draft_and_question_visibility(db,actor):
    seed(db,actor)
    qs=s.list_question_sets(db)[0]
    before=s.list_content(db,qs['id'])
    with pytest.raises(HTTPException):s.release_question_set(db,actor,qs['id'])
    after=s.get_question_set(db,qs['id'])
    assert after['status']=='draft'
    assert after['is_active'] is False
    assert [(x['id'],x['published_revision'],x['is_active']) for x in before]==[(x['id'],x['published_revision'],x['is_active']) for x in s.list_content(db,qs['id'])]

@pytest.mark.parametrize('kind',['skill','advice'])
def test_import_template_matches_fixed_contract_without_mutating_bundled_data(kind):
    rows=transfer.template(kind)
    normalized,errors=transfer.normalize(rows)
    assert not errors,errors
    assert len(normalized)==1
    assert normalized[0]['kind']==kind
    if kind=='skill':
        assert rows[0]['stable_code']=='BLK-2-MAU-01'
        assert transfer.bundled()[0]['stable_code']=='CDC-02-01'


def test_live_template_and_export_respect_kind_scope_and_soft_deletion(db,actor):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.features.development.router import admin_router,admin
    from app.core.database import get_db
    seed(db,actor)
    app=FastAPI();app.include_router(admin_router)
    app.dependency_overrides[admin]=lambda:actor
    def connection():yield db
    app.dependency_overrides[get_db]=connection
    qs=s.list_question_sets(db)[0]
    questions=s.list_content(db,qs['id'])
    with TestClient(app) as client:
        response=client.get('/admin/development/import/template?kind=skill')
        assert response.status_code==200,response.text
        assert not transfer.normalize(response.json())[1]
        assert client.get('/admin/development/import/template?kind=invalid').status_code==422
        all_rows=client.get('/admin/development/export?kind=skill').json()
        assert len(all_rows)==159
        params={'kind':'skill','set_ids':str(qs['id'])}
        scoped=client.get('/admin/development/export',params=params).json()
        assert len(scoped)==len(questions)
        assert {row['set_code'] for row in scoped}=={qs['code']}
        s.delete_content(db,actor,questions[0]['id'])
        assert len(client.get('/admin/development/export',params=params).json())==len(questions)-1
        s.lifecycle(db,actor,'question_set',qs['id'],'delete')
        assert client.get('/admin/development/export',params=params).json()==[]
        exported=client.get('/admin/development/export?kind=skill').json()
        assert qs['code'] not in {row['set_code'] for row in exported}

def test_question_release_validates_data_without_reviews_and_preserves_visibility_on_failure(db,actor):
    seed(db,actor)
    item=next(x for x in s.list_content(db) if x['kind']=='skill')
    with pytest.raises(HTTPException) as rejected:
        s.release_content(db,actor,item['id'],item['current_revision'])
    assert rejected.value.status_code==409
    unchanged=s.get_content(db,item['id'])
    assert unchanged['published_revision'] is None and unchanged['is_active'] is False
    item=s.create_content_revision(db,actor,item['id'],AdminContentRevisionCreate(expectedRevision=item['current_revision'],payload={**item['payload'],'media':[]},sourceRefs=item['source_refs']))
    with pytest.raises(HTTPException):
        s.release_content(db,actor,item['id'],item['current_revision']+1)
    released=s.release_content(db,actor,item['id'],item['current_revision'])
    assert released['published_revision']==item['current_revision']
    assert released['is_active'] is True
    revised=s.create_content_revision(db,actor,item['id'],AdminContentRevisionCreate(expectedRevision=item['current_revision'],payload={**item['payload'],'skill_name':''},sourceRefs=item['source_refs']))
    with pytest.raises(HTTPException):
        s.release_content(db,actor,item['id'],revised['current_revision'])
    unchanged=s.get_content(db,item['id'])
    assert unchanged['published_revision']==item['current_revision']
    assert unchanged['is_active'] is True

def test_advice_release_is_atomic_without_reviews_and_preserves_locked_conditions(db,actor):
    seed(db,actor)
    item=s.list_content(db,kind='advice')[0]
    assert not s.get_gate(db,item['id'])['reviews']
    released=s.release_content(db,actor,item['id'],item['current_revision'])
    assert released['is_active'] is True and released['published_revision']==item['current_revision']
    assert released['payload']['match_condition']==item['payload']['match_condition']
    with pytest.raises(HTTPException):
        s.create_content_revision(db,actor,item['id'],AdminContentRevisionCreate(expectedRevision=item['current_revision'],payload={**item['payload'],'match_condition':'changed'},sourceRefs=item['source_refs']))
    revision=s.create_content_revision(db,actor,item['id'],AdminContentRevisionCreate(expectedRevision=item['current_revision'],payload={**item['payload'],'title':'Advice draft updated'},sourceRefs=[]))
    with pytest.raises(HTTPException):
        s.release_content(db,actor,item['id'],revision['current_revision'])
    unchanged=s.get_content(db,item['id'])
    assert unchanged['is_active'] is True and unchanged['published_revision']==item['current_revision']
