"""Business regression tests; live cases use an explicitly disposable test DB."""
import copy
import os
from uuid import uuid4
import pytest
from fastapi import HTTPException
from app.features.assessment.admin import service as s, transfer
from app.features.assessment.admin.schema import AdminContentRevisionCreate, AdminReviewCreate


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
        cur.execute('TRUNCATE assessment.question_sets,assessment.content_items,admin.admin_users RESTART IDENTITY CASCADE')
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
    from app.features.assessment.admin.router import admin_router,admin
    from app.core.database import get_db
    seed(db,actor)
    app=FastAPI();app.include_router(admin_router)
    app.dependency_overrides[admin]=lambda:actor
    def connection():yield db
    app.dependency_overrides[get_db]=connection
    with TestClient(app) as client:
        sets=client.get('/admin/assessment/question-sets');assert sets.status_code==200,sets.text
        qs=sets.json()[-1]
        response=client.get('/admin/assessment/question-sets/'+qs['id']+'/content');assert response.status_code==200,response.text
        rows=response.json();assert rows
        item=rows[0]
        response=client.get('/admin/assessment/content/'+item['id']+'/gate');assert response.status_code==200,response.text
        assert response.json()['blockers']
        # API serialization, pin validation and exact reference engine are exercised.
        answers={x['stableCode']:'achieved' for x in rows}
        for regression,concern,variant in [('no','no','CONTINUE_MONITORING'),('yes','no','CONTACT_REGRESSION_YES'),('unsure','no','CONTACT_REGRESSION_UNSURE'),('no','yes','CONTACT_CONCERN_ONLY')]:
            response=client.post('/admin/assessment/preview-result',json={'question_set_id':qs['id'],'answers':answers,'regression':regression,'caregiver_concern':concern})
            assert response.status_code==200,response.text
            view=response.json();assert view['release_status']=='sandbox_only'
            assert view['sections']['next_steps']['auto_play'] is False
            assert view['sections']['next_steps']['advice_items'][0]['variant_id']==variant
        enriched={**rows[0]['payload'],'skill_guidance':{'explanation':'Giải thích kỹ năng kiểm thử','support_steps':['Bước hỗ trợ kiểm thử 1','Bước hỗ trợ kiểm thử 2'],'discussion_points':'Ghi nhận kiểm thử'}}
        saved=client.post('/admin/assessment/content/'+rows[0]['id']+'/revisions',json={'expectedRevision':rows[0]['currentRevision'],'payload':enriched,'sourceRefs':rows[0]['sourceRefs']})
        assert saved.status_code==200,saved.text
        history=client.get('/admin/assessment/content/'+rows[0]['id']+'/revisions').json()
        assert 'skill_guidance' not in history[-1]['payload']
        keys=list(answers);answers[keys[0]]='not_yet';answers[keys[1]]='not_observed'
        response=client.post('/admin/assessment/preview-result',json={'question_set_id':qs['id'],'answers':answers,'regression':'no','caregiver_concern':'no'})
        assert response.status_code==200,response.text
        view=response.json();assert len(view['sections']['next_steps']['advice_items'])==2
        assert view['sections']['skills_to_note']['total']==2
        assert set(view['sections'])=={'overview','overall_comment','skills_to_note','next_steps'}
        assert [step['id'] for step in view['sections']['next_steps']['action_plan']['actions']]==['contact','prepare','observe']
        assert 'facts' not in view['sections']['next_steps']['action_plan']
        assert {fact['id'] for fact in view['preview_diagnostics']['reported_signals']}=={'not_yet','not_observed'}
        assert 'skill_guidance' not in view['sections']['next_steps']
        assert 'Bước hỗ trợ kiểm thử 1' not in view['sections']['next_steps']['tts_text']
        assert len(view['preview_diagnostics']['selected_templates'])==2
        del answers[keys[0]]
        assert client.post('/admin/assessment/preview-result',json={'question_set_id':qs['id'],'answers':answers,'regression':'no','caregiver_concern':'no'}).status_code==422
        assert client.post('/admin/assessment/question-sets',json={'code':'bad-age','ageMonths':3,'version':'v1','sourceName':'Test'}).status_code==422


