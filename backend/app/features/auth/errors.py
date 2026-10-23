"""Auth failures are values so security counters commit before HTTP errors."""

from dataclasses import dataclass, field
from typing import Any


@dataclass
class AuthFailure:
    status_code: int
    code: str
    details: dict[str, Any] = field(default_factory=dict)
    fields: dict[str, str] = field(default_factory=dict)
    retry: int | None = None


def failure(status, code, *, details=None, retry=None, fields=None):
    return AuthFailure(status, code, details or {}, fields or {}, retry)
