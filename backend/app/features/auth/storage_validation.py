"""Shape checks for compact auth JSON; snapshots remain immutable."""
from datetime import datetime
import re

HASH = re.compile(r'^[0-9a-f]{64}$')
SYSTEM_KEYS = frozenset({'limiter', 'notice', 'appleEvent'})


def valid_devices(value):
    if not isinstance(value, list) or len(value) > 16:
        return False
    seen = set()
    for item in value:
        if not isinstance(item, dict):
            return False
        digest, when = item.get('hash'), item.get('lastAuthenticatedAt')
        if not isinstance(digest, str) or not HASH.fullmatch(digest) or digest in seen or not isinstance(when, str):
            return False
        try:
            timestamp = datetime.fromisoformat(when.replace('Z', '+00:00'))
            if timestamp.tzinfo is None or not re.search(r'(Z|[+-][0-9]{2}:[0-9]{2})$', when):
                return False
        except ValueError:
            return False
        seen.add(digest)
    return True


def valid_documents(value):
    if not isinstance(value, list) or not value:
        return False
    seen = set()
    for item in value:
        if not isinstance(item, dict):
            return False
        kind, version, digest = item.get('type'), item.get('version'), item.get('sha256')
        if not isinstance(kind, str) or kind not in {'terms', 'privacy', 'data_policy'} or kind in seen:
            return False
        if not isinstance(version, str) or not 1 <= len(version.strip()) <= 20:
            return False
        if not isinstance(digest, str) or not HASH.fullmatch(digest):
            return False
        seen.add(kind)
    return True


def validate_metadata(purpose, value):
    if not isinstance(value, dict):
        raise ValueError('Auth metadata must be an object')
    kinds = SYSTEM_KEYS.intersection(value)
    if len(kinds) > 1 or (kinds and purpose != 'reauth') or 'legacyCode' in value:
        raise ValueError('Auth record kinds cannot overlap')
    return value
