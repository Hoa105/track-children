"""Mount auth routes and map auth errors without changing other API features."""

import psycopg
from fastapi.exceptions import RequestValidationError
from fastapi.exception_handlers import request_validation_exception_handler

from app.features.auth.dependencies import AuthenticationRequired
from app.features.auth.errors import failure
from app.features.auth.presenters import output
from app.features.auth.router import router


def install_auth(app):
    app.include_router(router)

    @app.exception_handler(AuthenticationRequired)
    async def authentication_error(request, exc):
        return exc.response

    @app.exception_handler(RequestValidationError)
    async def validation_error(request, exc):
        path = request.url.path
        if path == "/api/v1/legal-documents" or path.startswith("/api/v1/auth/"):
            fields = {
                ".".join(str(p) for p in e["loc"][1:]): e["msg"] for e in exc.errors()
            }
            return output(failure(422, "VALIDATION_ERROR", fields=fields))
        return await request_validation_exception_handler(request, exc)

    @app.exception_handler(psycopg.Error)
    async def database_error(request, exc):
        return output(failure(503, "DATABASE_UNAVAILABLE"))
