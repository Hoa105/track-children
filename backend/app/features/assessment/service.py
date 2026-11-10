"""Parent assessment workflow using published revisions and immutable results."""
import datetime as dt
import hashlib
import json
from uuid import uuid4
from . import content
from .rule_engine import AGE_MONTHS
from .rule_engine import add_calendar_months, evaluate
from .advice_resolver import resolve_advice, VERSION
from .result_presenter import build_result_view_model


def today(offset=420):
    return (dt.datetime.now(dt.timezone.utc)+dt.timedelta(minutes=offset)).date()


def age_for(birth,day):
    if day<birth:return None
    if day>=add_calendar_months(birth,61):return None
    return next((m for m in reversed(AGE_MONTHS) if add_calendar_months(birth,m)<=day),None)


def _questions(cur,attempt_id):
    cur.execute("""SELECT q.content_item_id AS id,ci.stable_code AS code,ci.app_domain AS domain,
      q.revision,q.order_index,r.payload,r.source_refs FROM assessment.assessment_questions q
      JOIN assessment.content_items ci ON ci.id=q.content_item_id
      JOIN assessment.content_revisions r ON r.content_item_id=q.content_item_id AND r.revision=q.revision
      WHERE q.assessment_id=%s ORDER BY q.order_index""",(attempt_id,))
    return cur.fetchall()


def _attempt(cur,child_id,attempt_id,lock=False):
    return content.one(cur,"SELECT a.*,qs.age_months,qs.version AS set_version FROM assessment.assessments a JOIN assessment.question_sets qs ON qs.id=a.question_set_id WHERE a.id=%s AND a.child_id=%s"+(' FOR UPDATE OF a' if lock else ''),(attempt_id,child_id))


def _serialize(cur,row,current_age):
    cur.execute('SELECT ci.stable_code,a.answer FROM assessment.assessment_answers a JOIN assessment.content_items ci ON ci.id=a.content_item_id WHERE a.assessment_id=%s',(row['id'],))
    answers={x['stable_code']:x['answer'] for x in cur.fetchall()}
    cur.execute('SELECT view_snapshot FROM assessment.assessment_results WHERE assessment_id=%s',(row['id'],))
    result=cur.fetchone()
    return {'id':row['id'],'age_months':row['age_months'],'status':row['status'],'started_at':row['started_at'],
      'completed_at':row['completed_at'],'version':row['update_version'],'answers':answers,
      'regression':row['regression_response'],'caregiver_concern':row['caregiver_concern'],
      'editable':row['status']=='in_progress' and row['age_months']==current_age,
      'questions':result['view_snapshot']['question_snapshot'] if result else _questions(cur,row['id']),'result':result['view_snapshot'] if result else None}


def overview(conn,child,offset=420):
    day=today(offset);birth=child['date_of_birth'];age=age_for(birth,day)
    with conn.cursor() as cur:
        cur.execute('SELECT gestational_weeks FROM child.children WHERE id=%s',(child['id'],))
        weeks=cur.fetchone()['gestational_weeks']
        cur.execute("SELECT qs.*, (SELECT count(*) FROM assessment.content_items ci WHERE ci.question_set_id=qs.id AND ci.kind='skill' AND ci.deleted_at IS NULL AND ci.is_active AND ci.published_revision IS NOT NULL) AS count FROM assessment.question_sets qs WHERE qs.age_months=%s AND qs.status='published' AND qs.is_active AND qs.deleted_at IS NULL ORDER BY qs.updated_at DESC,qs.id LIMIT 1",(age,))
        question_set=cur.fetchone()
        cur.execute("SELECT a.id,qs.age_months FROM assessment.assessments a JOIN assessment.question_sets qs ON qs.id=a.question_set_id WHERE a.child_id=%s AND a.status='in_progress' ORDER BY a.started_at DESC",(child['id'],))
        drafts=cur.fetchall()
        draft=next((x for x in drafts if x['age_months']==age),None)
        cur.execute("SELECT a.id,qs.age_months FROM assessment.assessments a JOIN assessment.question_sets qs ON qs.id=a.question_set_id WHERE a.child_id=%s AND a.status='completed' ORDER BY a.completed_at DESC,a.id DESC",(child['id'],))
        completed=cur.fetchall()
        return {'age_months':age,'today':day,'can_edit':child.get('access')=='edit',
          'completed_milestones':sorted({x['age_months'] for x in completed}),
          'latest_completed':next((x for x in completed if x['age_months']==age),None),
          'guidance_required':bool(weeks and weeks<37 and day<add_calendar_months(birth,24)),
          'set':{'id':question_set['id'],'count':question_set['count']} if question_set and question_set['count'] else None,
          'draft':_serialize(cur,_attempt(cur,child['id'],draft['id']),age) if draft else None,
          'past_drafts':[{'id':x['id'],'age_months':x['age_months']} for x in drafts if x['age_months']!=age],
          'milestones':[{'age_months':m,'opens_on':add_calendar_months(birth,m),'closes_on':add_calendar_months(birth,AGE_MONTHS[i+1] if i+1<len(AGE_MONTHS) else 61)} for i,m in enumerate(AGE_MONTHS)]}


