import os
from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import psycopg
from app.features.growth.router import router as growth_router
from app.features.mobile_session import router as session_router
from app.shared.errors import ApiError, error_body

app = FastAPI(title="Track Children API", version="0.1.0")
app.include_router(growth_router)
app.include_router(session_router)
app.add_middleware(CORSMiddleware,
    allow_origins=[v.strip() for v in os.environ.get('CORS_ORIGINS', '').split(',') if v.strip()],
    allow_methods=['GET', 'POST', 'PUT', 'DELETE'],
    allow_headers=['Authorization', 'Content-Type'])


@app.exception_handler(ApiError)
async def api_error(request, exc):
    return JSONResponse(error_body(exc.code, exc.fields), status_code=exc.status,
                        headers={'Cache-Control': 'no-store', **({'WWW-Authenticate': 'Bearer'} if exc.status == 401 else {})})


@app.exception_handler(RequestValidationError)
async def validation_error(request, exc):
    fields = {'.'.join(str(p) for p in e['loc'][1:]): e['msg'] for e in exc.errors()}
    return JSONResponse(error_body('VALIDATION_ERROR', fields), status_code=422)


@app.exception_handler(psycopg.Error)
async def database_error(request, exc):
    return JSONResponse(error_body('DATABASE_UNAVAILABLE'), status_code=503)


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
