"""Reusable identity dependency for protected mobile API routes."""
from fastapi import Request
from fastapi.responses import Response

from app.core.database import transaction


class AuthenticationRequired(Exception):
    def __init__(self, response: Response):
        self.response = response


def require_user(request: Request) -> dict:
    # Imported lazily to keep shared access independent of router registration.
    from app.features.auth.router import current_user, ready

    error = ready()
    if error:
        raise AuthenticationRequired(error)
    with transaction() as db:
        user = current_user(request, db)
    if isinstance(user, Response):
        if user.status_code == 401:
            user.headers['WWW-Authenticate'] = 'Bearer'
        raise AuthenticationRequired(user)
    return user
