"""Deterministic 3-section results for Bé lớn khôn. No generative medical text."""
from __future__ import annotations
import csv
from pathlib import Path
from typing import Any

class PresentationValidationError(ValueError):
    pass


def load_skill_rows(path: str|Path) -> dict[str,dict[str,str]]:
    with Path(path).open(encoding='utf-8-sig',newline='') as f:
        records=list(csv.DictReader(f))
    ids=[r.get('question_id') for r in records]
    if len(records)!=159 or len(set(ids))!=159:
        raise PresentationValidationError('Skill mapping must contain 159 unique questions')
    needed=('question_id','age_months','skill_name','not_yet_comment','not_observed_comment','observation_guide','app_domain')
    for r in records:
        if any(not r.get(k) for k in needed):
            raise PresentationValidationError(f'Missing skill fields for {r.get("question_id")}')
    return {r['question_id']:r for r in records}


def build_result_view_model(*,step1_result:dict[str,Any],step3_advice:dict[str,Any],
                            skills_by_id:dict[str,dict[str,str]],preview_limit:int=3)->dict[str,Any]:
    if step1_result.get('assessment_status')!='completed':
        raise PresentationValidationError('Assessment not completed')
    if type(preview_limit) is not int or not 1<=preview_limit<=10:
        raise PresentationValidationError('Invalid preview limit')
    summary=step1_result.get('summary',{})
    if any(type(summary.get(k)) is not int or summary[k]<0 for k in ('total','achieved','not_yet','not_observed')):
        raise PresentationValidationError('Invalid summary counts')
    if sum(summary[k] for k in ('achieved','not_yet','not_observed'))!=summary['total']:
        raise PresentationValidationError('Summary count mismatch')
    listed=step1_result.get('skills_to_note',{})
    unmet=listed.get('not_yet_question_ids')
    unobserved=listed.get('not_observed_question_ids')
    achieved=step1_result.get('achieved_question_ids')
    if not all(isinstance(x,list) for x in (unmet,unobserved,achieved)):
        raise PresentationValidationError('Missing answer groups')
    if any(len(a)!=len(set(a)) for a in (unmet,unobserved,achieved)):
        raise PresentationValidationError('Duplicate question IDs')
    if len(unmet)!=summary['not_yet'] or len(unobserved)!=summary['not_observed'] or len(achieved)!=summary['achieved']:
        raise PresentationValidationError('Question lists do not match summary')
    all_ids=achieved+unmet+unobserved
    if len(set(all_ids))!=summary['total'] or not set(all_ids)<=set(skills_by_id):
        raise PresentationValidationError('Question IDs overlap or are missing')
    age=step1_result.get('question_set_age_months')
    if type(age) is not int or age not in (2,4,6,9,12,15,18,24,30,36,48,60):
        raise PresentationValidationError('Unknown age set')
    if any(int(skills_by_id[q]['age_months'])!=age for q in all_ids):
        raise PresentationValidationError('Wrong age mapping')
    items=step3_advice.get('advice_items',[])
    keys=step1_result.get('advice_mapping_keys',[])
    if not isinstance(items,list) or len(items)!=step3_advice.get('advice_count') or [r.get('advice_key') for r in items]!=keys:
        raise PresentationValidationError('Advice and Rule Engine mismatch')
    if len(items)>2 or sum(x.get('advice_key')=='ADVICE_CONTACT_HEALTHCARE' for x in items)>1:
        raise PresentationValidationError('Advice duplication')
    cards=[]
    for status,ids in (('not_yet',unmet),('not_observed',unobserved)):
        for qid in ids:
            s=skills_by_id[qid]
            cards.append({
                'question_id':qid,'status':status,'domain':s['app_domain'],'skill_name':s['skill_name'],
                'comment':s['not_yet_comment'] if status=='not_yet' else s['not_observed_comment'],
                'how_to_observe':s['observation_guide'],'safety_note':s.get('safety_note') or None,
                'media_reference':{'type':s.get('media_type','none'),'url':s.get('media_url',''),
                                   'runtime_status':s.get('media_runtime_status','pending'),
                                   'embedding_enabled':False},
            })
    reason_labels={'CONTACT_REGRESSION_YES':'Phụ huynh báo có mất kỹ năng từng làm được',
      'CONTACT_REGRESSION_UNSURE':'Phụ huynh chưa chắc về mất kỹ năng',
      'CONTACT_NOT_YET':'Có kỹ năng chưa làm được','CONTACT_CONCERN_ONLY':'Phụ huynh có lo ngại về phát triển',
      'OBSERVE_UNCHECKED':'Có kỹ năng chưa được quan sát','CONTINUE_MONITORING':'Tất cả kỹ năng đã làm được, không có lo ngại hoặc mất kỹ năng được báo'}
    from .overall_commentary import build_overall_commentary
    commentary=build_overall_commentary(step1_result=step1_result,skills_by_id=skills_by_id)
    internal_plan=step3_advice.get('action_plan') or {}
    public_plan={key:value for key,value in internal_plan.items() if key not in ('facts','preparation_variants')} if internal_plan else None
    view={
      'schema_version':'development-result-view-v1.5.0',
      'rules_version':step1_result.get('rules_version'),
      'advice_content_version':step3_advice.get('advice_content_version'),
      'question_set_age_months':age,
      'primary_result_code':step1_result.get('primary_result_code'),
      'reported_flags':step1_result.get('active_result_codes',[]),
      'sections':{
        'overview':{k:summary[k] for k in ('total','achieved','not_yet','not_observed')},
        'overall_comment':commentary,
        'skills_to_note':{'total':len(cards),'preview_count':min(len(cards),preview_limit),
                         'preview':cards[:preview_limit], 'all':cards, 'has_more':len(cards)>preview_limit},
        'next_steps':{'title':'Hướng dẫn tiếp theo','advice_items':items,'action_plan':public_plan,
          'tts_text':step3_advice.get('tts_short_text',''),'auto_play':False}
      },
      'preview_diagnostics':{'reported_signals':internal_plan.get('facts',[]),'preparation_variants':step3_advice.get('action_plan',{}).get('preparation_variants',[]),'selected_templates':[{'variant_id':item['variant_id'],'reason':reason_labels.get(item['variant_id'],item['variant_id'])} for item in items]},
      'disclaimer':'Theo dõi mốc phát triển; không thay thế sàng lọc hoặc chẩn đoán.',
      'release_status':step3_advice.get('release_status'),
    }
    return view
