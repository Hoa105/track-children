"""Normalized development content administration. All authenticated admins are equal."""
import csv
import hashlib
import io
import json
import re
from urllib.parse import urlparse
from uuid import UUID
from fastapi import HTTPException
from psycopg2 import errors
from psycopg2.extras import register_uuid

register_uuid()

AGES = (2,4,6,9,12,15,18,24,30,36,48,60)
DOMAINS = ('gross_motor','fine_motor','language_communication','cognitive','social_emotional')
REVIEW_TYPES = ('medical','language','media_rights','qa')
VARIANTS = {
 'CONTACT_REGRESSION_YES': ('ADVICE_CONTACT_HEALTHCARE',1,'regression == yes'),
 'CONTACT_REGRESSION_UNSURE': ('ADVICE_CONTACT_HEALTHCARE',2,'regression == unsure'),
 'CONTACT_NOT_YET': ('ADVICE_CONTACT_HEALTHCARE',3,'not_yet_count >= 1'),
 'CONTACT_CONCERN_ONLY': ('ADVICE_CONTACT_HEALTHCARE',4,'caregiver_concern == yes'),
 'OBSERVE_UNCHECKED': ('ADVICE_OBSERVE_SKILLS',10,'not_observed_count >= 1'),
 'CONTINUE_MONITORING': ('ADVICE_CONTINUE_MONITORING',20,'all_achieved && regression == no && caregiver_concern == no'),
}
SET_SELECT = '''SELECT qs.id,qs.code,qs.age_months,qs.version,qs.locale,qs.source_name,
 qs.status,qs.is_active,qs.deleted_at,qs.created_by,qs.created_at,
 GREATEST(qs.updated_at,(SELECT MAX(changed.updated_at) FROM development.content_items changed
 WHERE changed.question_set_id=qs.id)) AS updated_at,
 count(ci.id)::int AS content_count,
 count(ci.id) FILTER (WHERE ci.published_revision IS NOT NULL)::int AS published_count,
 count(ci.id) FILTER (WHERE ci.published_revision IS NOT NULL AND ci.is_active)::int AS visible_question_count
 FROM development.question_sets qs LEFT JOIN development.content_items ci
 ON ci.question_set_id=qs.id AND ci.deleted_at IS NULL'''
CONTENT_SELECT = '''SELECT ci.*, cr.payload, cr.source_refs,
 cr.created_at AS revision_created_at FROM development.content_items ci
 JOIN development.content_revisions cr ON cr.content_item_id=ci.id AND cr.revision=ci.current_revision'''

def fail(message, code=422):
    raise HTTPException(code, message)

def one(cur, sql, params=()):
    cur.execute(sql,params)
    row=cur.fetchone()
    if row is None: fail('Không tìm thấy nội dung',404)
    return row

def actor_id(actor):
    return actor['id'] if isinstance(actor,dict) else None

def log(cur, actor, action, entity, entity_id, before=None, after=None):
    cur.execute('''INSERT INTO admin.admin_audit_logs
      (admin_user_id,action,entity_type,entity_id,before_data,after_data)
      VALUES (%s,%s,%s,%s,%s::jsonb,%s::jsonb)''',
      (actor_id(actor),action,'development.'+entity,str(entity_id),
       json.dumps(before,default=str) if before is not None else None,
       json.dumps(after,default=str) if after is not None else None))

def integrity(error):
    if isinstance(error,errors.UniqueViolation): fail('Mã, phiên bản hoặc thứ tự đã tồn tại',409)
    if isinstance(error,errors.ForeignKeyViolation): fail('Dữ liệu đang được tham chiếu',409)
    fail('Dữ liệu không hợp lệ')

def lock_set(cur, set_id):
    return one(cur,'SELECT * FROM development.question_sets WHERE id=%s FOR UPDATE',(set_id,))

