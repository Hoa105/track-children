"""Validated, optimistic, transactional content import/export."""
import csv
import copy
import hashlib
import io
import json
from pathlib import Path
from . import service as s
from .advice_samples import enrich_advice_row

MAX_ROWS=500

def bundled():
    return [enrich_advice_row(row) for row in json.loads((Path(__file__).parent/'data/cdc-draft.json').read_text(encoding='utf-8'))]

def template(kind='skill'):
    row=copy.deepcopy(next(item for item in bundled() if item['kind']==kind))
    if kind=='skill':
        row.update(stable_code='BLK-2-MAU-01',set_code='blk-2m-mau',set_version='mau-v1')
        row['set_source_name']='Bé lớn khôn'
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
         set_source_name=qs['source_name'] if qs else None,
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

def normalize(rows, *, unchanged_payloads=None):
    if not isinstance(rows,list) or not rows or len(rows)>MAX_ROWS: s.fail('Tệp cần từ 1 đến 500 dòng nội dung')
    errors=[]; normalized=[]; seen=set(); order_seen=set(); sets={}; identities={}
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
            if kind=='skill' and code.startswith('BLK-') and isinstance(x.get('payload'),dict):
                x['payload']={**x['payload'],'source_name':'app_authored'}
            known=(unchanged_payloads or {}).get((kind,code))
            unchanged_legacy=kind=='skill' and known is not None and known['payload']==x.get('payload') and known['source_refs']==x.get('source_refs')
            if not unchanged_legacy: s._validate_payload(x.get('payload'),kind,code)
            if kind=='advice':
                expected_action='contact_healthcare' if code.startswith('CONTACT_') else 'observe_skills' if code=='OBSERVE_UNCHECKED' else 'continue_monitoring'
                if x['payload'].get('action_kind')!=expected_action: s.fail('Không được đổi hành động hệ thống của lời khuyên')
                for field in ('age_months','set_code','set_version','app_domain','source_domain','order_index'):
                    if x.get(field) not in (None,''): s.fail('Mẫu lời khuyên không gắn bộ tuổi, lĩnh vực hoặc thứ tự câu hỏi')
                    x[field]=None
            if not isinstance(x.get('source_refs'),list) or any(not isinstance(v,dict) for v in x['source_refs']): s.fail('Nguồn tham khảo phải là danh sách đối tượng')
            if kind=='skill':
                for field in ('age_months','order_index'):
                    value=x.get(field,0)
                    if isinstance(value,bool) or not isinstance(value,(int,str)) or not str(value).isdigit(): s.fail('Tuổi và thứ tự phải là số nguyên không âm')
                x['age_months']=int(x.get('age_months',0)); x['order_index']=int(x.get('order_index',0))
                if x['age_months'] not in s.AGES or x.get('app_domain') not in s.DOMAINS: s.fail('Tuổi hoặc lĩnh vực không hợp lệ')
                if x.get('source_domain') not in ('social_emotional','language_communication','cognitive','movement_physical'): s.fail('Lĩnh vực nguồn không hợp lệ')
                expected_domain='movement_physical' if x['app_domain'] in ('gross_motor','fine_motor') else x['app_domain']
                if x['source_domain']!=expected_domain: s.fail('Lĩnh vực nguồn không khớp lĩnh vực phát triển')
                if not s.re.fullmatch(r'[a-z0-9][a-z0-9_-]{1,60}',x.get('set_code') or '') or not isinstance(x.get('set_version'),str) or not x['set_version'].strip(): s.fail('Thiếu mã hoặc phiên bản bộ')
                x['set_version']=str(x['set_version']).strip()
                x['locale']=x.get('locale') or 'vi-VN'
                if not isinstance(x['locale'],str) or not 2<=len(x['locale'].strip())<=16: s.fail('Ngôn ngữ bộ không hợp lệ')
                x['locale']=x['locale'].strip()
                if len(x['set_version'])>40: s.fail('Phiên bản bộ tối đa 40 ký tự')
                if x.get('set_source_name') is not None:
                    if not isinstance(x['set_source_name'],str) or not 1<=len(x['set_source_name'].strip())<=200: s.fail('Nguồn nội dung bộ phải có từ 1 đến 200 ký tự')
                    x['set_source_name']=x['set_source_name'].strip()
                metadata=(x['age_months'],x['set_version'],x['locale'],x.get('set_source_name'))
                if x['set_code'] in sets and sets[x['set_code']]!=metadata: s.fail('Các dòng cùng bộ phải có cùng tuổi, phiên bản, ngôn ngữ và nguồn nội dung')
                identity=metadata[:3]
                if identity in identities and identities[identity]!=x['set_code']: s.fail('Hai mã bộ trùng tuổi, phiên bản và ngôn ngữ')
                sets[x['set_code']]=metadata;identities[identity]=x['set_code']
                if x['order_index']<0: s.fail('Thứ tự phải từ 0')
                order=(x['set_code'],x['order_index'])
                if order in order_seen: s.fail('Trùng thứ tự trong bộ')
                order_seen.add(order)
                if code.startswith('CDC-'):
                    canonical=next((r for r in bundled() if r['kind']=='skill' and r['stable_code']==code),None)
                    if canonical is None: s.fail('Mã CDC không có trong tài liệu chuẩn')
                    if canonical['age_months']!=x['age_months']: s.fail('Mã câu CDC không thuộc mốc tuổi của bộ')
            normalized.append(x)
        except (s.HTTPException,ValueError,TypeError) as error:
            errors.append({'row':number,'message':str(getattr(error,'detail',error))})
    return normalized,errors

