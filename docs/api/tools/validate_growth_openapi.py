"""Validate growth OpenAPI, all linked examples, enum consistency and negative probes."""
import copy
import yaml
from pathlib import Path
import re

from jsonschema import Draft202012Validator, FormatChecker
from openapi_spec_validator import validate_spec
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

ROOT = Path(__file__).resolve().parents[3]
PATH = ROOT / 'docs/api/mobile-growth.openapi.yaml'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def validate():
    doc = yaml.safe_load(PATH.read_text(encoding='utf-8'))
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
    schemas = doc['components']['schemas']
    for name, schema in schemas.items():
        values = schema.get('enum')
        if values is not None:
            require(len(values) == len(set(values)), f'duplicate enum values: {name}')
    reason_clauses = [
        clause for clause in schemas['IndicatorAssessment']['allOf']
        if 'reason' in clause.get('then', {}).get('properties', {})
    ]
    require({c['if']['properties']['status']['const'] for c in reason_clauses}
            == set(schemas['AssessmentStatus']['enum']), 'assessment reason status coverage')
    for clause in reason_clauses:
        reason = clause['then']['properties']['reason']
        require(reason.get('type') == 'null' or
                (reason.get('type') == 'string' and bool(reason.get('enum')) and
                 set(reason['enum']) <= set(schemas['AssessmentReason']['enum'])),
                'assessment reason must use a declared enum value or null')
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
    print(f'PASS: OpenAPI 3.1, {len(operation_ids)} operations, {len(doc["components"]["schemas"])} schemas, {len(refs)} local refs, {count} example uses, {len(probes)} negative probes, internal enum consistency')


if __name__=='__main__':
    validate()
