"""Validated, optimistic, transactional content import/export."""
import csv
import copy
import hashlib
import io
import json
from pathlib import Path
from . import service as s

MAX_ROWS=500

def bundled():
    return json.loads((Path(__file__).parent/'data/cdc-draft.json').read_text(encoding='utf-8'))

def template(kind='skill'):
    row=copy.deepcopy(next(item for item in bundled() if item['kind']==kind))
    if kind=='skill':
        row.update(stable_code='BLK-2-MAU-01',set_code='blk-2m-mau',set_version='mau-v1')
        row['payload']['source_name']='app_authored'
    return [row]


def exported(conn,set_id=None,kind=None,set_ids=None):
    rows=[]
    sets={str(x['id']):x for x in s.list_question_sets(conn)}
    for x in s.list_content(conn,set_id,kind):
        qs=sets.get(str(x['question_set_id']))
        if x['deleted_at'] or (qs and qs['deleted_at']): continue
        if set_ids is not None and str(x['question_set_id']) not in {str(value) for value in set_ids}: continue
        rows.append(dict(kind=x['kind'],stable_code=x['stable_code'],age_months=qs['age_months'] if qs else None,
         set_code=qs['code'] if qs else None,set_version=qs['version'] if qs else None,locale=qs['locale'] if qs else 'vi-VN',
         app_domain=x['app_domain'],source_domain=x['source_domain'],order_index=x['order_index'],
         payload=x['payload'],source_refs=x['source_refs']))
    return rows

def fingerprint(conn):
    with conn.cursor() as cur:
        cur.execute('SELECT id,current_revision,published_revision,is_active,deleted_at,updated_at FROM development.content_items ORDER BY id')
        items=cur.fetchall()
        cur.execute('SELECT id,code,updated_at FROM development.question_sets ORDER BY id')
        sets=cur.fetchall()
    return hashlib.sha256(json.dumps([items,sets],default=str,sort_keys=True).encode()).hexdigest()

def normalize(rows):
    if not isinstance(rows,list) or not rows or len(rows)>MAX_ROWS: s.fail('Tệp cần từ 1 đến 500 dòng nội dung')
    errors=[]; normalized=[]; seen=set(); order_seen=set()
    for number,row in enumerate(rows,1):
        try:
            if not isinstance(row,dict): s.fail('Dòng phải là đối tượng')
            x=dict(row)
            for key in ('payload','source_refs'):
                if isinstance(x.get(key),str): x[key]=json.loads(x[key])
            kind=x.get('kind'); code=x.get('stable_code')
            if kind not in ('skill','advice') or not isinstance(code,str) or not s.re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{1,80}',code): s.fail('Loại hoặc mã nội dung không hợp lệ')
            if (kind,code) in seen: s.fail('Mã bị trùng trong tệp')
            seen.add((kind,code))
            s._validate_payload(x.get('payload'),kind,code)
            if kind=='advice':
                expected_action='contact_healthcare' if code.startswith('CONTACT_') else 'observe_skills' if code=='OBSERVE_UNCHECKED' else 'continue_monitoring'
                if x['payload'].get('action_kind')!=expected_action: s.fail('Không được đổi hành động hệ thống của lời khuyên')
            if not isinstance(x.get('source_refs'),list) or any(not isinstance(v,dict) for v in x['source_refs']): s.fail('Nguồn tham khảo phải là danh sách đối tượng')
            if kind=='skill':
                x['age_months']=int(x.get('age_months',0)); x['order_index']=int(x.get('order_index',0))
                if x['age_months'] not in s.AGES or x.get('app_domain') not in s.DOMAINS: s.fail('Tuổi hoặc lĩnh vực không hợp lệ')
                if x.get('source_domain') not in ('social_emotional','language_communication','cognitive','movement_physical'): s.fail('Lĩnh vực nguồn không hợp lệ')
                if not s.re.fullmatch(r'[a-z0-9][a-z0-9_-]{1,60}',x.get('set_code') or '') or not str(x.get('set_version') or '').strip(): s.fail('Thiếu mã hoặc phiên bản bộ')
                if x['order_index']<0: s.fail('Thứ tự phải từ 0')
                order=(x['set_code'],x['order_index'])
                if order in order_seen: s.fail('Trùng thứ tự trong bộ')
                order_seen.add(order)
                if code.startswith('CDC-') and code not in {r['stable_code'] for r in bundled() if r['kind']=='skill'}: s.fail('Mã CDC không có trong tài liệu chuẩn')
            normalized.append(x)
        except (s.HTTPException,ValueError,TypeError) as error:
            errors.append({'row':number,'message':str(getattr(error,'detail',error))})
    return normalized,errors

