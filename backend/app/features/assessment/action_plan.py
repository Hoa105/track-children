"""Compose one ordered action plan; preserve every supplied signal without duplicating actions."""
from .advice_resolver import text_key


def build_action_plan(*,summary,regression,concern,by_variant,items):
    n=summary['not_yet'];o=summary['not_observed']
    facts=[]
    if n: facts.append({'id':'not_yet','text':'Có kỹ năng được chọn Chưa làm được.'})
    if o: facts.append({'id':'not_observed','text':'Có kỹ năng chưa được quan sát, nên chưa đủ thông tin để nhận xét khả năng thực hiện.'})
    if not n and not o: facts.append({'id':'all_achieved','text':'Các kỹ năng trong bộ câu hỏi đều được ghi nhận Đã làm được trong lần theo dõi này.'})
    if regression=='yes': facts.append({'id':'regression_yes','text':'Phụ huynh báo bé không còn làm được kỹ năng từng có; thông tin này chưa gắn với kỹ năng cụ thể trong bài.'})
    elif regression=='unsure': facts.append({'id':'regression_unsure','text':'Phụ huynh chưa chắc về việc bé mất kỹ năng từng có; thông tin này chưa gắn với kỹ năng cụ thể trong bài.'})
    if concern=='yes': facts.append({'id':'caregiver_concern','text':'Phụ huynh có lo ngại về sự phát triển của bé.'})
    contact=bool(n or regression!='no' or concern=='yes')
    actions=[]
    if contact:
        primary=items[0]
        actions.append({'id':'contact','title':'Trao đổi với bác sĩ','body':primary['body_text'],'items':[],'tts_text':primary['tts_text']})
        preparation=[];seen=set();variants=[]
        if regression!='no': variants.append('CONTACT_REGRESSION_YES' if regression=='yes' else 'CONTACT_REGRESSION_UNSURE')
        if n: variants.append('CONTACT_NOT_YET')
        if concern=='yes': variants.append('CONTACT_CONCERN_ONLY')
        for variant in variants:
            text=by_variant[variant].get('preparation_text','').strip()
            if text and text_key(text) not in seen: preparation.append(text);seen.add(text_key(text))
        common=by_variant[primary['variant_id']].get('preparation_common','').strip()
        if common and text_key(common) not in seen: preparation.append(common)
        if preparation: actions.append({'id':'prepare','title':'Chuẩn bị thông tin trao đổi','body':'','items':preparation,'tts_text':' '.join(preparation)})
    if o:
        observation=next(item for item in items if item['variant_id']=='OBSERVE_UNCHECKED')
        actions.append({'id':'observe','title':'Bổ sung quan sát','body':observation['body_text'],'items':[],'tts_text':observation['tts_text']})
    if not contact and not o:
        continuation=items[0]
        actions.append({'id':'continue','title':'Tiếp tục đồng hành cùng bé','body':continuation['body_text'],'items':[],'tts_text':continuation['tts_text']})
    timing='Có thể bổ sung quan sát song song; không cần chờ hoàn thành các câu chưa quan sát mới thực hiện bước trao đổi.' if contact and o else ''
    speech=[]
    for action in actions: speech.append(action['tts_text'])
    if timing:speech.append(timing)
    return {'facts':facts,'actions':actions,'observation_timing':timing,'preparation_variants':variants if contact else [],'tts_text':' '.join(speech)}
