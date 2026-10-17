from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
import psycopg
from app.features.auth.router import router
from app.features.auth.service import failure
from app.core.config import settings
from fastapi.middleware.cors import CORSMiddleware
from app.shared.access import AuthenticationRequired

app = FastAPI(title="Track Children API", version="0.1.0")
app.include_router(router)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins,
                   allow_methods=['GET', 'POST'], allow_headers=['Content-Type', 'Authorization'])


@app.exception_handler(AuthenticationRequired)
async def authentication_error(request, exc):
    return exc.response


@app.exception_handler(RequestValidationError)
async def validation_error(request, exc):
    fields = {'.'.join(str(p) for p in e['loc'][1:]): e['msg'] for e in exc.errors()}
    return failure(422, 'VALIDATION_ERROR', fields=fields)


@app.exception_handler(psycopg.Error)
async def database_error(request, exc):
    return failure(503, 'DATABASE_UNAVAILABLE')


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
