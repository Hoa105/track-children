from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.features.dev.router import router as dev_router
from app.features.vaccination.router import admin_router as vaccination_admin_router
from app.features.vaccination.router import router as vaccination_router

app = FastAPI(title="Track Children API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(vaccination_router)
app.include_router(vaccination_admin_router)
app.include_router(dev_router)


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