def load(conn,child,attempt_id,offset=420):
    with conn.cursor() as cur:return _serialize(cur,_attempt(cur,child['id'],attempt_id),age_for(child['date_of_birth'],today(offset)))


def history(conn,child,age=None,offset=0,limit=20):
    with conn.cursor() as cur:
        cur.execute("""SELECT a.id,qs.age_months,a.completed_at,r.view_snapshot->'sections'->'overview' AS summary,
          (SELECT count(*) FROM assessment.assessments prev JOIN assessment.question_sets pqs ON pqs.id=prev.question_set_id WHERE prev.child_id=a.child_id AND pqs.age_months=qs.age_months AND prev.status='completed' AND (prev.completed_at,prev.id)<=(a.completed_at,a.id)) AS attempt_number
          FROM assessment.assessments a JOIN assessment.question_sets qs ON qs.id=a.question_set_id
          JOIN assessment.assessment_results r ON r.assessment_id=a.id
          WHERE a.child_id=%s AND a.status='completed' AND (%s::int IS NULL OR qs.age_months=%s)
          ORDER BY a.completed_at DESC,a.id DESC LIMIT %s OFFSET %s""",(child['id'],age,age,limit+1,offset))
        rows=cur.fetchall();return {'items':rows[:limit],'has_more':len(rows)>limit}


def start(conn,child,user_id,attempt_id,guidance=False,offset=420):
    with conn,conn.cursor() as cur:
        cur.execute('SELECT id FROM child.children WHERE id=%s FOR UPDATE',(child['id'],))
        cur.execute('SELECT child_id FROM assessment.assessments WHERE id=%s',(attempt_id,))
        old=cur.fetchone()
        if old:
            if old['child_id']!=child['id']:content.fail('Không tìm thấy bài đánh giá',404)
            return _serialize(cur,_attempt(cur,child['id'],attempt_id),age_for(child['date_of_birth'],today(offset)))
        state=overview(conn,child,offset);age=state['age_months']
        if age is None:content.fail('Hiện chưa có mốc đánh giá phù hợp với tuổi của bé',409)
        if state['guidance_required'] and not guidance:content.fail('Cần xác nhận hướng dẫn của nhân viên y tế về cách dùng tuổi cho trẻ sinh non',409)
        if state['draft']:return state['draft']
        if not state['set']:content.fail('Chưa có bộ câu hỏi đang xuất bản cho mốc này',503)
        qs=content.lock_set(cur,state['set']['id'])
        if not qs['is_active'] or qs['deleted_at'] or qs['status']!='published':content.fail('Bộ câu hỏi vừa thay đổi. Vui lòng tải lại',409)
        cur.execute("SELECT * FROM assessment.content_items WHERE question_set_id=%s AND kind='skill' AND is_active AND deleted_at IS NULL AND published_revision IS NOT NULL ORDER BY order_index FOR SHARE",(qs['id'],))
        items=cur.fetchall()
        if not items:content.fail('Bộ câu hỏi chưa có nội dung hiển thị',503)
        for item in items:
            if content.blockers(cur,item,item['published_revision']):content.fail('Nội dung bộ câu hỏi chưa sẵn sàng. Vui lòng thử lại sau',503)
        cur.execute('INSERT INTO assessment.assessments(id,child_id,caregiver_id,question_set_id,birth_date_used) VALUES (%s,%s,%s,%s,%s)',(attempt_id,child['id'],user_id,qs['id'],child['date_of_birth']))
        for i,item in enumerate(items):cur.execute('INSERT INTO assessment.assessment_questions(assessment_id,content_item_id,revision,order_index) VALUES (%s,%s,%s,%s)',(attempt_id,item['id'],item['published_revision'],i))
        return _serialize(cur,_attempt(cur,child['id'],attempt_id),age)


def _editable(row,child,offset):
    if row['status']!='in_progress':content.fail('Bài đã hoàn thành, chỉ có thể xem lại',409)
    if age_for(child['date_of_birth'],today(offset))!=row['age_months']:content.fail('Bé đã sang mốc mới. Bài cũ được giữ để xem; hãy bắt đầu bài ở mốc hiện tại',409)


