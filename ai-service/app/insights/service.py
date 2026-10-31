"""Xử lý một job: kiểm tra video → (vận động) đo MediaPipe → gọi AI → lưu kết quả.

Video luôn bị xóa khi job kết thúc (done / rejected / failed); chỉ giữ lại khi
còn chờ thử lại.
"""

import datetime as dt
import logging
from dataclasses import dataclass
from pathlib import Path

from app.llm.client import LLMError, TransientLLMError, VideoAnalyzer
from app.insights.repository import InsightStore
from app.pose import evidence as pose_evidence
from app.schemas.insight import MOTOR_GROUPS, Evidence, Insight, InsightContext
from app.video import frames as video_frames
from app.video import quality

log = logging.getLogger(__name__)

FAILED_MESSAGE = "Chưa phân tích được video lúc này. Ba mẹ thử gửi lại sau ít phút nhé."


@dataclass(frozen=True)
class ProcessOptions:
    max_frames: int
    frame_max_side: int
    min_seconds: float
    max_seconds: float
    max_attempts: int
    pose_enabled: bool
    pose_models: pose_evidence.PoseModels


def retry_delay(attempt: int) -> dt.timedelta:
    return dt.timedelta(seconds=30 * 2 ** (attempt - 1))  # 30 s, 60 s, 120 s…


def _remove(path: str | None) -> None:
    if path:
        Path(path).unlink(missing_ok=True)


def measure_evidence(path, info, context: InsightContext, options: ProcessOptions) -> Evidence | None:
    if not options.pose_enabled or context.activity.group not in MOTOR_GROUPS:
        return None
    return pose_evidence.measure(path, info, context.metrics, options.pose_models)


def read_video(path: str, options: ProcessOptions) -> tuple[str, video_frames.VideoInfo, list]:
    """(đường dẫn đọc được, thông tin, khung hình). OpenCV không giải mã được
    (vd. AV1) thì chuyển sang H.264 bằng ffmpeg rồi đọc lại."""
    try:
        info = video_frames.probe(path)
        frames = video_frames.sample(path, info, options.max_frames, options.frame_max_side)
        if frames:
            return path, info, frames
    except video_frames.UnreadableVideo:
        pass
    converted = video_frames.transcode(path)
    if converted is None:
        raise video_frames.UnreadableVideo("Máy chủ chưa đọc được định dạng video này")
    try:
        info = video_frames.probe(converted)
        frames = video_frames.sample(converted, info, options.max_frames, options.frame_max_side)
    except video_frames.UnreadableVideo:
        _remove(converted)
        raise
    return converted, info, frames


def process(job: dict, store: InsightStore, analyzer: VideoAnalyzer, options: ProcessOptions) -> None:
    insight_id, path = job["id"], job["video_path"]
    finished = True
    converted = None
    try:
        if not path or not Path(path).is_file():
            store.fail(insight_id, "video file missing", FAILED_MESSAGE)
            return
        context = InsightContext.model_validate(job["context"])
        try:
            readable, info, frames = read_video(path, options)
        except video_frames.UnreadableVideo as e:
            store.reject(insight_id, f"{e}. Ba mẹ thử quay lại hoặc chọn video khác nhé.", None)
            return
        if readable != path:
            converted = readable

        report = quality.assess(info, frames, options.min_seconds, options.max_seconds)
        if report.reject_reason:
            store.reject(insight_id, report.reject_reason, round(info.seconds, 1))
            return

        evidence = measure_evidence(readable, info, context, options)
        try:
            analysis = analyzer.analyze(context, frames, info.seconds, report.notes, evidence)
        except TransientLLMError as e:
            if job["attempts"] < options.max_attempts:
                finished = False
                store.retry_later(
                    insight_id, str(e), dt.datetime.now(dt.timezone.utc) + retry_delay(job["attempts"])
                )
            else:
                store.fail(insight_id, str(e), FAILED_MESSAGE)
            return
        except LLMError as e:
            store.fail(insight_id, str(e), FAILED_MESSAGE)
            return

        store.complete(
            insight_id,
            result=analysis.result.model_dump(mode="json", by_alias=True),
            evidence=evidence.model_dump(mode="json", by_alias=True) if evidence else None,
            video_seconds=round(info.seconds, 1),
            model=analysis.model,
            prompt_version=analysis.prompt_version,
            usage=analysis.usage,
        )
    except Exception as e:  # noqa: BLE001 — lỗi không lường trước: đánh dấu failed, không treo job
        log.exception("Video insight %s failed", insight_id)
        store.fail(insight_id, repr(e), FAILED_MESSAGE)
    finally:
        _remove(converted)  # bản chuyển mã chỉ dùng trong lần xử lý này
        if finished:
            _remove(path)
            store.clear_video(insight_id)


def to_insight(row: dict) -> Insight:
    return Insight(
        id=row["id"],
        child_id=row["child_id"],
        activity_ref=row["activity_ref"],
        status=row["status"],
        message=row["message"],
        result=row["result"],
        evidence=row["evidence"],
        created_at=row["created_at"],
        finished_at=row["finished_at"],
    )