def lock_item(cur,item_id):
    # Serialize all mutations in a set with publication and import.
    item=one(cur,'SELECT question_set_id FROM development.content_items WHERE id=%s',(item_id,))
    if item['question_set_id']: lock_set(cur,item['question_set_id'])
    return one(cur,'SELECT * FROM development.content_items WHERE id=%s FOR UPDATE',(item_id,))

def list_question_sets(conn,status_filter=None):
    with conn.cursor() as cur:
        cur.execute(SET_SELECT+(' WHERE qs.status=%s' if status_filter else '')+' GROUP BY qs.id ORDER BY qs.age_months,qs.version DESC', (status_filter,) if status_filter else ())
        return cur.fetchall()

def get_question_set(conn,set_id):
    with conn.cursor() as cur:
        return one(cur,SET_SELECT+' WHERE qs.id=%s GROUP BY qs.id',(set_id,))

def create_question_set(conn,actor,body):
    try:
        with conn,conn.cursor() as cur:
            row=one(cur,'''INSERT INTO development.question_sets(code,age_months,version,locale,source_name,created_by)
              VALUES (%s,%s,%s,%s,%s,%s) RETURNING *''',(body.code,body.age_months,body.version,body.locale,body.source_name,actor_id(actor)))
            log(cur,actor,'create','question_set',row['id'],after=row)
            row.update(content_count=0,published_count=0)
            return row
    except errors.IntegrityError as error: integrity(error)

def update_question_set(conn,actor,set_id,body):
    with conn,conn.cursor() as cur:
        before=lock_set(cur,set_id)
        if before['deleted_at']: fail('Khôi phục bộ câu hỏi trước khi sửa',409)
        if body.source_name is not None:
            cur.execute('UPDATE development.question_sets SET source_name=%s,updated_at=now() WHERE id=%s',(body.source_name,set_id))
            log(cur,actor,'update','question_set',set_id,before,body.model_dump())
    return get_question_set(conn,set_id)

def list_content(conn,question_set_id=None,kind=None,active_only=False):
    clauses=[]; params=[]
    if question_set_id: clauses.append('ci.question_set_id=%s'); params.append(question_set_id)
    if kind: clauses.append('ci.kind=%s'); params.append(kind)
    if active_only: clauses.append('ci.is_active AND ci.deleted_at IS NULL')
    with conn.cursor() as cur:
        cur.execute(CONTENT_SELECT+(' WHERE '+' AND '.join(clauses) if clauses else '')+' ORDER BY ci.order_index NULLS LAST,ci.stable_code',params)
        return cur.fetchall()

def get_content(conn,item_id):
    with conn.cursor() as cur: return one(cur,CONTENT_SELECT+' WHERE ci.id=%s',(item_id,))

def list_content_revisions(conn,item_id):
    with conn.cursor() as cur:
        one(cur,'SELECT id FROM development.content_items WHERE id=%s',(item_id,))
        cur.execute('SELECT * FROM development.content_revisions WHERE content_item_id=%s ORDER BY revision DESC',(item_id,))
        return cur.fetchall()

def validate_media(media, strict=False):
    entries=media if isinstance(media,list) else ([] if media is None else [media])
    if len(entries)>5: fail('Mỗi câu tối đa 5 media')
    for entry in entries:
        if not isinstance(entry,dict) or entry.get('type') not in ('none','image','youtube'): fail('Loại media không hợp lệ')
        if entry['type']=='none': continue
        for key in ('url','source_page'):
            value=entry.get(key)
            if not value and key=='source_page': continue
            if not isinstance(value,str): fail('URL media phải là chuỗi HTTPS')
            parsed=urlparse(value or '')
            host=(parsed.hostname or '').lower()
            allowed=any(host==domain or host.endswith('.'+domain) for domain in ('cdc.gov','youtube.com','youtube-nocookie.com','youtu.be'))
            if parsed.scheme!='https' or not allowed or parsed.username or parsed.password or parsed.port not in (None,443): fail('Media chỉ nhận URL HTTPS của CDC hoặc YouTube, không chứa tài khoản')
        if strict and not str(entry.get('alt') or entry.get('caption') or '').strip(): fail('Nhập mô tả ảnh/video')
        if strict and not str(entry.get('attribution') or '').strip(): fail('Nhập ghi công nguồn media')
        if entry['type']=='youtube' and not re.fullmatch(r'[A-Za-z0-9_-]{11}',entry.get('youtube_id') or ''): fail('YouTube ID phải có 11 ký tự')

