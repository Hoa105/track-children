"""Provider-verified identities. No automatic linking by email; no demo bypass."""
import hmac
import secrets
from datetime import timedelta
from functools import lru_cache
from pathlib import Path

import httpx
import jwt
import psycopg
from pydantic import EmailStr, TypeAdapter, ValidationError

from app.core import security as sec
from app.core.config import settings
from app.features.auth.errors import AuthFailure, failure
from app.features.auth.registration import legal


@lru_cache(maxsize=2)
def keys(provider):
    url = ('https://www.googleapis.com/oauth2/v3/certs' if provider == 'google'
           else 'https://appleid.apple.com/auth/keys')
    return jwt.PyJWKClient(url, timeout=5, lifespan=3600)


def apple_configured():
    return bool(settings.apple_client_ids and settings.apple_team_id
                and settings.apple_key_id and settings.apple_private_key_path)


def apple_challenge():
    if not apple_configured():
        return failure(503, 'SOCIAL_AUTH_NOT_CONFIGURED')
    nonce = secrets.token_urlsafe(32)
    return {'nonce': nonce, 'challenge': jwt.encode({
        'nonce': nonce, 'jti': secrets.token_urlsafe(32), 'iat': sec.now(),
        'exp': sec.now()+timedelta(minutes=10), 'iss': settings.auth_issuer,
        'aud': 'track-children-apple-challenge',
    }, settings.auth_secret, algorithm='HS256')}


def verify_identity(data):
    audiences = settings.google_client_ids if data.provider == 'google' else settings.apple_client_ids
    if not audiences or (data.provider == 'apple' and not apple_configured()):
        return failure(503, 'SOCIAL_AUTH_NOT_CONFIGURED')
    try:
        signing = keys(data.provider).get_signing_key_from_jwt(data.idToken)
        issuers = ['accounts.google.com', 'https://accounts.google.com'] if data.provider == 'google' else ['https://appleid.apple.com']
        claims = jwt.decode(data.idToken, signing.key, algorithms=['RS256'],
            audience=audiences, issuer=issuers,
            options={'require': ['sub','iss','aud','exp','iat']}, leeway=30)
        if not isinstance(claims['sub'], str) or not 1 <= len(claims['sub']) <= 255:
            raise ValueError()
        if data.provider == 'apple':
            challenge = jwt.decode(data.challenge or '', settings.auth_secret, algorithms=['HS256'],
                audience='track-children-apple-challenge', issuer=settings.auth_issuer,
                options={'require': ['nonce','jti','exp','iat']})
            if not hmac.compare_digest(str(claims.get('nonce','')), challenge['nonce']):
                raise ValueError()
            if not data.authorizationCode:
                raise ValueError()
            # Exchange the one-time authorization code as well as verifying the ID token.
            client = claims['aud']
            if not isinstance(client, str):
                raise ValueError()
            secret = jwt.encode({'iss': settings.apple_team_id, 'sub': client,
                'aud': 'https://appleid.apple.com', 'iat': sec.now(),
                'exp': sec.now()+timedelta(minutes=5)},
                Path(settings.apple_private_key_path).read_text(encoding='utf-8'),
                algorithm='ES256', headers={'kid': settings.apple_key_id})
            body = {'client_id': client, 'client_secret': secret,
                    'code': data.authorizationCode, 'grant_type': 'authorization_code'}
            if data.device.platform in ('android','web'):
                body['redirect_uri'] = settings.apple_redirect_uri
            with httpx.Client(timeout=10, follow_redirects=False) as http:
                response = http.post('https://appleid.apple.com/auth/token', data=body)
            if response.status_code != 200:
                return failure(401, 'SOCIAL_TOKEN_INVALID')
            exchanged = response.json()['id_token']
            other_key = keys('apple').get_signing_key_from_jwt(exchanged)
            other = jwt.decode(exchanged, other_key.key, algorithms=['RS256'],
                issuer='https://appleid.apple.com', audience=client,
                options={'require': ['sub','iss','aud','exp']})
            if other['sub'] != claims['sub'] or other.get('nonce') != claims.get('nonce'):
                raise ValueError()
        return claims
    except jwt.PyJWKClientConnectionError:
        return failure(503, 'SOCIAL_PROVIDER_UNAVAILABLE')
    except (httpx.HTTPError, OSError):
        return failure(503, 'SOCIAL_PROVIDER_UNAVAILABLE')
    except (jwt.PyJWTError, ValueError, TypeError, KeyError):
        return failure(401, 'SOCIAL_TOKEN_INVALID')


def register(db, data, claims):
    from app.features.auth.service import new_session, public_user
    if not data.acceptedTerms:
        return failure(422, 'LEGAL_CONSENT_REQUIRED')
    docs = legal()
    if isinstance(docs, AuthFailure):
        return docs
    provider, subject = data.provider, claims['sub']
    db.execute('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', ('social:'+provider+':'+subject,))
    if provider == 'apple':
        used = db.execute('''INSERT INTO account.social_challenge_uses(token_hash,expires_at)
            VALUES (%s,%s) ON CONFLICT DO NOTHING RETURNING token_hash''',
            (sec.secret_hash(data.challenge), sec.now()+timedelta(minutes=10))).fetchone()
        if not used:
            return failure(401, 'SOCIAL_TOKEN_INVALID')
        db.execute('DELETE FROM account.social_challenge_uses WHERE expires_at < %s', (sec.now(),))
    user = db.execute('''SELECT u.* FROM account.users u JOIN account.social_identities i
        ON i.user_id=u.id WHERE i.provider=%s AND i.subject=%s FOR UPDATE OF u''', (provider,subject)).fetchone()
    created = user is None
    if created:
        if claims.get('email_verified') not in (True, 'true'):
            return failure(403, 'SOCIAL_EMAIL_NOT_VERIFIED')
        try:
            email = str(TypeAdapter(EmailStr).validate_python(claims.get('email'))).lower()
        except ValidationError:
            return failure(403, 'SOCIAL_EMAIL_NOT_VERIFIED')
        db.execute('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', ('registration:'+email,))
        if db.execute('SELECT id FROM account.users WHERE email=%s', (email,)).fetchone():
            return failure(409, 'SOCIAL_ACCOUNT_CONFLICT')
        try:
            with db.transaction():
                name = (str(claims.get('name') or data.displayName).strip() or 'Phụ huynh')[:150]
                user = db.execute('''INSERT INTO account.users
                    (email,password_hash,display_name,default_relationship,status,consented_at,email_verified_at)
                    VALUES (%s,'!social',%s,%s,'active',%s,%s) RETURNING *''',
                    (email,name,data.defaultRelationship,sec.now(),sec.now())).fetchone()
                db.execute('INSERT INTO account.social_identities(provider,subject,user_id) VALUES (%s,%s,%s)',
                    (provider,subject,user['id']))
        except psycopg.errors.UniqueViolation:
            return failure(409, 'SOCIAL_ACCOUNT_CONFLICT')
    if user['status'] != 'active':
        return failure(403, 'ACCOUNT_UNAVAILABLE')
    return {**new_session(db,user,data.device,data.rememberMe), 'user':public_user(user), 'isNewUser':created}