def preview(conn,rows):
    normalized,errors=normalize(rows)
    changes=[]
    with conn.cursor() as cur:
        for index,x in enumerate(normalized,1):
            cur.execute(s.CONTENT_SELECT+' WHERE ci.kind=%s AND ci.stable_code=%s',(x['kind'],x['stable_code']))
            old=cur.fetchone()
            action='create' if old is None else 'unchanged' if old['payload']==x['payload'] and old['source_refs']==x['source_refs'] else 'revision'
            if old and old['deleted_at']: errors.append({'row':index,'message':x['stable_code']+': cần khôi phục trước khi nhập'})
            if old and old['kind']=='skill':
                qs=s.one(cur,'SELECT code,age_months,version FROM development.question_sets WHERE id=%s',(old['question_set_id'],))
                if (qs['code'],qs['age_months'],qs['version'])!=(x['set_code'],x['age_months'],x['set_version']): errors.append({'row':index,'message':x['stable_code']+': không được chuyển bộ tuổi'})
                if old['order_index']!=x['order_index'] or old['app_domain']!=x['app_domain'] or old['source_domain']!=x['source_domain']: errors.append({'row':index,'message':x['stable_code']+': đổi lĩnh vực/thứ tự trong trang chỉnh sửa trước khi nhập'})
            if x['kind']=='skill':
                cur.execute('SELECT id,age_months,version,deleted_at FROM development.question_sets WHERE code=%s',(x['set_code'],))
                qs=cur.fetchone()
                if qs:
                    if qs['deleted_at'] or (qs['age_months'],qs['version'])!=(x['age_months'],x['set_version']): errors.append({'row':index,'message':'Bộ '+x['set_code']+' đã xóa hoặc khác tuổi/phiên bản'})
                    cur.execute('SELECT stable_code FROM development.content_items WHERE question_set_id=%s AND order_index=%s AND deleted_at IS NULL AND stable_code<>%s',(qs['id'],x['order_index'],x['stable_code']))
                    if cur.fetchone(): errors.append({'row':index,'message':x['stable_code']+': thứ tự đã được câu khác sử dụng'})
            changes.append({'code':x['stable_code'],'action':action,'before':old['payload'] if old else None,'after':x['payload'],'before_sources':old['source_refs'] if old else [],'after_sources':x['source_refs']})
    return {'rows':normalized,'errors':errors,'changes':changes,'fingerprint':fingerprint(conn)}

def commit(conn,actor,rows,expected):
    try:
        with conn,conn.cursor() as cur:
            # Exclusive table locks serialize preview validation with all content writes.
            cur.execute('LOCK TABLE development.question_sets,development.content_items IN EXCLUSIVE MODE')
            if fingerprint(conn)!=expected: s.fail('Dữ liệu đã thay đổi. Xem trước tệp lần nữa',409)
            checked=preview(conn,rows)
            if checked['errors']: s.fail('Tệp còn lỗi. Xem trước và sửa trước khi nhập',422)
            counts={'created':0,'revised':0,'unchanged':0}
            for x in checked['rows']:
                cur.execute(s.CONTENT_SELECT+' WHERE ci.kind=%s AND ci.stable_code=%s',(x['kind'],x['stable_code']))
                old=cur.fetchone()
                if old and old['payload']==x['payload'] and old['source_refs']==x['source_refs']:
                    counts['unchanged']+=1; continue
                if old:
                    item_id=old['id']; revision=old['current_revision']+1; counts['revised']+=1
                    cur.execute('UPDATE development.content_items SET current_revision=%s,updated_by=%s,updated_at=now() WHERE id=%s',(revision,s.actor_id(actor),item_id))
                else:
                    set_id=None
                    if x['kind']=='skill':
                        cur.execute('''INSERT INTO development.question_sets(code,age_months,version,locale,created_by)
                          VALUES (%s,%s,%s,%s,%s) ON CONFLICT (code) DO NOTHING''',(x['set_code'],x['age_months'],x['set_version'],x.get('locale') or 'vi-VN',s.actor_id(actor)))
                        set_id=s.one(cur,'SELECT id FROM development.question_sets WHERE code=%s',(x['set_code'],))['id']
                    item_id=s.one(cur,'''INSERT INTO development.content_items(kind,stable_code,question_set_id,app_domain,source_domain,order_index,created_by,updated_by)
                      VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''',(x['kind'],x['stable_code'],set_id,x.get('app_domain'),x.get('source_domain'),x.get('order_index'),s.actor_id(actor),s.actor_id(actor)))['id']
                    revision=1; counts['created']+=1
                cur.execute('INSERT INTO development.content_revisions(content_item_id,revision,payload,source_refs,created_by) VALUES (%s,%s,%s::jsonb,%s::jsonb,%s)',(item_id,revision,json.dumps(x['payload']),json.dumps(x['source_refs']),s.actor_id(actor)))
                s.log(cur,actor,'import','content_item',item_id,after={'code':x['stable_code'],'revision':revision})
            return counts
    except s.errors.IntegrityError as error: s.integrity(error)

