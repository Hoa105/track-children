"""Versioned Vietnamese advice samples, adapted for local product testing."""
import copy
import json
from pathlib import Path

SAMPLE_VERSION='advice-local-test-v5-2026-11-06'


def enrich_advice_row(row):
    if row['kind']!='advice': return row
    samples=json.loads((Path(__file__).parent/'data/advice-test-content.json').read_text(encoding='utf-8-sig'))
    sample=next((item for item in samples if item['variant_id']==row['stable_code']),None)
    if sample is None: return row
    result=copy.deepcopy(row)
    result['payload'].update({key:sample[key] for key in ('title','body_text','tts_text','cta_label')})
    result['payload'].update({key:sample[key] for key in ('preparation_text','preparation_common') if key in sample})
    result['payload'].pop('combined_body_text',None)
    result['payload'].pop('combined_tts_text',None)
    result['payload'].update(source_name='Bé lớn khôn · biên soạn tham khảo CDC',editorial_version=SAMPLE_VERSION)
    by_url={ref.get('url') or str(index):ref for index,ref in enumerate(result.get('source_refs',[]))}
    for url in sample['sources']:
        by_url[url]={'organization':'CDC','url':url,'accessed_on':'2026-11-06'}
    result['source_refs']=list(by_url.values())
    return result