def save(conn,child,attempt_id,body,offset=420):
    with conn,conn.cursor() as cur:
        row=_attempt(cur,child['id'],attempt_id,True);_editable(row,child,offset)
        if row['update_version']!=body.expected_version:content.fail('Bài đã thay đổi trên thiết bị khác. Tải lại đáp án trước khi lưu',409)
        questions={x['code']:x for x in _questions(cur,attempt_id)}
        if not set(body.answers)<=set(questions):content.fail('Có câu trả lời không thuộc bài đánh giá')
        for code,answer in body.answers.items():
            cur.execute('INSERT INTO assessment.assessment_answers(assessment_id,content_item_id,answer) VALUES (%s,%s,%s) ON CONFLICT (assessment_id,content_item_id) DO UPDATE SET answer=EXCLUDED.answer,answered_at=now()', (attempt_id,questions[code]['id'],answer))
        cur.execute('UPDATE assessment.assessments SET regression_response=%s,caregiver_concern=%s,update_version=update_version+1 WHERE id=%s',(body.regression,body.caregiver_concern,attempt_id))
        return _serialize(cur,_attempt(cur,child['id'],attempt_id),row['age_months'])


def complete(conn,child,attempt_id,version,offset=420):
    with conn,conn.cursor() as cur:
        row=_attempt(cur,child['id'],attempt_id,True)
        if row['status']=='completed':return _serialize(cur,row,row['age_months'])
        _editable(row,child,offset)
        if row['update_version']!=version:content.fail('Bài đã thay đổi. Tải lại trước khi hoàn thành',409)
        attempt=_serialize(cur,row,row['age_months']);questions=attempt['questions']
        if len(attempt['answers'])!=len(questions) or not row['regression_response'] or not row['caregiver_concern']:content.fail('Trả lời đủ các kỹ năng và hai câu hỏi bổ sung trước khi xem kết quả')
        cur.execute("SELECT * FROM assessment.content_items WHERE kind='advice' AND is_active AND deleted_at IS NULL AND published_revision IS NOT NULL ORDER BY id FOR SHARE")
        advice=cur.fetchall()
        if len(advice)!=6 or {x['stable_code'] for x in advice}!=set(content.VARIANTS):content.fail('Nội dung hướng dẫn chưa sẵn sàng. Bài đã lưu, vui lòng thử lại sau',503)
        advice_rows=[]
        for item in advice:
            if content.blockers(cur,item,item['published_revision']):content.fail('Nội dung hướng dẫn chưa sẵn sàng',503)
            payload=content.one(cur,'SELECT payload FROM assessment.content_revisions WHERE content_item_id=%s AND revision=%s',(item['id'],item['published_revision']))['payload']
            advice_rows.append({**payload,'content_version':VERSION})
        fingerprint=hashlib.sha256(json.dumps([(str(q['id']),q['revision']) for q in questions]).encode()).hexdigest()
        # The reference calculation is deterministic. The app adapter above enforces
        # actual published pointers, not the removed editorial approval workflow.
        engine=evaluate(expected_question_ids=[q['code'] for q in questions],answers=attempt['answers'],regression=row['regression_response'],caregiver_concern=row['caregiver_concern'],question_set_age_months=row['age_months'],question_set_version=fingerprint,domain_by_question={q['code']:q['domain'] for q in questions})
        resolved=resolve_advice(step1_result=engine,regression=row['regression_response'],caregiver_concern=row['caregiver_concern'],advice_rows=advice_rows)
        mapped={q['code']:{**q['payload'],'app_domain':q['domain'],'age_months':row['age_months']} for q in questions}
        view=build_result_view_model(step1_result=engine,step3_advice=resolved,skills_by_id=mapped)
        view.pop('preview_diagnostics',None);view['release_status']='published'
        view['question_snapshot']=json.loads(json.dumps(questions,default=str))
        cur.execute('INSERT INTO assessment.assessment_results(assessment_id,rules_version,question_set_version,skill_content_versions,advice_content_versions,engine_snapshot,view_snapshot,snapshot_schema_version,idempotency_key) VALUES (%s,%s,%s,%s::jsonb,%s::jsonb,%s::jsonb,%s::jsonb,%s,%s)',(attempt_id,engine['rules_version'],fingerprint,json.dumps({q['code']:q['revision'] for q in questions}),json.dumps({x['stable_code']:x['published_revision'] for x in advice}),json.dumps(engine),json.dumps(view),view['schema_version'],str(attempt_id)))
        cur.execute("UPDATE assessment.assessments SET status='completed',completed_at=now(),update_version=update_version+1 WHERE id=%s",(attempt_id,))
        return _serialize(cur,_attempt(cur,child['id'],attempt_id),row['age_months'])