def preview(conn,rows):
    known={(x['kind'],x['stable_code']):x for x in s.list_content(conn) if not x['deleted_at']}
    normalized,errors=normalize(rows,unchanged_payloads=known)
    row_numbers={(row.get('kind'),row.get('stable_code')):number for number,row in enumerate(rows,1) if isinstance(row,dict) and isinstance(row.get('kind'),str) and isinstance(row.get('stable_code'),str)}
    changes=[]
    with conn.cursor() as cur:
        for index,x in enumerate(normalized,1):
            index=row_numbers.get((x['kind'],x['stable_code']),index)
            cur.execute(s.CONTENT_SELECT+' WHERE ci.kind=%s AND ci.stable_code=%s',(x['kind'],x['stable_code']))
            old=cur.fetchone()
            if old is None and x['kind']=='skill' and not x['stable_code'].startswith('CDC-') and not s.re.fullmatch(r'BLK-'+str(x['age_months'])+r'-[A-Z0-9_-]+',x['stable_code']):
                errors.append({'row':index,'message':'Câu mới phải dùng mã BLK-'+str(x['age_months'])+'-...; mã cũ chỉ được dùng để cập nhật câu đã tồn tại'})
            action='create' if old is None else 'unchanged' if old['payload']==x['payload'] and old['source_refs']==x['source_refs'] else 'revision'
            if old and old['deleted_at']: errors.append({'row':index,'message':x['stable_code']+': cần khôi phục trước khi nhập'})
            if old and old['kind']=='skill':
                qs=s.one(cur,'SELECT code,age_months,version FROM development.question_sets WHERE id=%s',(old['question_set_id'],))
                if (qs['code'],qs['age_months'],qs['version'])!=(x['set_code'],x['age_months'],x['set_version']): errors.append({'row':index,'message':x['stable_code']+': không được chuyển bộ tuổi'})
                if old['order_index']!=x['order_index'] or old['app_domain']!=x['app_domain'] or old['source_domain']!=x['source_domain']: errors.append({'row':index,'message':x['stable_code']+': đổi lĩnh vực/thứ tự trong trang chỉnh sửa trước khi nhập'})
            if x['kind']=='skill':
                cur.execute('SELECT id,age_months,version,locale,source_name,deleted_at FROM development.question_sets WHERE code=%s',(x['set_code'],))
                qs=cur.fetchone()
                if qs:
                    if qs['deleted_at'] or (qs['age_months'],qs['version'],qs['locale'])!=(x['age_months'],x['set_version'],x['locale']): errors.append({'row':index,'message':'Bộ '+x['set_code']+' đã xóa hoặc khác tuổi/phiên bản/ngôn ngữ'})
                    if x.get('set_source_name') is not None and x['set_source_name']!=qs['source_name']: errors.append({'row':index,'message':'Nguồn nội dung bộ khác dữ liệu hiện tại; sửa nguồn ở thông tin bộ trước khi nhập'})
                    cur.execute('SELECT stable_code FROM development.content_items WHERE question_set_id=%s AND order_index=%s AND deleted_at IS NULL AND stable_code<>%s',(qs['id'],x['order_index'],x['stable_code']))
                    if cur.fetchone(): errors.append({'row':index,'message':x['stable_code']+': thứ tự đã được câu khác sử dụng'})
                else:
                    cur.execute('SELECT code FROM development.question_sets WHERE age_months=%s AND version=%s AND locale=%s',(x['age_months'],x['set_version'],x['locale']))
                    if cur.fetchone(): errors.append({'row':index,'message':'Tuổi, phiên bản và ngôn ngữ đã thuộc một bộ khác; đổi phiên bản hoặc dùng đúng mã bộ'})
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
                        cur.execute('''INSERT INTO development.question_sets(code,age_months,version,locale,source_name,created_by)
                          VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT (code) DO NOTHING''',(x['set_code'],x['age_months'],x['set_version'],x.get('locale') or 'vi-VN',x.get('set_source_name') or ('Bé lớn khôn' if x['stable_code'].startswith('BLK-') else 'CDC Developmental Milestones'),s.actor_id(actor)))
                        set_id=s.one(cur,'SELECT id FROM development.question_sets WHERE code=%s',(x['set_code'],))['id']
                    item_id=s.one(cur,'''INSERT INTO development.content_items(kind,stable_code,question_set_id,app_domain,source_domain,order_index,created_by,updated_by)
                      VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''',(x['kind'],x['stable_code'],set_id,x.get('app_domain'),x.get('source_domain'),x.get('order_index'),s.actor_id(actor),s.actor_id(actor)))['id']
                    revision=1; counts['created']+=1
                cur.execute('INSERT INTO development.content_revisions(content_item_id,revision,locale,payload,source_refs,created_by) VALUES (%s,%s,%s,%s::jsonb,%s::jsonb,%s)',(item_id,revision,x.get('locale') or 'vi-VN',json.dumps(x['payload']),json.dumps(x['source_refs']),s.actor_id(actor)))
                s.log(cur,actor,'import','content_item',item_id,
                      before={'revision':old['current_revision'],'payload':old['payload'],'source_refs':old['source_refs']} if old else None,
                      after={'code':x['stable_code'],'revision':revision,'payload':x['payload'],'source_refs':x['source_refs']})
            return counts
    except s.errors.IntegrityError as error: s.integrity(error)

