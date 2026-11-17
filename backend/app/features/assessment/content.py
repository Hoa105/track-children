"""Published content rules and database helpers shared by admin and mobile.

This module has no dependency on the admin editing or review workflow.
"""
import re
from urllib.parse import urlparse
from fastapi import HTTPException
from psycopg2.extras import register_uuid

register_uuid()

AGES = (2,4,6,9,12,15,18,24,30,36,48,60)


DOMAINS = ('gross_motor','fine_motor','language_communication','cognitive','social_emotional')


VARIANTS = {
 'CONTACT_REGRESSION_YES': ('ADVICE_CONTACT_HEALTHCARE',1,'regression == yes'),
 'CONTACT_REGRESSION_UNSURE': ('ADVICE_CONTACT_HEALTHCARE',2,'regression == unsure'),
 'CONTACT_NOT_YET': ('ADVICE_CONTACT_HEALTHCARE',3,'not_yet_count >= 1'),
 'CONTACT_CONCERN_ONLY': ('ADVICE_CONTACT_HEALTHCARE',4,'caregiver_concern == yes'),
 'OBSERVE_UNCHECKED': ('ADVICE_OBSERVE_SKILLS',10,'not_observed_count >= 1'),
 'CONTINUE_MONITORING': ('ADVICE_CONTINUE_MONITORING',20,'all_achieved && regression == no && caregiver_concern == no'),
}


def fail(message, code=422):
    raise HTTPException(code, message)


def one(cur, sql, params=()):
    cur.execute(sql,params)
    row=cur.fetchone()
    if row is None: fail('Không tìm thấy nội dung',404)
    return row


def lock_set(cur, set_id):
    return one(cur,'SELECT * FROM assessment.question_sets WHERE id=%s FOR UPDATE',(set_id,))


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
        for key in ('preparation_text','preparation_common'):
            if key in payload and not isinstance(payload[key],str): fail('Nội dung chuẩn bị trao đổi phải là văn bản')
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


def blockers(cur,item,revision=None):
    rev=revision or item['current_revision']
    result=[]
    content=one(cur,'SELECT payload,source_refs FROM assessment.content_revisions WHERE content_item_id=%s AND revision=%s',(item['id'],rev))
    payload=content['payload']
    try: _validate_payload(payload,item['kind'],item['stable_code'])
    except HTTPException as error: result.append(str(error.detail))
    if not content['source_refs'] or not any(isinstance(ref,dict) and any(isinstance(ref.get(k),str) and ref[k].strip() for k in ('url','document','organization','label')) for ref in content['source_refs']):
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