def test_live_unpublished_set_cannot_be_enabled(db,actor):
    seed(db,actor);qs=s.list_question_sets(db)[-1]
    with pytest.raises(HTTPException) as error:s.lifecycle(db,actor,'question_set',qs['id'],'availability',True)
    assert error.value.status_code==409

def test_live_http_review_queue_uses_frontend_contract(db,actor):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.features.assessment.admin.router import admin_router,admin
    from app.core.database import get_db
    seed(db,actor)
    app=FastAPI();app.include_router(admin_router)
    app.dependency_overrides[admin]=lambda:actor
    def connection():yield db
    app.dependency_overrides[get_db]=connection
    with TestClient(app) as client:
        response=client.get('/admin/assessment/review-queue')
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
    from app.features.assessment.admin.router import admin_router,admin
    from app.features.assessment.admin.schema import AdminQuestionSetCreate,AdminContentCreate
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
                response=client.patch('/admin/assessment'+path+'/availability',json={'isActive':active})
                assert response.status_code==200,response.text
                row=client.get('/admin/assessment'+path).json()
                assert row['isActive'] is active
                listed=client.get('/admin/assessment/question-sets').json()
                summary=next(record for record in listed if record['id']==str(qs['id']))
                assert summary['visibleQuestionCount']==(int(active) if path.startswith('/content/') else 1)
        response=client.post(f"/admin/assessment/question-sets/{qs['id']}/release")
        assert response.status_code==200,response.text
        assert response.json()['isActive'] is True
        assert response.json()['status']=='published'
        client.patch(f"/admin/assessment/content/{item['id']}/availability",json={'isActive':False})
        rejected=client.post(f"/admin/assessment/question-sets/{qs['id']}/release")
        assert rejected.status_code==409,rejected.text
        assert client.get(f"/admin/assessment/content/{item['id']}").json()['isActive'] is False


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
    from app.features.assessment.admin.router import admin_router,admin
    from app.core.database import get_db
    seed(db,actor)
    app=FastAPI();app.include_router(admin_router)
    app.dependency_overrides[admin]=lambda:actor
    def connection():yield db
    app.dependency_overrides[get_db]=connection
    qs=s.list_question_sets(db)[0]
    questions=s.list_content(db,qs['id'])
    with TestClient(app) as client:
        response=client.get('/admin/assessment/import/template?kind=skill')
        assert response.status_code==200,response.text
        assert not transfer.normalize(response.json())[1]
        assert client.get('/admin/assessment/import/template?kind=invalid').status_code==422
        all_rows=client.get('/admin/assessment/export?kind=skill').json()
        assert len(all_rows)==159
        params={'kind':'skill','set_ids':str(qs['id'])}
        scoped=client.get('/admin/assessment/export',params=params).json()
        assert len(scoped)==len(questions)
        assert {row['set_code'] for row in scoped}=={qs['code']}
        s.delete_content(db,actor,questions[0]['id'])
        assert len(client.get('/admin/assessment/export',params=params).json())==len(questions)-1
        s.lifecycle(db,actor,'question_set',qs['id'],'delete')
        assert client.get('/admin/assessment/export',params=params).json()==[]
        exported=client.get('/admin/assessment/export?kind=skill').json()
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

@pytest.mark.parametrize('guidance',[None,[],{'explanation':'Legacy draft','support_steps':[]}])
def test_removed_skill_advice_does_not_block_question_validation(guidance):
    row=copy.deepcopy(next(x for x in transfer.bundled() if x['kind']=='skill'))
    row['payload']['skill_guidance']=guidance
    s._validate_payload(row['payload'],'skill',row['stable_code'])
    assert row['payload']['skill_guidance']==guidance