def _validate_payload(payload,kind='skill',stable_code=None):
    if not isinstance(payload,dict): fail('Nội dung phải là đối tượng JSON')
    if kind=='advice':
        variant=payload.get('variant_id')
        if not isinstance(variant,str) or variant not in VARIANTS or (stable_code and variant!=stable_code): fail('Mẫu lời khuyên không hợp lệ')
        expected=VARIANTS[variant]
        if (payload.get('advice_key'),payload.get('variant_priority'),payload.get('match_condition'))!=expected: fail('Không được thay đổi điều kiện chọn mẫu lời khuyên')
        for key in ('title','body_text','tts_text','cta_label','action_kind'):
            if not isinstance(payload.get(key),str) or not payload[key].strip(): fail('Mẫu lời khuyên thiếu trường '+key)
        return
    question=payload.get('question_vi') or payload.get('prompt')
    if not isinstance(question,str) or len(question.strip())<10: fail('Câu hỏi phải có ít nhất 10 ký tự')
    if not isinstance(payload.get('instruction_vi'),str) or not payload['instruction_vi'].strip(): fail('Nhập hướng dẫn quan sát câu hỏi')
    options=payload.get('answer_options')
    if not isinstance(options,list) or len(options)!=3 or any(not isinstance(x,dict) for x in options): fail('Câu hỏi cần đúng 3 đáp án cố định')
    if any(not isinstance(x.get('value'),str) for x in options) or {x.get('value') for x in options}!={'achieved','not_yet','not_observed'}: fail('Không được thay đổi 3 mã đáp án cố định')
    if any(not isinstance(x.get('label'),str) or not x['label'].strip() for x in options): fail('Nhãn đáp án không được trống')
    try: validate_media(payload.get('media',[]))
    except ValueError: fail('URL media không hợp lệ')

def create_content(conn,actor,set_id,body):
    try:
        if body.kind!='skill': fail('Chỉ thêm câu hỏi vào bộ tuổi')
        if body.app_domain not in DOMAINS: fail('Chọn một trong 5 lĩnh vực phát triển')
        _validate_payload(body.payload)
        with conn,conn.cursor() as cur:
            qs=lock_set(cur,set_id)
            if qs['deleted_at']: fail('Không thêm câu vào bộ đã xóa',409)
            code=body.stable_code.upper()
            if not re.fullmatch(r'BLK-'+str(qs['age_months'])+r'-[A-Z0-9_-]+',code): fail('Câu tự biên soạn phải dùng mã BLK-'+str(qs['age_months'])+'-...')
            payload={**body.payload,'source_name':'app_authored'}
            row=one(cur,'''INSERT INTO development.content_items(kind,stable_code,question_set_id,source_domain,app_domain,order_index,created_by,updated_by)
              VALUES ('skill',%s,%s,%s,%s,%s,%s,%s) RETURNING id''',
              (code,set_id,body.source_domain,body.app_domain,body.order_index,actor_id(actor),actor_id(actor)))
            cur.execute('INSERT INTO development.content_revisions(content_item_id,revision,payload,source_refs,created_by) VALUES (%s,1,%s::jsonb,%s::jsonb,%s)',(row['id'],json.dumps(payload),json.dumps(body.source_refs),actor_id(actor)))
            log(cur,actor,'create','content_item',row['id'],after={'code':code})
        return get_content(conn,row['id'])
    except errors.IntegrityError as error: integrity(error)

