"""Export standalone assessment contracts from the current FastAPI routers.

Run with .venv/Scripts/python.exe scripts/export-assessment-openapi.py.
Request schemas, parameters, response models and status codes come from routers;
unmodelled service responses and workflow descriptions are documented below.
"""
import copy
import sys
from pathlib import Path

import yaml
from fastapi import FastAPI

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
from app.features.assessment.router import router as mobile_router
from app.features.assessment.admin.router import admin_router


def ref(name):
    return {'$ref': '#/components/schemas/' + name}


def obj(properties=None, required=None):
    properties = properties or {}
    return {'type': 'object', 'properties': properties,
            'required': list(properties) if required is None else required}


def array(item):
    return {'type': 'array', 'items': item}


def nullable(schema):
    return {'anyOf': [schema, {'type': 'null'}]}


STRING = {'type': 'string'}
INTEGER = {'type': 'integer', 'minimum': 0}
BOOL = {'type': 'boolean'}
UUID = {'type': 'string', 'format': 'uuid'}
DATE = {'type': 'string', 'format': 'date'}
DATETIME = {'type': 'string', 'format': 'date-time'}
OPEN = {'type': 'object', 'additionalProperties': True}
AGES = [2, 4, 6, 9, 12, 15, 18, 24, 30, 36, 48, 60]


def shared_schemas():
    return {
        'AgeMonths': {'type': 'integer', 'enum': AGES},
        'Answer': {'type': 'string', 'enum': ['achieved', 'not_yet', 'not_observed']},
        'SummaryCounts': obj({key: INTEGER for key in ('total', 'achieved', 'not_yet', 'not_observed')}),
        'QuestionSnapshot': obj({
            'id': UUID, 'code': STRING, 'domain': STRING, 'revision': INTEGER,
            'order_index': INTEGER, 'payload': OPEN, 'source_refs': array(OPEN)}),
        'ResultView': obj({
            'schema_version': STRING, 'rules_version': nullable(STRING),
            'advice_content_version': nullable(STRING), 'question_set_age_months': ref('AgeMonths'),
            'primary_result_code': nullable(STRING), 'reported_flags': array(STRING),
            'sections': obj({
                'overview': ref('SummaryCounts'),
                'overall_comment': OPEN,
                'skills_to_note': obj({'total': INTEGER, 'preview_count': INTEGER,
                    'preview': array(OPEN), 'all': array(OPEN), 'has_more': BOOL}),
                'next_steps': obj({'title': STRING, 'advice_items': array(OPEN),
                    'action_plan': nullable(OPEN), 'tts_text': STRING, 'auto_play': {'const': False}})}),
            'disclaimer': STRING, 'release_status': STRING,
            'question_snapshot': array(ref('QuestionSnapshot')), 'preview_diagnostics': OPEN},
            required=['schema_version', 'rules_version', 'advice_content_version',
                'question_set_age_months', 'primary_result_code', 'reported_flags',
                'sections', 'disclaimer', 'release_status']),
        'ServiceError': obj({'detail': STRING}),
        'AuthError': obj({'error': obj({'code': STRING, 'message': STRING,
            'fields': OPEN, 'details': OPEN})}),
    }


def mobile_schemas():
    return {
        'AttemptReference': obj({'id': UUID, 'age_months': ref('AgeMonths')}),
        'AssessmentAttempt': obj({
            'id': UUID, 'age_months': ref('AgeMonths'),
            'status': {'type': 'string', 'enum': ['in_progress', 'completed']},
            'started_at': DATETIME, 'completed_at': nullable(DATETIME),
            'version': {'type': 'integer', 'minimum': 1},
            'answers': {'type': 'object', 'additionalProperties': ref('Answer')},
            'regression': {'enum': ['yes', 'no', 'unsure', None]},
            'caregiver_concern': {'enum': ['yes', 'no', None]}, 'editable': BOOL,
            'questions': array(ref('QuestionSnapshot')), 'result': nullable(ref('ResultView'))}),
        'AssessmentOverview': obj({
            'age_months': nullable(ref('AgeMonths')), 'today': DATE, 'can_edit': BOOL,
            'completed_milestones': array(ref('AgeMonths')),
            'latest_completed': nullable(ref('AttemptReference')), 'guidance_required': BOOL,
            'set': nullable(obj({'id': UUID, 'count': INTEGER})),
            'draft': nullable(ref('AssessmentAttempt')), 'past_drafts': array(ref('AttemptReference')),
            'milestones': array(obj({'age_months': ref('AgeMonths'), 'opens_on': DATE, 'closes_on': DATE}))}),
        'AssessmentHistory': obj({'items': array(obj({
            'id': UUID, 'age_months': ref('AgeMonths'), 'completed_at': DATETIME,
            'summary': ref('SummaryCounts'), 'attempt_number': {'type': 'integer', 'minimum': 1}})),
            'has_more': BOOL}),
    }