def test_updated_advice_samples_are_complete_and_keep_selection_rules():
    rows=[row for row in transfer.bundled() if row['kind']=='advice']
    assert {row['stable_code'] for row in rows}==set(s.VARIANTS)
    for row in rows:
        payload=row['payload']
        assert len(payload['body_text'])>80
        assert 'mốc' not in payload['body_text'].casefold()
        assert payload['editorial_version'].startswith('advice-local-test-v5')
        assert payload['source_name'].endswith('CDC')
        assert all(ref.get('url','').startswith('https://www.cdc.gov/') for ref in row['source_refs'])
        s._validate_payload(payload,'advice',row['stable_code'])


def test_local_advice_sample_update_is_versioned_idempotent_and_preserves_publication(db,actor):
    from scripts.update_assessment_advice_samples import update_samples
    seed(db,actor)
    advice=s.list_content(db,kind='advice')[0]
    custom=s.create_content_revision(db,actor,advice['id'],AdminContentRevisionCreate(expectedRevision=advice['current_revision'],payload={**advice['payload'],'body_text':'Existing local content','custom_field':'keep this'},sourceRefs=advice['source_refs']))
    s.release_content(db,actor,advice['id'],custom['current_revision'])
    before=[(row['id'],row['current_revision']) for row in s.list_content(db,kind='skill')]
    result=update_samples(db,apply=True)
    assert result['revised']==1 and result['unchanged']==5
    updated=s.get_content(db,advice['id'])
    assert updated['current_revision']==custom['current_revision']+1
    assert updated['published_revision']==custom['current_revision'] and updated['is_active'] is True
    assert updated['payload']['custom_field']=='keep this'
    assert [(row['id'],row['current_revision']) for row in s.list_content(db,kind='skill')]==before
    assert update_samples(db,apply=True)['unchanged']==6

def test_exhaustive_advice_selection_counts_and_followup_answers():
    from app.features.assessment.admin.advice_audit import audit_advice_cases
    rows=transfer.bundled()
    sets=[{'age_months':age,'question_ids':[row['stable_code'] for row in rows if row['kind']=='skill' and row['age_months']==age]} for age in s.AGES]
    report=audit_advice_cases(sets,[row['payload'] for row in rows if row['kind']=='advice'])
    assert report['cases']==7950 and report['sets']==12
    assert len(report['selection_paths'])==10
    assert len(report['context_patterns'])==24
    assert report['combined_cases']>0


def test_advice_composition_removes_exact_duplicate_paragraphs_and_spoken_sentences():
    from app.features.assessment.advice_resolver import resolve_advice,VERSION
    from app.features.assessment.rule_engine import evaluate
    engine=evaluate(expected_question_ids=['a','b'],answers={'a':'not_yet','b':'not_observed'},regression='no',caregiver_concern='no',question_set_age_months=12)
    rows=[{**row['payload'],'content_version':VERSION} for row in transfer.bundled() if row['kind']=='advice']
    for row in rows:
        if row['variant_id']=='CONTACT_NOT_YET':row.update(body_text='Repeated paragraph.\n\nUnique contact paragraph.',tts_text='Repeated sentence. Unique contact sentence.')
        if row['variant_id']=='OBSERVE_UNCHECKED':row.update(body_text='Repeated paragraph.\n\nUnique observation paragraph.',tts_text='Repeated sentence. Unique observation sentence.')
    result=resolve_advice(step1_result=engine,regression='no',caregiver_concern='no',advice_rows=rows)
    assert sum(row['body_text'].count('Repeated paragraph.') for row in result['advice_items'])==1
    assert 'Unique observation paragraph.' in result['advice_items'][1]['body_text']
    assert result['tts_short_text'].count('Repeated sentence.')==1
    assert 'Unique contact sentence.' in result['tts_short_text'] and 'Unique observation sentence.' in result['tts_short_text']

