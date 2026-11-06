"""Exhaustive advice selection audit over every answer-count and follow-up combination."""
from collections import Counter
import re
from .advice_resolver import resolve_advice, VERSION, text_key
from .rule_engine import evaluate


def audit_advice_cases(question_sets,advice_rows):
    rows=[{**row,'content_version':VERSION} for row in advice_rows]
    cases=0;combinations=Counter();contexts=Counter();combined=0
    for question_set in question_sets:
        ids=question_set['question_ids'];n=len(ids)
        if not n: continue
        for achieved in range(n+1):
            for not_yet in range(n-achieved+1):
                observed=n-achieved-not_yet
                answers={qid:('achieved' if i<achieved else 'not_yet' if i<achieved+not_yet else 'not_observed') for i,qid in enumerate(ids)}
                for regression in ('no','yes','unsure'):
                    for concern in ('no','yes'):
                        engine=evaluate(expected_question_ids=ids,answers=answers,regression=regression,caregiver_concern=concern,question_set_age_months=question_set['age_months'],environment='sandbox')
                        result=resolve_advice(step1_result=engine,regression=regression,caregiver_concern=concern,advice_rows=rows)
                        items=result['advice_items'];variants=[item['variant_id'] for item in items]
                        contact=bool(not_yet or regression!='no' or concern=='yes')
                        expected=[]
                        if contact: expected.append('CONTACT_REGRESSION_YES' if regression=='yes' else 'CONTACT_REGRESSION_UNSURE' if regression=='unsure' else 'CONTACT_NOT_YET' if not_yet else 'CONTACT_CONCERN_ONLY')
                        if observed: expected.append('OBSERVE_UNCHECKED')
                        if not expected: expected=['CONTINUE_MONITORING']
                        assert variants==expected,(question_set,achieved,not_yet,regression,concern,variants)
                        blocks=[text_key(block) for item in items for block in re.split(r'\n\s*\n',item['body_text']) if block.strip()]
                        assert len(blocks)==len(set(blocks)),('Repeated paragraph',variants)
                        spoken=[text_key(sentence) for sentence in re.split(r'(?<=[.!?])\s+',result['tts_short_text']) if sentence.strip()]
                        assert len(spoken)==len(set(spoken)),('Repeated spoken sentence',variants)
                        if contact and observed:
                            observation=items[-1]
                            assert observation.get('composition_mode')=='combined'
                            assert not re.search('bác sĩ|sàng lọc|đánh giá thêm',observation['body_text'],re.I)
                            assert not re.search('bác sĩ|sàng lọc|đánh giá thêm',observation['tts_text'],re.I)
                            combined+=1
                        assert engine['summary']['achieved']==achieved and engine['summary']['not_yet']==not_yet and engine['summary']['not_observed']==observed
                        plan=result['action_plan']
                        action_ids=[action['id'] for action in plan['actions']]
                        assert action_ids==(['contact','prepare'] if contact else [])+(['observe'] if observed else [])+(['continue'] if not contact and not observed else [])
                        assert len(action_ids)==len(set(action_ids))
                        fact_ids={fact['id'] for fact in plan['facts']}
                        assert ('not_yet' in fact_ids)==bool(not_yet)
                        assert ('not_observed' in fact_ids)==bool(observed)
                        assert ('regression_yes' in fact_ids)==(regression=='yes')
                        assert ('regression_unsure' in fact_ids)==(regression=='unsure')
                        assert ('caregiver_concern' in fact_ids)==(concern=='yes')
                        assert ('all_achieved' in fact_ids)==(not not_yet and not observed)
                        preparation=next((action['items'] for action in plan['actions'] if action['id']=='prepare'),[])
                        assert len(preparation)==len(set(map(text_key,preparation)))
                        assert len(plan['preparation_variants'])==int(regression!='no')+int(bool(not_yet))+int(concern=='yes')
                        rendered=' '.join([fact['text'] for fact in plan['facts']]+[action['body']+' '+' '.join(action['items']) for action in plan['actions']])
                        assert 'mốc' not in rendered.casefold()
                        assert result['tts_short_text']==plan['tts_text']
                        pattern=('mixed' if not_yet and observed else 'not_yet' if not_yet else 'not_observed' if observed else 'all_achieved')
                        contexts[f'{pattern} | regression={regression} | concern={concern}']+=1
                        assert len(variants)==len(set(variants))
                        cases+=1;combinations[' + '.join(variants)]+=1
    return {'sets':len(question_sets),'cases':cases,'combined_cases':combined,'selection_paths':dict(sorted(combinations.items())),'context_patterns':dict(sorted(contexts.items())),'duplicate_paragraphs':0,'duplicate_spoken_sentences':0}
