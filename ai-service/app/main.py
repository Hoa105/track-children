import datetime as dt
import logging
import os
import threading
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.core.config import settings
from app.insights.repository import PgInsightStore
from app.insights.router import router as insights_router
from app.insights.service import ProcessOptions
from app.insights.worker import InsightWorker
from app.pose import model_files
from app.pose.evidence import PoseModels

logging.basicConfig(level=logging.INFO)


def process_options() -> ProcessOptions:
    return ProcessOptions(
        max_frames=settings.llm_max_frames,
        frame_max_side=settings.llm_frame_max_side,
        min_seconds=settings.min_video_seconds,
        max_seconds=settings.max_video_seconds,
        max_attempts=settings.max_attempts,
        pose_enabled=settings.pose_enabled,
        pose_models=PoseModels(
            pose_model_path=settings.pose_model_path,
            hand_model_path=settings.hand_model_path,
            sample_fps=settings.pose_sample_fps,
        ),
    )


def video_analyzer():
    """AI xem video theo LLM_PROVIDER; cảnh báo ngay khi khởi động nếu thiếu khóa."""
    log = logging.getLogger(__name__)
    if settings.llm_provider == "claude":
        from app.llm.client import ClaudeVideoAnalyzer

        if not (os.environ.get("ANTHROPIC_API_KEY") or os.environ.get("ANTHROPIC_AUTH_TOKEN")):
            log.warning("ANTHROPIC_API_KEY chưa được đặt — mọi video sẽ phân tích thất bại")
        return ClaudeVideoAnalyzer(settings.llm_model, settings.llm_effort)
    if settings.llm_provider != "gemini":
        raise ValueError(f"LLM_PROVIDER không hợp lệ: {settings.llm_provider} (gemini | claude)")
    from app.llm.gemini import GeminiVideoAnalyzer

    if not settings.gemini_api_key:
        log.warning("GEMINI_API_KEY chưa được đặt — mọi video sẽ phân tích thất bại")
    log.info("Video AI: Gemini %s", settings.gemini_model)
    return GeminiVideoAnalyzer(settings.gemini_model, settings.gemini_api_key)


@asynccontextmanager
async def lifespan(app: FastAPI):
    store = getattr(app.state, "insight_store", None) or PgInsightStore()
    app.state.insight_store = store
    worker = None
    if settings.worker_enabled and settings.pose_enabled:
        # Image build không tải được model (lỗi mạng) thì tải ở nền, không chặn khởi động
        threading.Thread(
            target=model_files.ensure,
            args=([settings.pose_model_path, settings.hand_model_path],),
            name="mediapipe-models",
            daemon=True,
        ).start()
    if settings.worker_enabled:
        worker = InsightWorker(
            store,
            video_analyzer(),
            process_options(),
            poll_seconds=settings.worker_poll_seconds,
            stale_after=dt.timedelta(minutes=settings.stale_running_minutes),
        )
        worker.start()
    yield
    if worker:
        worker.stop()


app = FastAPI(title="Track Children AI Service", version="0.1.0", lifespan=lifespan)
app.include_router(insights_router)


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    return {"status": "ok"}