def test_advice_preparation_fields_require_text():
    item=next(row for row in transfer.bundled() if row['stable_code']=='CONTACT_NOT_YET')
    payload=copy.deepcopy(item['payload']);payload['preparation_text']=5
    with pytest.raises(HTTPException):s._validate_payload(payload,'advice',item['stable_code'])

@pytest.mark.parametrize('mode',['all_achieved','not_yet','not_observed','mixed'])
@pytest.mark.parametrize('regression',['no','yes','unsure'])
@pytest.mark.parametrize('concern',['no','yes'])
def test_action_plan_preserves_all_signals_and_orders_unique_actions(mode,regression,concern):
    from app.features.assessment.advice_resolver import resolve_advice,VERSION
    from app.features.assessment.rule_engine import evaluate
    patterns={'all_achieved':['achieved','achieved'],'not_yet':['not_yet','achieved'],'not_observed':['not_observed','achieved'],'mixed':['not_yet','not_observed']}
    answers=dict(zip(['q1','q2'],patterns[mode]));n='not_yet' in answers.values();o='not_observed' in answers.values()
    engine=evaluate(expected_question_ids=['q1','q2'],answers=answers,regression=regression,caregiver_concern=concern,question_set_age_months=12)
    rows=[{**row['payload'],'content_version':VERSION} for row in transfer.bundled() if row['kind']=='advice']
    by_id={row['variant_id']:row for row in rows}
    result=resolve_advice(step1_result=engine,regression=regression,caregiver_concern=concern,advice_rows=rows)
    plan=result['action_plan'];contact=bool(n or regression!='no' or concern=='yes')
    expected_actions=(['contact','prepare'] if contact else [])+(['observe'] if o else [])+(['continue'] if not contact and not o else [])
    assert [action['id'] for action in plan['actions']]==expected_actions
    expected_facts=({'not_yet'} if n else set())|({'not_observed'} if o else set())|({'all_achieved'} if not n and not o else set())|({'regression_'+regression} if regression!='no' else set())|({'caregiver_concern'} if concern=='yes' else set())
    assert {fact['id'] for fact in plan['facts']}==expected_facts
    prep=next((action['items'] for action in plan['actions'] if action['id']=='prepare'),[])
    if n:assert by_id['CONTACT_NOT_YET']['preparation_text'] in prep
    if concern=='yes':assert by_id['CONTACT_CONCERN_ONLY']['preparation_text'] in prep
    if regression!='no':assert by_id['CONTACT_REGRESSION_YES' if regression=='yes' else 'CONTACT_REGRESSION_UNSURE']['preparation_text'] in prep
    assert len(prep)==len(set(prep))
    assert bool(plan['observation_timing'])==(contact and o)
    for action in plan['actions']:
        assert 'mốc' not in action['body'].lower()
        if action['id']=='observe':assert 'bác sĩ' not in action['body']
    assert result['tts_short_text']==plan['tts_text']
    assert all(fact['text'] not in plan['tts_text'] for fact in plan['facts'])

