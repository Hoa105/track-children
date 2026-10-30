"""Validate growth OpenAPI, all linked examples, source enums and negative probes."""
import copy
import csv
import json
from pathlib import Path
import re

from jsonschema import Draft202012Validator, FormatChecker
from openapi_spec_validator import validate_spec
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

ROOT = Path(__file__).resolve().parents[3]
PATH = ROOT / 'docs/api/mobile-growth.openapi.json'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def validate():
    doc = json.loads(PATH.read_text(encoding='utf-8'))
    validate_spec(doc)
    refs = []

    def walk(value):
        if isinstance(value, dict):
            if '$ref' in value:
                refs.append(value['$ref'])
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    def resolve(path):
        require(path.startswith('#/'), f'non-standalone reference: {path}')
        node = doc
        for component in path[2:].split('/'):
            node = node[component.replace('~1','/').replace('~0','~')]
        return node

    walk(doc)
    for path in refs:
        resolve(path)
    registry = Registry().with_resource('urn:growth:openapi', Resource(contents=doc, specification=DRAFT202012))

    def validator(schema):
        # Absolute base resolves the document-local #/components fragments.
        return Draft202012Validator({'$ref':'urn:growth:openapi' + schema['$ref']} if '$ref' in schema else schema,
                                    registry=registry, format_checker=FormatChecker())

    count = 0

    def check_media(media):
        nonlocal count
        check = validator(media['schema'])
        examples = [media['example']] if 'example' in media else []
        for item in media.get('examples', {}).values():
            examples.append((resolve(item['$ref']) if '$ref' in item else item)['value'])
        for example in examples:
            errors = list(check.iter_errors(example))
            require(not errors, '\n'.join(f'{list(e.path)}: {e.message}' for e in errors[:5]))
            count += 1

    operation_ids = []
    for path, item in doc['paths'].items():
        for method, op in item.items():
            require(method in ('get','put','delete'), f'unexpected method {method}')
            operation_ids.append(op['operationId'])
            params = [resolve(p['$ref']) for p in op['parameters']]
            require(set(re.findall(r'\{([^}]+)\}',path)) == {p['name'] for p in params if p['in']=='path'}, f'path parameters: {path}')
            require(len({(p['in'],p['name']) for p in params}) == len(params), 'duplicate parameter')
            if 'requestBody' in op:
                check_media(op['requestBody']['content']['application/json'])
            for status, response in op['responses'].items():
                response = resolve(response['$ref']) if '$ref' in response else response
                if status == '204':
                    require('content' not in response, '204 body not allowed')
                for media in response.get('content', {}).values():
                    check_media(media)
    require(len(operation_ids)==len(set(operation_ids))==6, 'expected six distinct operations')
    for screen, ids in doc['x-screen-operations'].items():
        require(set(ids) <= set(operation_ids), f'unbound screen: {screen}')
    contract=json.loads((ROOT/'docs/core_growth/GROWTH-STATUS-CONTRACT.json').read_text(encoding='utf-8'))
    schema_keys={'AssessmentStatus':'assessment_status','AssessmentReason':'assessment_reason','VelocityCalculationStatus':'velocity_calculation_status',
                 'ReferenceStatus':'reference_status','ReferenceReason':'reference_reason','VelocityZScoreStatus':'velocity_z_score_status',
                 'VelocityZScoreReason':'velocity_z_score_reason','ContentStatus':'content_status','ReferenceImportStatus':'reference_import_status'}
    require(doc['x-status-contract-version']==contract['schema_version'], 'source contract version drift')
    for schema,key in schema_keys.items():
        require(doc['components']['schemas'][schema]['enum']==contract[key], f'enum drift: {schema}')
    with (ROOT/'docs/core_growth/GROWTH-WHO-CLASSIFICATION-MAP.csv').open(encoding='utf-8',newline='') as stream:
        codes=sorted({row['classification_code'] for row in csv.DictReader(stream)})
    require(doc['components']['schemas']['ClassificationCode']['enum']==codes, 'classification enum drift')
    for state, reasons in contract['assessment_reasons_by_status'].items():
        clauses=doc['components']['schemas']['IndicatorAssessment']['allOf']
        clause=next(c for c in clauses if c['if']['properties'].get('status',{}).get('const')==state and 'reason' in c['then']['properties'])
        require(clause['then']['properties']['reason']==({'type':'string','enum':reasons} if reasons else {'type':'null'}), f'reason drift: {state}')
    examples={key:item['value'] for key,item in doc['components']['examples'].items()}
    probes=[]
    def reject(schema, payload, name):
        require(not validator({'$ref':'#/components/schemas/'+schema}).is_valid(payload), f'accepted invalid fixture: {name}')
        probes.append(name)
    for payload in [{},{'weightKg':None},{'weightKg':True},{'weightKg':-1},{'weightKg':9,'bmi':17},{'height':{'value':75}}, {'weightKg':9,'measuredAt':'2026-01-01'}]:
        reject('SaveDayRequest',payload,'invalid save '+str(len(probes)))
    bad=copy.deepcopy(examples['DayWhoFlagged']['assessments'][0]);bad['zScore']=0
    reject('IndicatorAssessment',bad,'flagged cannot carry valid Z')
    bad=copy.deepcopy(examples['DayEngineUnavailable']['assessments'][0]);bad['reason']='WHO_FLAGGED'
    reject('IndicatorAssessment',bad,'reason must match status')
    bad=copy.deepcopy(examples['OverviewEmpty']);bad['cards'][0]['metric']='bmi'
    reject('OverviewResponse',bad,'duplicate card metric')
    bad=copy.deepcopy(examples['VelocityActualOnly']['actualIntervals'][0]);bad['referenceStatus']='REFERENCE_MATCHED'
    reject('VelocityInterval',bad,'matched reference required')
    bad=copy.deepcopy(examples['VelocityActualOnly']['actualIntervals'][0]);bad['zScore']=0
    reject('VelocityInterval',bad,'no phantom Z when not requested')
    bad=copy.deepcopy(examples['DayEngineUnavailable']['assessments'][0]['content']['comment']);bad['text']='WITHIN_RANGE'
    reject('ContentBlock',bad,'blocked content fixed fallback')
    bad=copy.deepcopy(examples['VelocityActualOnly']);bad['intervalMonths']=2
    reject('VelocityResponse',bad,'actual mode cannot pretend selected WHO period')
    require(doc['x-implementation-status'] in ('DESIGN_ONLY','IMPLEMENTED'),'unknown implementation status')
    print(f'PASS: OpenAPI 3.1, {len(operation_ids)} operations, {len(doc["components"]["schemas"])} schemas, {len(refs)} local refs, {count} example uses, {len(probes)} negative probes, source status enums')


if __name__=='__main__':
    validate()