def create_content_revision(conn,actor,item_id,body):
    try:
        with conn,conn.cursor() as cur:
            item=lock_item(cur,item_id)
            if item['deleted_at']: fail('Khôi phục nội dung trước khi sửa',409)
            if item['current_revision']!=body.expected_revision: fail('Nội dung đã thay đổi. Tải lại trước khi lưu',409)
            if item['kind']=='advice' and body.app_domain is not None: fail('Mẫu lời khuyên không gắn lĩnh vực')
            if item['published_revision'] and body.app_domain is not None and body.app_domain!=item['app_domain']:
                fail('Không đổi lĩnh vực câu đã công bố. Tạo câu mới để giữ đúng lịch sử',409)
            if item['stable_code'].startswith('BLK-'):
                body.payload['source_name']='app_authored'
            _validate_payload(body.payload,item['kind'],item['stable_code'])
            if item['kind']=='advice':
                old=one(cur,'SELECT payload FROM development.content_revisions WHERE content_item_id=%s AND revision=%s',(item_id,item['current_revision']))['payload']
                if body.payload.get('action_kind')!=old.get('action_kind'): fail('Không được thay đổi hành động hệ thống của mẫu lời khuyên')
            revision=item['current_revision']+1
            cur.execute('INSERT INTO development.content_revisions(content_item_id,revision,payload,source_refs,created_by) VALUES (%s,%s,%s::jsonb,%s::jsonb,%s)',(item_id,revision,json.dumps(body.payload),json.dumps(body.source_refs),actor_id(actor)))
            source_domain='movement_physical' if body.app_domain in ('gross_motor','fine_motor') else body.app_domain
            cur.execute('''UPDATE development.content_items SET current_revision=%s,updated_by=%s,updated_at=now(),
             app_domain=COALESCE(%s,app_domain),source_domain=COALESCE(%s,source_domain) WHERE id=%s''',(revision,actor_id(actor),body.app_domain,source_domain,item_id))
            log(cur,actor,'create_revision','content_item',item_id,{'revision':item['current_revision']},{'revision':revision})
        return get_content(conn,item_id)
    except errors.IntegrityError as error: integrity(error)

def latest_reviews(cur,item_id,revision):
    cur.execute('''SELECT DISTINCT ON (review_type) review_type,decision,note,evidence_ref,reviewed_at,reviewer_id
     FROM development.content_reviews WHERE content_item_id=%s AND revision=%s ORDER BY review_type,reviewed_at DESC,id DESC''',(item_id,revision))
    return {r['review_type']:dict(r) for r in cur.fetchall()}

def blockers(cur,item,revision=None):
    rev=revision or item['current_revision']
    result=[]
    content=one(cur,'SELECT payload,source_refs FROM development.content_revisions WHERE content_item_id=%s AND revision=%s',(item['id'],rev))
    payload=content['payload']
    try: _validate_payload(payload,item['kind'],item['stable_code'])
    except HTTPException as error: result.append(str(error.detail))
    if not content['source_refs'] or not any(isinstance(ref,dict) and any(str(ref.get(k) or '').strip() for k in ('url','document','organization','label')) for ref in content['source_refs']):
        result.append('Thiếu nguồn tham khảo')
    if item['kind']=='skill':
        try: validate_media(payload.get('media'), strict=True)
        except (HTTPException, ValueError) as error: result.append(str(getattr(error, 'detail', 'URL media kh?ng h?p l?')))
        if item['app_domain'] not in DOMAINS: result.append('Chưa chọn lĩnh vực')
        if item['stable_code'].startswith('CDC-'):
            if not str(payload.get('source_pdf') or '').strip(): result.append('Thiếu tài liệu CDC gốc')
            if not str(payload.get('source_excerpt') or '').strip(): result.append('Thiếu trích đoạn CDC gốc')
            try:
                if int(payload.get('source_page') or 0)<1: result.append('Trang tài liệu phải từ 1')
            except (ValueError,TypeError): result.append('Trang tài liệu phải là số nguyên từ 1')
        for key,label in [('skill_name','tên kỹ năng'),('not_yet_comment','nhận xét chưa làm được'),('not_observed_comment','nhận xét chưa quan sát'),('observation_guide','cách quan sát kỹ năng'),('tts_short_text','lời đọc kỹ năng')]:
            if not isinstance(payload.get(key),str) or not payload[key].strip(): result.append('Thiếu '+label)
    return result