@pytest.mark.parametrize('mode',['all_achieved','not_yet','all_not_yet','not_observed','mixed','all_unobserved'])
@pytest.mark.parametrize('regression',['no','yes','unsure'])
@pytest.mark.parametrize('concern',['no','yes'])
def test_overall_commentary_is_descriptive_source_based_and_keeps_all_parent_signals(mode,regression,concern):
    from app.features.assessment.rule_engine import evaluate
    from app.features.assessment.overall_commentary import build_overall_commentary
    patterns={'all_achieved':['achieved','achieved'],'not_yet':['not_yet','achieved'],'all_not_yet':['not_yet','not_yet'],'not_observed':['not_observed','achieved'],'mixed':['not_yet','not_observed'],'all_unobserved':['not_observed','not_observed']}
    answers=dict(zip(['q1','q2'],patterns[mode]));n=list(answers.values()).count('not_yet');o=list(answers.values()).count('not_observed')
    engine=evaluate(expected_question_ids=['q1','q2'],answers=answers,regression=regression,caregiver_concern=concern,question_set_age_months=12)
    comment=build_overall_commentary(step1_result=engine,skills_by_id={'q1':{'app_domain':'gross_motor'},'q2':{'app_domain':'language_communication'}})
    ids=[row['id'] for row in comment['paragraphs']]
    assert len(ids)==len(set(ids))
    assert ('regression_yes' in ids)==(regression=='yes')
    assert ('regression_unsure' in ids)==(regression=='unsure')
    assert ('caregiver_concern' in ids)==(concern=='yes')
    contact=bool(n or regression!='no' or concern=='yes')
    assert comment['professional_review_recommended']==contact
    assert ('professional_contact' in ids)==contact
    if mode=='all_unobserved':assert ids[0]=='all_unobserved'
    if mode=='mixed':assert ids[0]=='mixed'
    if mode=='all_achieved':assert ids[0]==('all_recorded_context' if contact else 'all_recorded')
    assert sum(row['total'] for row in comment['domain_observations'])==2
    assert sum(row['not_observed'] for row in comment['domain_observations'])==o
    source_ids={source['id'] for source in comment['sources']}
    assert all(set(row['source_ids'])<=source_ids for row in comment['paragraphs'])
    assert 'không thay thế việc sàng lọc' in comment['paragraphs'][-1]['text']
    first=comment['paragraphs'][0]['text']
    if mode in ('not_yet','mixed','all_not_yet'):assert 'vận động thô' in first
    if mode=='not_yet':assert 'ngôn ngữ và giao tiếp' not in first
    if mode in ('mixed','all_not_yet'):assert 'ngôn ngữ và giao tiếp' in first
    if mode=='not_observed':
        assert 'vận động thô' in first
        assert 'ngôn ngữ và giao tiếp' not in first
    if mode in ('all_achieved','all_unobserved','not_yet','all_not_yet','mixed'):assert '12 tháng' in first
    assert '{' not in comment['tts_text']
    assert first.startswith(('Kết quả bài đánh giá','Tất cả kỹ năng trong bài đánh giá'))
    assert all(phrase not in comment['tts_text'].lower() for phrase in ['bạn cho biết','gia đình cho biết','phụ huynh cho biết'])
    assert len(comment['tts_text'].split()) <= 230
    assert all(row['text'] not in comment['tts_text'] for row in comment['domain_observations'])
    assert all(word not in comment['tts_text'] for word in ['nguy cơ cao','bé bị chậm','phát triển bình thường'])


def small_workspace(db,actor,with_advice=False):
    rows=transfer.template('skill')
    rows[0]['payload']['media']=[]
    rows[0]['set_source_name']='Nguồn bộ kiểm thử'
    if with_advice: rows += [copy.deepcopy(x) for x in transfer.bundled() if x['kind']=='advice']
    checked=transfer.preview(db,rows)
    assert not checked['errors'],checked['errors']
    transfer.commit(db,actor,checked['rows'],checked['fingerprint'])
    qs=s.list_question_sets(db)[0]
    return qs,s.list_content(db,qs['id'])[0]


def test_deleted_parent_blocks_question_mutations_and_restore(db,actor):
    qs,item=small_workspace(db,actor)
    s.release_content(db,actor,item['id'],1)
    s.lifecycle(db,actor,'question_set',qs['id'],'delete')
    actions=[lambda:s.create_content_revision(db,actor,item['id'],AdminContentRevisionCreate(expectedRevision=1,payload=item['payload'],sourceRefs=item['source_refs'])),
             lambda:s.publish_content(db,actor,item['id'],1),lambda:s.release_content(db,actor,item['id'],1),
             lambda:s.lifecycle(db,actor,'content_item',item['id'],'availability',True)]
    for action in actions:
        with pytest.raises(HTTPException) as rejected:action()
        assert rejected.value.status_code==409
    assert len(s.list_content_revisions(db,item['id']))==1
    s.delete_content(db,actor,item['id'])
    with pytest.raises(HTTPException):s.restore_content(db,actor,item['id'])
    s.lifecycle(db,actor,'question_set',qs['id'],'restore')
    s.restore_content(db,actor,item['id'])
    assert s.get_content(db,item['id'])['is_active'] is False