MOBILE_DESCRIPTIONS = {
    'overview': ('Tổng quan đánh giá theo mốc tuổi',
        'Requires assessment view access. Uses calendar age and tz (UTC offset in minutes, default +420). '
        'Milestones are 2–60 months; no current milestone before 2 months or from 61 months. '
        'Premature children under 24 months require explicit guidance confirmation; age is not automatically corrected.'),
    'history': ('Lịch sử các bài đã hoàn thành',
        'Requires view access. Completed attempts only, newest first. Optional age filter; '
        'offset/limit pagination, has_more indicates another page. Summary comes from the immutable saved result.'),
    'start': ('Bắt đầu hoặc tiếp tục bài đánh giá',
        'Requires edit access. The client supplies a UUID for retry idempotency. An existing ID for this child '
        'or an existing draft at the current milestone is returned. Success is HTTP 200, including creation. '
        'Published active question revisions are pinned when starting. 409: no eligible age or missing guidance '
        'confirmation/content changed. 503: published content is unavailable.'),
    'load': ('Xem bài đánh giá và kết quả đã lưu',
        'Requires view access. Completed attempts use immutable question/result snapshots. Old-milestone '
        'drafts remain readable with editable=false. Missing attempts return 404.'),
    'save': ('Lưu đáp án của bài đang làm',
        'Requires edit access at the current milestone. expected_version must match version; a successful save '
        'increments version. Supplied answers are upserted by question code; omitted answers remain saved. '
        'Both parent signals are assigned from this request (omitted/null resets them to null). '
        '409: stale version, completed attempt or expired milestone. Unknown question codes return 422.'),
    'complete': ('Hoàn thành bài và lưu kết quả bất biến',
        'Requires edit access. All skill answers and both parent signals must be present. '
        'For an unfinished attempt, expected_version must match. Retrying an already completed attempt '
        'returns its saved result even if expected_version is old. 422: incomplete answers. '
        '409: stale version or expired milestone. 503: published advice unavailable; draft remains saved. '
        'Results monitor milestones and do not provide a diagnosis or developmental risk score.'),
}


def response(schema, description='Successful response'):
    return {'description': description, 'content': {'application/json': {'schema': schema}}}


