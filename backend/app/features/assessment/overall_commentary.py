"""Source-traceable descriptive commentary, separate from actionable next steps."""
import json
from functools import lru_cache
from pathlib import Path

DOMAIN_LABELS={'gross_motor':'Vận động thô','fine_motor':'Vận động tinh','language_communication':'Ngôn ngữ và giao tiếp','cognitive':'Nhận thức','social_emotional':'Cảm xúc và xã hội'}

@lru_cache(maxsize=1)
def commentary_content():
    return json.loads((Path(__file__).parent/'data/overall-commentary.json').read_text(encoding='utf-8-sig'))


def build_overall_commentary(*,step1_result,skills_by_id):
    content=commentary_content();summary=step1_result['summary'];flags=set(step1_result['active_result_codes'])
    n=summary['not_yet'];o=summary['not_observed'];total=summary['total']
    paragraphs=[]
    def add(key):
        item=content['texts'][key]
        paragraphs.append({'id':key,'text':item['text'].format(**context),'source_ids':item['source_ids']})
    groups={key:{'domain':key,'label':label,'total':0,'achieved':0,'not_yet':0,'not_observed':0} for key,label in DOMAIN_LABELS.items()}
    assignments=[('achieved',step1_result['achieved_question_ids']),('not_yet',step1_result['skills_to_note']['not_yet_question_ids']),('not_observed',step1_result['skills_to_note']['not_observed_question_ids'])]
    for status,ids in assignments:
        for qid in ids:
            domain=skills_by_id[qid]['app_domain']
            if domain not in groups:raise ValueError('Unknown domain in commentary')
            groups[domain][status]+=1;groups[domain]['total']+=1
    domains=[]
    for group in groups.values():
        if not group['total']:continue
        descriptions=[]
        for key,label in [('achieved','được ghi nhận đã làm được'),('not_yet','được chọn chưa làm được'),('not_observed','chưa được quan sát')]:
            if group[key]:descriptions.append(f"{group[key]} kỹ năng {label}")
        group['text']=group['label']+': '+', '.join(descriptions)+'.'
        domains.append(group)
    def domain_names(status):
        labels=[group['label'].lower() for group in domains if group[status]]
        return labels[0] if len(labels)==1 else ', '.join(labels[:-1])+' và '+labels[-1] if labels else ''
    context={'age_months':step1_result['question_set_age_months'],
             'not_yet_skills':'kỹ năng nào trong các câu hỏi' if n==total else 'một số kỹ năng',
             'not_yet_domains':domain_names('not_yet'),
             'unobserved_domains':domain_names('not_observed'),
             'concern_context':('Thông tin bổ sung có ghi nhận lo ngại về sự phát triển của bé. Lo ngại này vẫn cần được xem xét dù các kỹ năng trong bài đều đã làm được.'
                                if not n and not o else 'Thông tin bổ sung có ghi nhận lo ngại về sự phát triển của bé; cần xem xét cùng những kỹ năng chưa làm được hoặc chưa quan sát.')}
    if not n and not o:add('all_recorded_context' if {'SKILL_REGRESSION_REPORTED','REGRESSION_UNCERTAIN','CAREGIVER_CONCERN'}&flags else 'all_recorded')
    elif o==total:add('all_unobserved')
    elif n and o:add('mixed')
    elif n:add('not_yet')
    else:add('unobserved')
    if 'SKILL_REGRESSION_REPORTED' in flags:add('regression_yes')
    elif 'REGRESSION_UNCERTAIN' in flags:add('regression_unsure')
    if 'CAREGIVER_CONCERN' in flags:add('caregiver_concern')
    contact=bool(n or {'SKILL_REGRESSION_REPORTED','REGRESSION_UNCERTAIN','CAREGIVER_CONCERN'}&flags)
    add('professional_contact' if contact else 'professional_incomplete' if o else 'professional_routine')
    add('scope')
    used={source_id for paragraph in paragraphs for source_id in paragraph['source_ids']}
    return {'title':'Nhận xét chung','content_version':content['version'],'paragraphs':paragraphs,'domain_observations':domains,
      'professional_review_recommended':contact,'sources':[source for source in content['sources'] if source['id'] in used],
      'tts_text':' '.join(paragraph['text'] for paragraph in paragraphs),'auto_play':False}