def test_restore_question_relocates_occupied_position_and_records_history(db,actor):
    from app.features.assessment.admin.schema import AdminContentCreate
    qs,item=small_workspace(db,actor)
    s.delete_content(db,actor,item['id'])
    replacement=s.create_content(db,actor,qs['id'],AdminContentCreate(stableCode='BLK-2-REPLACEMENT',appDomain='fine_motor',sourceDomain='cognitive',orderIndex=item['order_index'],payload=item['payload'],sourceRefs=item['source_refs']))
    assert replacement['source_domain']=='movement_physical'
    s.restore_content(db,actor,item['id'])
    restored=s.get_content(db,item['id'])
    assert restored['order_index']>replacement['order_index']
    assert restored['is_active'] is False and restored['published_revision'] is None
    event=next(x for x in s.audit_rows(db,item['id']) if x['action']=='restore')
    assert event['after_data']['order_index']==restored['order_index']
    assert event['after_data']['deleted_at'] is None


def test_revision_audit_includes_content_and_appears_in_parent_history(db,actor):
    qs,item=small_workspace(db,actor)
    payload={**item['payload'],'question_vi':'Nội dung câu hỏi đã được chỉnh sửa để kiểm tra lịch sử'}
    s.create_content_revision(db,actor,item['id'],AdminContentRevisionCreate(expectedRevision=1,payload=payload,sourceRefs=[{'document':'Nguồn mới'}]))
    event=next(x for x in s.audit_rows(db,qs['id']) if x['action']=='create_revision')
    assert event['before_data']['payload']==item['payload']
    assert event['after_data']['payload']==payload
    assert event['after_data']['source_refs']==[{'document':'Nguồn mới'}]
    assert event['after_data']['code']==item['stable_code']
    assert event['actor']=='Admin kiểm thử'


def test_schema_rename_preserves_content_legacy_tables_and_is_repeatable(db,actor):
    from pathlib import Path
    qs,item=small_workspace(db,actor)
    migration=(Path(__file__).resolve().parents[1]/'migrations/025_rename_schema_to_assessment.sql').read_text(encoding='utf-8')
    migration=migration.replace('BEGIN;','').replace('COMMIT;','')
    with db,db.cursor() as cur:
        cur.execute('ALTER SCHEMA assessment RENAME TO development')
        cur.execute('CREATE SCHEMA assessment; CREATE TABLE assessment.assessments(id integer); CREATE TABLE assessment.assessment_answers(id integer); CREATE TABLE assessment.assessment_domain_results(id integer)')
        cur.execute('INSERT INTO assessment.assessments VALUES (42)')
        cur.execute(migration)
        cur.execute(migration)
        cur.execute('SELECT id FROM assessment_legacy.assessments')
        assert cur.fetchone()['id']==42
        cur.execute("SELECT to_regnamespace('development') AS old_schema")
        assert cur.fetchone()['old_schema'] is None
        cur.execute('DROP SCHEMA assessment_legacy CASCADE')
    assert s.get_content(db,item['id'])['payload']==item['payload']
    assert s.get_question_set(db,qs['id'])['id']==qs['id']


def test_parent_audit_keeps_legacy_entity_names_visible(db,actor):
    qs,item=small_workspace(db,actor)
    with db,db.cursor() as cur:
        cur.execute("UPDATE admin.admin_audit_logs SET entity_type='development.content_item' WHERE entity_id=%s",(str(item['id']),))
    assert any(row['action']=='import' for row in s.audit_rows(db,qs['id']))


