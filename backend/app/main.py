from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.features.activities.router import admin_router as activities_admin_router
from app.features.activities.router import router as activities_router
from app.features.auth.setup import install_auth
from app.features.growth.router import router as growth_router
from app.features.children.router import router as children_router
from app.features.growth.errors import GrowthError
from fastapi.responses import JSONResponse
from app.features.dev.router import router as dev_router
from app.features.diary.router import router as diary_router
from app.features.diary_ai.router import router as diary_ai_router
from app.features.vaccination.router import admin_router as vaccination_admin_router
from app.features.vaccination.router import router as vaccination_router
from app.features.teething.router import router as teething_router
from app.features.sharing.router import router as sharing_router

app = FastAPI(title="Track Children API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=(
        r"http://(localhost|127\.0\.0\.1)(:[0-9]+)?"
        if settings.app_env == "local"
        else None
    ),
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(activities_router)
app.include_router(activities_admin_router)
app.include_router(vaccination_router)
app.include_router(teething_router)
app.include_router(sharing_router)
app.include_router(vaccination_admin_router)
app.include_router(diary_router)
app.include_router(diary_ai_router)
app.include_router(dev_router)
app.include_router(growth_router)
app.include_router(children_router)
install_auth(app)

# Ảnh hoạt động (activity.activities.thumbnail_url, activity_steps.image_url, activity_media.url)
app.mount("/static", StaticFiles(directory=Path(__file__).resolve().parents[1] / "static"), name="static")


@app.on_event('startup')
def growth_startup():
    from app.features.growth.anthro_client import startup_check
    startup_check()


@app.exception_handler(GrowthError)
async def growth_error(request, exc):
    return JSONResponse({'error':{'code':exc.code,'message':exc.code,'fields':exc.fields,'details':{}}},
                        status_code=exc.status_code,headers={'Cache-Control':'no-store'})


@app.middleware('http')
async def growth_private_response(request, call_next):
    response = await call_next(request)
    if request.url.path.startswith('/api/v1/children/') and '/growth' in request.url.path:
        response.headers['Cache-Control']='no-store'
    return response


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    from app.features.growth.anthro_client import HEALTH
    return {"status": "ok", "growth_engine": HEALTH['status']}
