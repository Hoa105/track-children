"""Bé lớn khôn — Step 3 advice resolver. Reference implementation (not medical software).

Takes exact Step 1 `advice_mapping_keys` (server-produced), and trusted metadata.
Draft advice may only render in sandbox. This is not a medical screening tool.
"""
from __future__ import annotations
import csv
import re
import unicodedata
from pathlib import Path
from typing import Any

ALLOWED_KEYS={"ADVICE_CONTACT_HEALTHCARE","ADVICE_OBSERVE_SKILLS","ADVICE_CONTINUE_MONITORING"}
VERSION="advice-draft-v1.1.0"

class AdviceValidationError(ValueError):
    pass

def load_advice_rows(path: str | Path) -> list[dict[str,str]]:
    with open(path,encoding="utf-8-sig",newline="") as f:
        rows=list(csv.DictReader(f))
    if len(rows)!=6 or len({r['variant_id'] for r in rows})!=6:
        raise AdviceValidationError("Missing or duplicate advice variant")
    return rows

def text_key(text):
    return ' '.join(unicodedata.normalize('NFC',text).casefold().split())


def unique_text_blocks(text,seen,spoken=False):
    # Only exact textual duplicates are removed; no fuzzy medical paraphrasing.
    units=re.split(r'(?<=[.!?])\s+',text.strip()) if spoken else re.split(r'\n\s*\n',text.strip())
    kept=[]
    for unit in units:
        key=text_key(unit)
        if key and key not in seen:
            seen.add(key);kept.append(unit.strip())
    return (' ' if spoken else '\n\n').join(kept)


def resolve_advice(*, step1_result: dict[str,Any], regression: str,
                   caregiver_concern: str, advice_rows: list[dict[str,str]],
                   environment: str="sandbox",release_gate:dict[str,bool]|None=None) -> dict[str,Any]:
    if step1_result.get('assessment_status')!='completed':
        raise AdviceValidationError("Only completed assessments can be resolved")
    if regression not in ('yes','no','unsure') or caregiver_concern not in ('yes','no'):
        raise AdviceValidationError("Invalid caregiver follow-up answers")
    if environment not in ('sandbox','production'):
        raise AdviceValidationError("Invalid environment")
    keys=step1_result.get('advice_mapping_keys')
    if not isinstance(keys,list) or len(keys)!=len(set(keys)) or not set(keys)<=ALLOWED_KEYS:
        raise AdviceValidationError("Unexpected or duplicate advice keys")
    summary=step1_result.get('summary',{})
    n=summary.get('not_yet'); o=summary.get('not_observed'); t=summary.get('total')
    a=summary.get('achieved')
    if any(type(x) is not int or x<0 for x in (n,o,t,a)) or n+o+a!=t:
        raise AdviceValidationError("Invalid summary: achieved/not_yet/not_observed must equal total")
    should_contact=bool(n or regression in ('yes','unsure') or caregiver_concern=='yes')
    expected=set()
    if should_contact: expected.add('ADVICE_CONTACT_HEALTHCARE')
    if o: expected.add('ADVICE_OBSERVE_SKILLS')
    if not expected: expected.add('ADVICE_CONTINUE_MONITORING')
    if set(keys)!=expected:
        raise AdviceValidationError("Step1 advice keys inconsistent with answers")
    raw_flags=step1_result.get('active_result_codes')
    if not isinstance(raw_flags,list) or len(raw_flags)!=len(set(raw_flags)):
        raise AdviceValidationError('Invalid or duplicate result flags')
    flags=set(raw_flags)
    allowed_flags={'SKILL_REGRESSION_REPORTED','REGRESSION_UNCERTAIN','MILESTONE_NOT_RECORDED','CAREGIVER_CONCERN','OBSERVATION_INCOMPLETE','ALL_RECORDED'}
    if not flags <= allowed_flags:
        raise AdviceValidationError('Unknown result flag')
    if ('SKILL_REGRESSION_REPORTED' in flags)!=(regression=='yes') or ('REGRESSION_UNCERTAIN' in flags)!=(regression=='unsure') or ('CAREGIVER_CONCERN' in flags)!=(caregiver_concern=='yes'):
        raise AdviceValidationError("Step1 flags inconsistent with end-of-checklist answers")
    if ('MILESTONE_NOT_RECORDED' in flags)!=(n>0) or ('OBSERVATION_INCOMPLETE' in flags)!=(o>0):
        raise AdviceValidationError("Step1 flags inconsistent with summary")
    if ('ALL_RECORDED' in flags) != (not should_contact and not o):
        raise AdviceValidationError("Invalid ALL_RECORDED flag")
    by_variant={r['variant_id']:r for r in advice_rows}
    if len(by_variant)!=6:
        raise AdviceValidationError("Advice mapping incomplete")
    selected=[]
    if should_contact:
        variant=('CONTACT_REGRESSION_YES' if regression=='yes' else
                 'CONTACT_REGRESSION_UNSURE' if regression=='unsure' else
                 'CONTACT_NOT_YET' if n else 'CONTACT_CONCERN_ONLY')
        selected.append(by_variant[variant])
    if o:
        selected.append(by_variant['OBSERVE_UNCHECKED'])
    if not selected:
        selected.append(by_variant['CONTINUE_MONITORING'])
    if len(set(r.get('content_version') for r in advice_rows))!=1 or advice_rows[0].get('content_version')!=VERSION:
        raise AdviceValidationError('Mixed advice content versions')
    if environment=='production':
        needed=('question_bank_approved','skill_mapping_approved','media_rights_approved','media_runtime_tested','clinical_signoff','language_qa_passed','rule_engine_qa_passed')
        if not release_gate or not all(release_gate.get(k) is True for k in needed):
            raise AdviceValidationError('RELEASE_GATE_BLOCKED: source/clinical/QA approval missing')
        if any(r.get('release_status')!='approved' or r.get('clinical_review_status')!='approved' or r.get('language_review_status')!='approved' or not r.get('approval_by') or not r.get('approved_at') for r in advice_rows):
            raise AdviceValidationError('RELEASE_GATE_BLOCKED: advice not approved')
    out=[{k:r[k] for k in ('advice_key','variant_id','title','body_text','tts_text','cta_label','action_kind','content_version')} for r in selected]
    seen_body=set();seen_speech=set()
    composition=[]
    for item in out:
        if item['variant_id']=='OBSERVE_UNCHECKED' and should_contact:
            item['composition_mode']='combined'
            composition.append('observation_complements_contact')
        item['body_text']=unique_text_blocks(item['body_text'],seen_body)
        item['tts_text']=unique_text_blocks(item['tts_text'],seen_speech,spoken=True)
    from .action_plan import build_action_plan
    plan=build_action_plan(summary=summary,regression=regression,concern=caregiver_concern,by_variant=by_variant,items=out)
    return {'action_plan':plan,'composition':composition,'advice_content_version':VERSION,'advice_count':len(out),
            'advice_items':out,'tts_short_text':plan['tts_text'],
            'is_medical_screening':False,'release_status':'sandbox_only' if environment=='sandbox' else 'production'}