@pytest.mark.parametrize('change',[{'age_months':4},{'set_version':'other'},{'locale':'en-US'},{'set_source_name':'Nguồn khác'}])
def test_import_rejects_inconsistent_set_metadata_within_file(change):
    first=transfer.template()[0];second=copy.deepcopy(first)
    second.update(stable_code='BLK-2-MAU-02',order_index=first['order_index']+1,**change)
    _,errors=transfer.normalize([first,second])
    assert errors and errors[0]['row']==2


@pytest.mark.parametrize('change',[{'order_index':1.5},{'order_index':True},{'source_domain':'cognitive'},{'set_source_name':'   '}])
def test_import_rejects_invalid_identity_domain_and_numbers(change):
    row=transfer.template()[0];row.update(change)
    assert transfer.normalize([row])[1]


def test_import_preview_detects_existing_set_identity_collision_before_commit(db,actor):
    qs,item=small_workspace(db,actor)
    row=transfer.template()[0];row.update(set_code='another-set',stable_code='BLK-2-OTHER')
    checked=transfer.preview(db,[{},row])
    assert any(x['row']==2 and 'phiên bản' in x['message'] for x in checked['errors'])
    with pytest.raises(HTTPException) as rejected:transfer.commit(db,actor,[row],checked['fingerprint'])
    assert rejected.value.status_code==422
    assert len(s.list_question_sets(db))==1 and len(s.list_content_revisions(db,item['id']))==1


def test_export_import_preserves_set_source_and_creates_drafts_only(db,actor):
    qs,item=small_workspace(db,actor)
    row=transfer.exported(db,qs['id'],'skill')[0]
    assert row['set_source_name']=='Nguồn bộ kiểm thử'
    row.update(stable_code='BLK-2-CLONE',set_code='clone-set',set_version='clone-v1')
    checked=transfer.preview(db,[row]);assert not checked['errors'],checked['errors']
    transfer.commit(db,actor,checked['rows'],checked['fingerprint'])
    clone=next(x for x in s.list_question_sets(db) if x['code']=='clone-set')
    assert clone['source_name']==qs['source_name']
    assert clone['status']=='draft' and clone['is_active'] is False
    assert s.list_content(db,clone['id'])[0]['published_revision'] is None


def test_preview_http_validates_inputs_and_missing_or_deleted_sets_without_writes(db,actor):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.features.assessment.admin.router import admin_router,admin
    from app.core.database import get_db
    qs,item=small_workspace(db,actor,with_advice=True)
    app=FastAPI();app.include_router(admin_router);app.dependency_overrides[admin]=lambda:actor
    def connection():yield db
    app.dependency_overrides[get_db]=connection
    body={'question_set_id':str(qs['id']),'answers':{item['stable_code']:'achieved'},'regression':'no','caregiver_concern':'no'}
    with TestClient(app) as client:
        assert client.post('/admin/assessment/preview-result',json=body).status_code==200
        missing=client.post('/admin/assessment/preview-result',json={**body,'answers':{}})
        assert missing.status_code==422 and 'thiếu 1' in missing.json()['detail']
        assert client.post('/admin/assessment/preview-result',json={**body,'regression':'invalid'}).status_code==422
        assert client.post('/admin/assessment/preview-result',json={**body,'answers':{item['stable_code']:'invalid'}}).status_code==422
        assert client.get('/admin/assessment/question-sets/'+str(uuid4())+'/content').status_code==404
        advice=s.list_content(db,kind='advice')[0]
        s.delete_content(db,actor,advice['id'])
        absent=client.post('/admin/assessment/preview-result',json=body)
        assert absent.status_code==422 and '6 mẫu' in absent.json()['detail']
        s.restore_content(db,actor,advice['id'])
        empty=client.post('/admin/assessment/question-sets',json={'code':'empty-set','ageMonths':2,'version':'empty-v1','sourceName':'Nguồn thử'})
        assert empty.status_code==201
        no_questions=client.post('/admin/assessment/preview-result',json={**body,'question_set_id':empty.json()['id'],'answers':{}})
        assert no_questions.status_code==422 and 'ít nhất một câu' in no_questions.json()['detail']
        s.lifecycle(db,actor,'question_set',qs['id'],'delete')
        assert client.post('/admin/assessment/preview-result',json=body).status_code==409
    with db.cursor() as cur:
        cur.execute('SELECT count(*) AS count FROM assessment.assessments')
        assert cur.fetchone()['count']==0