def get_gate(conn,item_id):
    with conn.cursor() as cur:
        item=one(cur,'SELECT * FROM development.content_items WHERE id=%s',(item_id,))
        reasons=blockers(cur,item)
        if item['deleted_at']: reasons.append('Nội dung đã xóa')
        return {'revision':item['current_revision'],'blockers':reasons,'reviews':latest_reviews(cur,item_id,item['current_revision'])}

def create_review(conn,reviewer_id,actor,item_id,body):
    with conn,conn.cursor() as cur:
        item=lock_item(cur,item_id)
        if item['deleted_at']: fail('Không duyệt nội dung đã xóa',409)
        if item['current_revision']!=body.revision: fail('Phiên bản đã thay đổi. Tải lại trước khi duyệt',409)
        if body.decision=='approved' and not (body.evidence_ref or '').strip(): fail('Nhập căn cứ phê duyệt: tài liệu hoặc xác nhận người kiểm tra')
        cur.execute('''INSERT INTO development.content_reviews(content_item_id,revision,review_type,decision,reviewer_id,evidence_ref,note)
         VALUES (%s,%s,%s,%s,%s,%s,%s)''',(item_id,body.revision,body.review_type,body.decision,reviewer_id,body.evidence_ref,body.note))
        log(cur,actor,'review','content_item',item_id,after=body.model_dump())
        return {'saved':True}

def list_review_queue(conn,question_set_id=None,review_type=None):
    result=[]
    with conn.cursor() as cur:
        for item in list_content(conn,question_set_id):
            if item['deleted_at']: continue
            reviews=latest_reviews(cur,item['id'],item['current_revision'])
            if review_type and reviews.get(review_type,{}).get('decision')=='approved': continue
            result.append(dict(content_item_id=item['id'],stable_code=item['stable_code'],kind=item['kind'],question_set_id=item['question_set_id'],revision=item['current_revision'],payload=item['payload'],source_refs=item['source_refs'],reviews=reviews,created_at=item['revision_created_at']))
    return result

def publish_content(conn,actor,item_id,expected_revision):
    with conn,conn.cursor() as cur:
        item=lock_item(cur,item_id)
        if item['deleted_at']: fail('Khôi phục nội dung trước khi công bố',409)
        if item['current_revision']!=expected_revision: fail('Phiên bản đã thay đổi. Tải lại trước khi công bố',409)
        reasons=blockers(cur,item)
        if reasons: fail('; '.join(reasons),409)
        cur.execute('UPDATE development.content_items SET published_revision=current_revision,updated_at=now() WHERE id=%s',(item_id,))
        log(cur,actor,'publish','content_item',item_id,after={'revision':expected_revision})
    return get_content(conn,item_id)

def release_content(conn,actor,item_id,expected_revision):
    """Publish valid content and enable it atomically without a review workflow."""
    with conn,conn.cursor() as cur:
        item=lock_item(cur,item_id)
        if item['deleted_at']: fail('Khôi phục nội dung trước khi xuất bản',409)
        if item['kind']=='skill':
            parent=lock_set(cur,item['question_set_id'])
            if parent['deleted_at']: fail('Khôi phục bộ câu hỏi trước khi xuất bản câu',409)
        if item['current_revision']!=expected_revision: fail('Phiên bản đã thay đổi. Tải lại trước khi xuất bản',409)
        reasons=blockers(cur,item)
        if reasons: fail('; '.join(reasons),409)
        cur.execute('UPDATE development.content_items SET published_revision=current_revision,is_active=true,updated_at=now() WHERE id=%s',(item_id,))
        log(cur,actor,'release','content_item',item_id,after={'revision':expected_revision,'is_active':True})
    return get_content(conn,item_id)