def export(kind, router):
    app = FastAPI(title=f'Track Children - {kind.title()} assessment API', version='1.0.0')
    app.include_router(router)
    doc = app.openapi()
    doc['servers'] = [{'url': 'http://localhost:8000'}]
    doc['info']['description'] = (
        'Implemented assessment API. Paths include the actual backend prefix. '
        'Mobile request/response fields use snake_case. Admin model-backed fields use camelCase; '
        'unmodelled action, import, preview and audit responses use snake_case. '
        'Free-form editorial payloads and computed commentary/action-plan bodies are extensible objects.')
    doc['components']['schemas'].update(copy.deepcopy(shared_schemas()))
    doc['components']['securitySchemes']['HTTPBearer'].update({
        'bearerFormat': 'JWT', 'description':
        'Mobile access JWT and live session.' if kind == 'mobile' else
        'Admin access JWT and live session; assessment.read is required on every endpoint.'})
    if kind == 'mobile':
        doc['components']['schemas'].update(mobile_schemas())
    else:
        doc['components']['schemas'].update({
            'SavedAction': obj({'saved': {'const': True}}),
            'PublishSetResult': obj({'question_set_id': UUID, 'status': {'const': 'published'},
                'published_revision_count': INTEGER}),
            'ContentGate': obj({'revision': INTEGER, 'blockers': array(STRING),
                'reviews': {'type': 'object', 'additionalProperties': OPEN}}),
            'TransferRow': OPEN,
            'ImportPreview': obj({'rows': array(ref('TransferRow')),
                'errors': array(obj({'row': {'type': 'integer'}, 'message': STRING})),
                'changes': array(OPEN), 'fingerprint': STRING}),
            'ImportCounts': obj({'created': INTEGER, 'revised': INTEGER, 'unchanged': INTEGER}),
            'AuditEvent': obj({'id': INTEGER, 'action': STRING, 'created_at': DATETIME,
                'before_data': nullable(OPEN), 'after_data': nullable(OPEN), 'actor': nullable(STRING)}),
        })
    routes = {(r.path, method.lower()): r for r in router.routes for method in r.methods}
    for path, item in doc['paths'].items():
        for method, operation in item.items():
            name = routes[path, method].endpoint.__name__
            if kind == 'mobile':
                operation['summary'], operation['description'] = MOBILE_DESCRIPTIONS[name]
                schema = {'overview': 'AssessmentOverview', 'history': 'AssessmentHistory'}.get(name, 'AssessmentAttempt')
                operation['responses']['200'] = response(ref(schema))
                examples = {
                    'start': {'id': '11111111-1111-4111-8111-111111111111',
                        'chronological_guidance_confirmed': False},
                    'save': {'expected_version': 1, 'answers': {'CDC-12-01': 'achieved'},
                        'regression': 'no', 'caregiver_concern': 'no'},
                    'complete': {'expected_version': 2},
                }
                if name in examples:
                    operation['requestBody']['content']['application/json']['example'] = examples[name]
            else:
                operation['description'] = 'Requires an active admin with assessment.read; actor identity is recorded for audit.'
                schema = {
                    'set_availability': ref('SavedAction'), 'delete_set': ref('SavedAction'),
                    'restore_set': ref('SavedAction'), 'order': ref('SavedAction'),
                    'publish_set': ref('PublishSetResult'), 'gate': ref('ContentGate'),
                    'review': ref('SavedAction'), 'availability': ref('SavedAction'),
                    'delete': ref('SavedAction'), 'restore': ref('SavedAction'),
                    'audit': array(ref('AuditEvent')), 'export': array(ref('TransferRow')),
                    'import_template': array(ref('TransferRow')), 'seed_preview': ref('ImportPreview'),
                    'import_preview': ref('ImportPreview'), 'import_commit': ref('ImportCounts'),
                    'preview_result': ref('ResultView'),
                }.get(name)
                if schema:
                    status = str(routes[path, method].status_code or 200)
                    operation['responses'][status] = response(schema)
                if name == 'import_commit':
                    operation['description'] += ' Use rows and fingerprint from a fresh preview. Stale fingerprint returns 409. Import saves unpublished drafts only.'
                if name == 'preview_result':
                    operation['description'] += ' Sandbox simulation using current drafts; requires an answer for every skill and all six undeleted advice variants. Does not save an attempt/result. Includes preview_diagnostics.'
                if name.startswith('release'):
                    operation['description'] += ' Publishes the current revision(s) and makes the content available after validation; distinct from the editorial publish endpoint.'
                if name in ('delete', 'delete_set', 'restore', 'restore_set'):
                    operation['description'] += ' Soft delete/restore; restored content remains hidden until explicitly released.'
                if name in ('export', 'import_template', 'import_preview', 'import_commit'):
                    operation['description'] += ' JSON rows over HTTP; CSV parsing/formatting is performed by the admin client.'
                examples = {
                    'create_set': {'code': 'blk-12m-v1', 'ageMonths': 12, 'version': '1',
                        'locale': 'vi-VN', 'sourceName': 'Bé lớn khôn'},
                    'update_set': {'sourceName': 'Bé lớn khôn'},
                    'set_availability': {'isActive': False}, 'availability': {'isActive': False},
                    'order': {'contentIds': ['11111111-1111-4111-8111-111111111111']},
                    'publish': {'expectedRevision': 1}, 'release_content': {'expectedRevision': 1},
                    'review': {'revision': 1, 'reviewType': 'qa', 'decision': 'approved'},
                }
                if name in examples:
                    operation['requestBody']['content']['application/json']['example'] = examples[name]
            operation['responses']['401'] = response(ref('AuthError'), 'Missing, expired or invalid access token/session.')
            operation['responses']['403'] = response({'anyOf': [ref('AuthError'), ref('ServiceError')]}, 'Account unavailable, insufficient permission or read-only child access.')
            operation['responses']['404'] = response(ref('ServiceError'), 'Resource missing or child access hidden from this caller.')
            operation['responses']['422'] = response({'anyOf': [ref('HTTPValidationError'), ref('ServiceError')]}, 'Request validation errors (detail array) or business validation failure (detail string).')
            operation['responses']['503'] = response({'anyOf': [ref('AuthError'), ref('ServiceError')]}, 'Authentication not configured or required published content unavailable.')
            if method != 'get':
                operation['responses']['409'] = response(ref('ServiceError'), 'Version conflict, invalid lifecycle state or unavailable milestone.')
    # FastAPI omits this definition when no route has request validation.
    doc['components']['schemas'].setdefault('HTTPValidationError', obj({'detail': array(OPEN)}, required=[]))
    output = ROOT / f'docs/api/{kind}-assessment.openapi.yaml'
    output.write_text(yaml.safe_dump(doc, allow_unicode=True, sort_keys=False, width=100), encoding='utf-8', newline='\n')
    print(f'{output.name}: {len(doc["paths"])} paths, {len(routes)} operations')


if __name__ == '__main__':
    export('mobile', mobile_router)
    export('admin', admin_router)
