"""New credentials only. Legacy password login must not use these validators."""
import unicodedata
from pathlib import Path
from functools import lru_cache

import phonenumbers
import regex
from email_validator import validate_email, EmailNotValidError

from app.core.config import settings


def phone(value):
    value = value.strip()
    if not regex.fullmatch(r'(?:0[0-9]{9}|\+84[0-9]{9})', value):
        raise ValueError('Invalid Vietnamese mobile number')
    number = phonenumbers.parse(value, 'VN')
    if (not phonenumbers.is_valid_number(number) or number.country_code != 84
            or phonenumbers.number_type(number) not in
            (phonenumbers.PhoneNumberType.MOBILE, phonenumbers.PhoneNumberType.FIXED_LINE_OR_MOBILE)):
        raise ValueError('Invalid Vietnamese mobile number')
    return phonenumbers.format_number(number, phonenumbers.PhoneNumberFormat.E164)


def email(value):
    value = value.strip()
    if not value.isascii() or len(value) > 254:
        raise ValueError('Invalid email')
    try:
        result = validate_email(value, check_deliverability=False, allow_smtputf8=False)
    except EmailNotValidError as exc:
        raise ValueError('Invalid email') from exc
    # Preserve existing case-insensitive lookup/unique policy, without Gmail rules.
    return result.normalized.lower()


def name(value):
    value = unicodedata.normalize('NFC', value.strip())
    if not 1 <= len(regex.findall(r'\X', value)) <= 50:
        raise ValueError('Display name must contain 1–50 characters')
    if any(unicodedata.category(c).startswith('C') for c in value):
        raise ValueError('Invalid display name')
    return value


def blocklist(path):
    if not path:
        return frozenset()
    try:
        info=Path(path).stat()
        return _blocklist(path,info.st_mtime_ns,info.st_size)
    except OSError as exc:
        raise ValueError('Password policy is unavailable') from exc


@lru_cache(maxsize=4)
def _blocklist(path,modified,size):
    return frozenset(v.casefold() for v in Path(path).read_text(encoding='utf-8').splitlines())


def password(value):
    if not 8 <= len(value) <= 64 or any(not 33 <= ord(c) <= 126 for c in value):
        raise ValueError('Password must be 8–64 printable ASCII characters without spaces')
    # Configured local file; never send plaintext passwords to a third party.
    denied = blocklist(settings.auth_password_blocklist_path)
    if value.casefold() in denied:
        raise ValueError('Password is blocked')
    return value