def _publish_question_set(cur,actor,set_id):
    qs=lock_set(cur,set_id)
    if qs['deleted_at']: fail('Khôi phục bộ trước khi công bố',409)
    cur.execute('SELECT * FROM development.content_items WHERE question_set_id=%s AND deleted_at IS NULL ORDER BY id FOR UPDATE',(set_id,))
    items=cur.fetchall()
    if not items: fail('Bộ chưa có câu hỏi')
    reasons=[]
    for item in items:
        problems=blockers(cur,item)
        if problems: reasons.append(item['stable_code']+': '+', '.join(problems))
    if reasons: fail('; '.join(reasons),409)
    cur.execute('UPDATE development.content_items SET published_revision=current_revision,updated_at=now() WHERE question_set_id=%s AND deleted_at IS NULL',(set_id,))
    cur.execute("UPDATE development.question_sets SET status='published',updated_at=now() WHERE id=%s",(set_id,))
    log(cur,actor,'publish','question_set',set_id,after={'count':len(items)})
    return {'question_set_id':set_id,'status':'published','published_revision_count':len(items)}



def publish_question_set(conn,actor,set_id):
    with conn,conn.cursor() as cur:
        return _publish_question_set(cur,actor,set_id)

def lifecycle(conn,actor,entity,entity_id,action,active=None):
    table='question_sets' if entity=='question_set' else 'content_items'
    with conn,conn.cursor() as cur:
        item=lock_set(cur,entity_id) if entity=='question_set' else lock_item(cur,entity_id)
        if action=='availability':
            if item['deleted_at']: fail('Khôi phục trước khi bật sử dụng',409)
            if active:
                if entity=='question_set':
                    if item['status']!='published': fail('Công bố bộ trước khi bật sử dụng',409)
                    cur.execute('SELECT * FROM development.content_items WHERE question_set_id=%s AND is_active AND deleted_at IS NULL',(entity_id,))
                    children=cur.fetchall()
                    if not children: fail('Bật ít nhất một câu đã công bố trước khi bật bộ',409)
                    for child in children:
                        if not child['published_revision'] or blockers(cur,child,child['published_revision']): fail('Có câu chưa đủ điều kiện sử dụng',409)
                    cur.execute("SELECT * FROM development.content_items WHERE kind='advice' AND deleted_at IS NULL AND is_active")
                    advice=cur.fetchall()
                    if {a['stable_code'] for a in advice}!=set(VARIANTS): fail('Cần đủ 6 mẫu lời khuyên đã công bố và bật sử dụng',409)
                    for a in advice:
                        if not a['published_revision'] or blockers(cur,a,a['published_revision']): fail('Mẫu lời khuyên chưa đủ điều kiện sử dụng',409)
                elif not item['published_revision'] or blockers(cur,item,item['published_revision']): fail('Công bố nội dung hợp lệ trước khi bật sử dụng',409)
            cur.execute(f'UPDATE development.{table} SET is_active=%s,updated_at=now() WHERE id=%s',(active,entity_id))
        elif action=='delete':
            cur.execute(f'UPDATE development.{table} SET is_active=false,deleted_at=COALESCE(deleted_at,now()),updated_at=now() WHERE id=%s',(entity_id,))
        else:
            if not item['deleted_at']: fail('Nội dung chưa bị xóa',409)
            cur.execute(f'UPDATE development.{table} SET is_active=false,deleted_at=NULL,updated_at=now() WHERE id=%s',(entity_id,))
        log(cur,actor,action,entity,entity_id,item,{'is_active':active if action=='availability' else False})
    return {'saved':True}