def test_import_allows_existing_legacy_codes_but_rejects_new_ones(db,actor):
    qs,item=small_workspace(db,actor)
    with db,db.cursor() as cur:
        cur.execute('UPDATE assessment.content_items SET stable_code=%s WHERE id=%s',('legacy-2m-question',item['id']))
    row=transfer.exported(db,qs['id'],'skill')[0]
    assert not transfer.preview(db,[row])['errors']
    row.update(stable_code='new-legacy-question',order_index=row['order_index']+1)
    assert any('Câu mới' in x['message'] for x in transfer.preview(db,[row])['errors'])


def test_import_and_revision_preserve_set_locale(db,actor):
    from app.features.assessment.admin.schema import AdminContentCreate
    row=transfer.template()[0];row['locale']='en-US'
    checked=transfer.preview(db,[row]);assert not checked['errors']
    transfer.commit(db,actor,checked['rows'],checked['fingerprint'])
    qs=s.list_question_sets(db)[0];item=s.list_content(db,qs['id'])[0]
    assert s.list_content_revisions(db,item['id'])[0]['locale']=='en-US'
    edited=s.create_content_revision(db,actor,item['id'],AdminContentRevisionCreate(expectedRevision=1,payload=item['payload'],sourceRefs=item['source_refs']))
    assert s.list_content_revisions(db,edited['id'])[0]['locale']=='en-US'
    created=s.create_content(db,actor,qs['id'],AdminContentCreate(stableCode='BLK-2-LOCALE',appDomain='fine_motor',orderIndex=99,payload=item['payload']))
    assert s.list_content_revisions(db,created['id'])[0]['locale']=='en-US'


@pytest.mark.parametrize('change',[{'order_index':1},{'app_domain':'cognitive'},{'set_code':'not-allowed'}])
def test_import_advice_cannot_acquire_question_metadata(change):
    row=transfer.template('advice')[0];row.update(change)
    assert transfer.normalize([row])[1]


def test_unchanged_incomplete_legacy_draft_can_roundtrip_but_cannot_publish_or_change(db,actor):
    qs,item=small_workspace(db,actor)
    legacy={'prompt':'Legacy question without current required fields','answerOptions':['A','B','C']}
    with db,db.cursor() as cur:
        cur.execute('INSERT INTO assessment.content_revisions(content_item_id,revision,payload,source_refs,created_by) VALUES (%s,2,%s::jsonb,%s::jsonb,%s)',(item['id'],__import__('json').dumps(legacy),'[]',actor['id']))
        cur.execute('UPDATE assessment.content_items SET stable_code=%s,current_revision=2 WHERE id=%s',('legacy-incomplete',item['id']))
    rows=transfer.exported(db,qs['id'],'skill')
    checked=transfer.preview(db,rows);assert not checked['errors'],checked['errors']
    assert transfer.commit(db,actor,checked['rows'],checked['fingerprint'])=={'created':0,'revised':0,'unchanged':1}
    assert len(s.list_content_revisions(db,item['id']))==2
    with pytest.raises(HTTPException):s.release_content(db,actor,item['id'],2)
    rows[0]['payload']['prompt']='Changed but still incomplete legacy question'
    assert transfer.preview(db,rows)['errors']
