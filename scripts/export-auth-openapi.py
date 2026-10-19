"""Refresh checked-in auth documentation from Markdown and request models.

Run after editing the contract: python scripts/export-auth-openapi.py.
Response/error examples remain manually reviewed in the OpenAPI source file.
"""
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'backend'))
from app.features.auth import schemas  # noqa: E402


def main():
    path = root / 'docs/api/mobile-auth.openapi.json'
    document = json.loads(path.read_text(encoding='utf-8'))
    source = (root / 'docs/api/mobile-auth.md').read_text(encoding='utf-8')
    document['info']['version'] = '1.0.0'
    document['info']['description'] = source[:source.index('## 2.')].strip()
    document['servers'][0]['description'] = 'Local backend'
    document['x-status'] = 'implemented'
    sections = {int(m.group(1)): m.group(2).strip() for m in re.finditer(
        r'^## (\d+)\. (.*?)(?=^## |\Z)', source, re.M | re.S)}
    endpoints = [('/legal-documents', 4), ('/auth/register', 5),
                 ('/auth/register/verify', 6), ('/auth/register/resend', 7),
                 ('/auth/login', 8), ('/auth/refresh', 9), ('/auth/logout', 10), ('/auth/me', 11)]
    for endpoint, section in endpoints:
        for operation in document['paths'][endpoint].values():
            operation['description'] = sections[section].partition('\n')[2].strip()
            codes = ['DATABASE_UNAVAILABLE']
            if endpoint.startswith('/auth/'):
                codes.append('AUTH_NOT_CONFIGURED')
            if endpoint in ['/legal-documents', '/auth/register']:
                codes.append('LEGAL_DOCUMENTS_UNAVAILABLE')
            operation['responses']['503'] = {
                'description': '; '.join(codes),
                'content': {'application/json': {'schema': {'$ref': '#/components/schemas/Error'}}}}
    document['x-implementation-notes'] = '\n\n'.join(sections[i] for i in [12, 13, 14])
    models = [('Device', schemas.Device), ('RegisterRequest', schemas.Register),
              ('VerifyRequest', schemas.Verify), ('ResendRequest', schemas.Challenge),
              ('LoginRequest', schemas.Login), ('RefreshRequest', schemas.Refresh), ('LogoutRequest', schemas.Refresh)]
    for name, model in models:
        schema = model.model_json_schema(ref_template='#/components/schemas/{model}')
        document['components']['schemas'].update(schema.pop('$defs', {}))
        document['components']['schemas'][name] = schema
    path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Auth OpenAPI updated.')


if __name__ == '__main__':
    main()
