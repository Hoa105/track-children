"""Refresh checked-in auth documentation from Markdown and request models.

Run after editing the contract: python scripts/export-auth-openapi.py.
Response/error examples remain manually reviewed in the OpenAPI source file.
"""
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'backend'))
from app.features.auth import schemas  # noqa: E402


def main():
    path = root / 'docs/api/mobile-auth.openapi.json'
    document = json.loads(path.read_text(encoding='utf-8'))
    source = (root / 'docs/api/mobile-registration-v2.md').read_text(encoding='utf-8')
    document['info']['version'] = '2.0.0'
    document['info']['description'] = source[:source.index('## API')].strip()
    document['servers'][0]['description'] = 'Local backend'
    document['x-status'] = 'registration-implemented; password-login-pending-schema-009'
    endpoints = [('/legal-documents', 4), ('/auth/register', 5),
                 ('/auth/register/verify', 6), ('/auth/register/resend', 7),
                 ('/auth/login', 8), ('/auth/refresh', 9), ('/auth/logout', 10), ('/auth/me', 11)]
    for endpoint, section in endpoints:
        for operation in document['paths'][endpoint].values():
            operation['description'] = (
                'Password login still requires migration to schema 009.' if endpoint == '/auth/login'
                else 'Schema 009. See docs/api/mobile-registration-v2.md for behavior and deployment configuration.'
            )
            codes = ['DATABASE_UNAVAILABLE']
            if endpoint.startswith('/auth/'):
                codes.append('AUTH_NOT_CONFIGURED')
            if endpoint in ['/legal-documents', '/auth/register']:
                codes.append('LEGAL_DOCUMENTS_UNAVAILABLE')
            if endpoint in ['/auth/register', '/auth/register/resend']:
                codes.append('OTP_DELIVERY_UNAVAILABLE')
            operation['responses']['503'] = {
                'description': '; '.join(codes),
                'content': {'application/json': {'schema': {'$ref': '#/components/schemas/Error'}}}}
    document['x-implementation-notes'] = source
    models = [('Device', schemas.Device), ('RegisterRequest', schemas.Register),
              ('VerifyRequest', schemas.Verify), ('ResendRequest', schemas.Challenge),
              ('LoginRequest', schemas.Login), ('RefreshRequest', schemas.Refresh), ('LogoutRequest', schemas.Refresh),
              ('SocialRegisterRequest', schemas.SocialRegister)]
    for name, model in models:
        schema = model.model_json_schema(ref_template='#/components/schemas/{model}')
        document['components']['schemas'].update(schema.pop('$defs', {}))
        document['components']['schemas'][name] = schema
    definitions = document['components']['schemas']
    document['paths']['/auth/social'] = {'post': {
        'operationId': 'social_register', 'tags': ['Mobile Auth'],
        'description': 'Google/Apple verified sign-in. See docs/api/mobile-social-auth.md. No automatic email linking.',
        'requestBody': {'required': True, 'content': {'application/json': {
            'schema': {'$ref': '#/components/schemas/SocialRegisterRequest'}}}},
        'responses': {'200': {'description': 'App session and isNewUser',
            'content': {'application/json': {'schema': {'$ref': '#/components/schemas/AuthResult'}}}},
            '401': {'description': 'SOCIAL_TOKEN_INVALID'},
            '403': {'description': 'Unverified email or unavailable account'},
            '409': {'description': 'SOCIAL_ACCOUNT_CONFLICT'},
            '503': {'description': 'Provider not configured or unavailable'}}}}
    document['paths']['/auth/social/apple/challenge'] = {'post': {
        'operationId': 'apple_social_challenge', 'tags': ['Mobile Auth'],
        'responses': {'200': {'description': 'Ten-minute signed challenge and nonce'},
                      '503': {'description': 'SOCIAL_AUTH_NOT_CONFIGURED'}}}}
    definitions.pop('Consent', None)
    auth = definitions['AuthResult']
    auth['required'] = [field for field in auth['required'] if field != 'deletionRequestCancelled']
    user = definitions['User']
    for key in ['username', 'avatarUrl']:
        user['properties'].pop(key, None)
        user['required'] = [field for field in user['required'] if field != key]
    roles = ['mother', 'father', 'grandfather', 'grandmother', 'other_guardian']
    user['properties']['relationship'] = {'type': 'string', 'enum': roles}
    user['properties']['defaultRelationship'] = {'type': 'string', 'enum': roles}
    user['properties']['displayName'] = {'type': 'string'}
    user['properties']['phoneVerifiedAt'] = {'type': ['string', 'null'], 'format': 'date-time'}
    for key in ['displayName', 'defaultRelationship']:
        if key not in user['required']:
            user['required'].append(key)
    ch = definitions['RegistrationChallenge']
    ch['properties']['requiresOtp'] = {'type': 'boolean', 'const': True}
    ch['properties']['channel'] = {'type': 'string', 'enum': ['email', 'sms']}
    ch['properties']['devOtp'] = {'type': 'string', 'description': 'Local preview only'}
    ch['properties']['deliveryStatus']['enum'] = ['sent', 'failed', 'preview']
    legal = definitions['LegalDocumentsResult']['properties']['documents']['items']
    legal['properties'].pop('id', None)
    legal['required'] = [field for field in legal['required'] if field != 'id']
    # Old response examples describe deleted columns and the removed OTP bypass.
    def remove_examples(node):
        if isinstance(node, dict):
            node.pop('examples', None)
            node.pop('example', None)
            for value in node.values():
                remove_examples(value)
        elif isinstance(node, list):
            for value in node:
                remove_examples(value)
    remove_examples(document['paths'])
    path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Auth OpenAPI updated.')


if __name__ == '__main__':
    main()
