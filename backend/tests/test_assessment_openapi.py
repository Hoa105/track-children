"""Validate standalone docs and compare documented assessment inputs to routers."""
from pathlib import Path

import pytest
import yaml
from fastapi import FastAPI
from jsonschema import Draft202012Validator
from openapi_spec_validator import validate
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

from app.features.assessment.router import router as mobile_router
from app.features.assessment.admin.router import admin_router

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('kind,router', [('mobile', mobile_router), ('admin', admin_router)])
def test_assessment_openapi_matches_router_inputs_and_models(kind, router):
    doc = yaml.safe_load((ROOT / f'docs/api/{kind}-assessment.openapi.yaml').read_text(encoding='utf-8'))
    validate(doc)
    app = FastAPI()
    app.include_router(router)
    actual = app.openapi()
    assert doc['paths'].keys() == actual['paths'].keys()
    registry = Registry().with_resource('urn:assessment', Resource(doc, DRAFT202012))
    for name, schema in actual['components']['schemas'].items():
        assert doc['components']['schemas'][name] == schema
    for path, methods in actual['paths'].items():
        assert doc['paths'][path].keys() == methods.keys()
        for method, operation in methods.items():
            documented = doc['paths'][path][method]
            assert documented.get('parameters') == operation.get('parameters')
            assert documented['security'] == operation['security']
            if 'requestBody' in operation:
                assert documented['requestBody']['required'] == operation['requestBody']['required']
                media = documented['requestBody']['content']['application/json']
                assert media['schema'] == operation['requestBody']['content']['application/json']['schema']
                if 'example' in media:
                    validator = Draft202012Validator(
                        {'$ref': 'urn:assessment' + media['schema']['$ref']}, registry=registry)
                    validator.validate(media['example'])
            status = next(code for code in operation['responses'] if code.startswith('2'))
            assert status in documented['responses']
            original_schema = operation['responses'][status]['content']['application/json']['schema']
            documented_schema = documented['responses'][status]['content']['application/json']['schema']
            assert documented_schema
            if original_schema:
                assert documented_schema == original_schema