def delete_content(conn,actor,item_id): return lifecycle(conn,actor,'content_item',item_id,'delete')
def restore_content(conn,actor,item_id): return lifecycle(conn,actor,'content_item',item_id,'restore')

def reorder(conn,actor,set_id,ids):
    if len(ids)!=len(set(ids)): fail('Danh sách thứ tự có câu bị trùng')
    with conn,conn.cursor() as cur:
        qs=lock_set(cur,set_id)
        if qs['deleted_at']: fail('Khôi phục bộ trước khi sắp xếp',409)
        cur.execute('SELECT id FROM development.content_items WHERE question_set_id=%s AND deleted_at IS NULL FOR UPDATE',(set_id,))
        existing={r['id'] for r in cur.fetchall()}
        if set(ids)!=existing: fail('Danh sách câu đã thay đổi. Tải lại trước khi sắp xếp',409)
        # Temporary negative positions avoid the partial unique order index.
        cur.execute('UPDATE development.content_items SET order_index=-order_index-10000 WHERE question_set_id=%s AND deleted_at IS NULL',(set_id,))
        for index,item_id in enumerate(ids,1): cur.execute('UPDATE development.content_items SET order_index=%s,updated_at=now() WHERE id=%s',(index,item_id))
        log(cur,actor,'reorder','question_set',set_id,after={'ids':[str(x) for x in ids]})
    return {'saved':True}

def audit_rows(conn,item_id):
    with conn.cursor() as cur:
        cur.execute('''SELECT a.id,a.action,a.created_at,a.before_data,a.after_data,u.full_name AS actor
         FROM admin.admin_audit_logs a LEFT JOIN admin.admin_users u ON u.id=a.admin_user_id
         WHERE a.entity_id=%s AND a.entity_type LIKE 'development.%%' ORDER BY a.created_at DESC LIMIT 100''',(str(item_id),))
        return cur.fetchall()


def release_question_set(conn,actor,set_id):
    """Publish and enable one set atomically. Previously hidden questions stay hidden."""
    with conn,conn.cursor() as cur:
        qs=lock_set(cur,set_id)
        if qs['deleted_at']: fail('Khôi phục bộ trước khi xuất bản',409)
        cur.execute("SELECT * FROM development.content_items WHERE kind='advice' AND deleted_at IS NULL AND is_active ORDER BY id FOR SHARE")
        advice=cur.fetchall()
        if {item['stable_code'] for item in advice}!=set(VARIANTS):
            fail('Hoàn tất và hiển thị đủ 6 mẫu lời khuyên trước khi xuất bản bộ',409)
        for item in advice:
            if not item['published_revision'] or blockers(cur,item,item['published_revision']):
                fail('Có mẫu lời khuyên chưa đủ điều kiện xuất bản',409)
        cur.execute('SELECT id FROM development.content_items WHERE question_set_id=%s AND deleted_at IS NULL AND published_revision IS NULL ORDER BY id FOR UPDATE',(set_id,))
        newly_published=[row['id'] for row in cur.fetchall()]
        _publish_question_set(cur,actor,set_id)
        # Newly published questions become available; intentional hiding of old ones is preserved.
        if newly_published:
            cur.execute('UPDATE development.content_items SET is_active=true,updated_at=now() WHERE id=ANY(%s)',(newly_published,))
        cur.execute('SELECT count(*) AS count FROM development.content_items WHERE question_set_id=%s AND deleted_at IS NULL AND is_active AND published_revision IS NOT NULL',(set_id,))
        if cur.fetchone()['count']==0: fail('Chọn ít nhất một câu hiển thị trong bộ trước khi xuất bản',409)
        cur.execute("UPDATE development.question_sets SET is_active=true,status='published',updated_at=now() WHERE id=%s",(set_id,))
        log(cur,actor,'release','question_set',set_id,qs,{'is_active':True,'status':'published'})
    return get_question_set(conn,set_id)
