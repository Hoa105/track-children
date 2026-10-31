from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.features.activities.router import admin_router as activities_admin_router
from app.features.activities.router import router as activities_router
from app.features.auth.setup import install_auth
from app.features.dev.router import router as dev_router
from app.features.diary.router import router as diary_router
from app.features.diary_ai.router import router as diary_ai_router
from app.features.vaccination.router import admin_router as vaccination_admin_router
from app.features.vaccination.router import router as vaccination_router

app = FastAPI(title="Track Children API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(activities_router)
app.include_router(activities_admin_router)
app.include_router(vaccination_router)
app.include_router(vaccination_admin_router)
app.include_router(diary_router)
app.include_router(diary_ai_router)
app.include_router(dev_router)
install_auth(app)

# Ảnh hoạt động (activity.activities.thumbnail_url, activity_steps.image_url, activity_media.url)
app.mount("/static", StaticFiles(directory=Path(__file__).resolve().parents[1] / "static"), name="static")


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
