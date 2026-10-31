"""Chọn và tính số đo cho một video theo danh sách khóa backend gửi (context.metrics)."""

import logging
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from app.pose import metrics as m
from app.schemas.insight import Evidence, EvidenceMetric
from app.video.frames import VideoInfo

log = logging.getLogger(__name__)

# Dưới ngưỡng này coi như không nhận diện được bé, không gửi số đo cho AI
MIN_POSE_DETECTION = 0.4
MIN_HAND_DETECTION = 0.3


@dataclass(frozen=True)
class MetricSpec:
    label: str
    unit: str
    source: str  # "pose" | "hands"
    compute: Callable


METRICS: dict[str, MetricSpec] = {
    "upright_seconds": MetricSpec("Thời gian giữ thân thẳng (ngồi / đứng)", "giây", "pose", m.upright_seconds),
    "standing_seconds": MetricSpec("Thời gian đứng", "giây", "pose", m.standing_seconds),
    "prone_seconds": MetricSpec("Thời gian nằm sấp / thân nằm ngang", "giây", "pose", m.prone_seconds),
    "head_lift_seconds": MetricSpec("Thời gian ngẩng đầu khi nằm sấp", "giây", "pose", m.head_lift_seconds),
    "crawl_posture_seconds": MetricSpec("Thời gian ở tư thế bò (chống tay và gối)", "giây", "pose", m.crawl_posture_seconds),
    "hip_travel": MetricSpec("Quãng di chuyển", "lần chiều dài thân bé", "pose", m.hip_travel),
    "step_count": MetricSpec("Số bước chân (ước lượng)", "bước", "pose", m.step_count),
    "jump_count": MetricSpec("Số lần bật nhảy hai chân", "lần", "pose", m.jump_count),
    "single_leg_max_seconds": MetricSpec("Đứng một chân lâu nhất", "giây", "pose", m.single_leg_max_seconds),
    "arm_raise_count": MetricSpec("Số lần đưa tay lên cao quá đầu", "lần", "pose", m.arm_raise_count),
    "hand_visible_seconds": MetricSpec("Thời gian thấy rõ tay bé", "giây", "hands", m.hand_visible_seconds),
    "two_hand_seconds": MetricSpec("Thời gian dùng cả hai tay", "giây", "hands", m.two_hand_seconds),
    "pinch_count": MetricSpec("Số lần chụm ngón cái – ngón trỏ", "lần", "hands", m.pinch_count),
}


@dataclass(frozen=True)
class PoseModels:
    pose_model_path: str
    hand_model_path: str
    sample_fps: float


def _unavailable(reason: str, ratio: float | None = None) -> Evidence:
    return Evidence(available=False, reason=reason, detection_ratio=ratio)


def compute(series, keys: list[str], source: str) -> list[EvidenceMetric]:
    out = []
    for key in keys:
        spec = METRICS[key]
        if spec.source != source:
            continue
        value = spec.compute(series)
        if value is not None:
            out.append(EvidenceMetric(key=key, label=spec.label, value=round(value, 1), unit=spec.unit))
    return out


def measure(path: str, info: VideoInfo, keys: list[str], models: PoseModels) -> Evidence | None:
    """None khi hoạt động không cần số đo. Lỗi MediaPipe không làm hỏng job — chỉ bỏ số đo."""
    keys = [k for k in keys if k in METRICS]
    if not keys:
        return None
    sources = {METRICS[k].source for k in keys}
    try:
        from app.pose import landmarks
    except ImportError:  # chưa cài mediapipe
        return _unavailable("Máy chủ chưa bật đo vận động")

    try:
        result: list[EvidenceMetric] = []
        ratio = None
        if "pose" in sources:
            if not Path(models.pose_model_path).is_file():
                return _unavailable("Máy chủ chưa tải model đo vận động")
            pose = landmarks.extract_pose(path, info, models.pose_model_path, models.sample_fps)
            ratio = round(m.detection_ratio(pose), 2)
            if ratio < MIN_POSE_DETECTION:
                return _unavailable("Không nhận diện đủ rõ cơ thể bé trong video", ratio)
            result += compute(pose, keys, "pose")
        if "hands" in sources:
            if not Path(models.hand_model_path).is_file():
                return _unavailable("Máy chủ chưa tải model đo cử động tay")
            hands = landmarks.extract_hands(path, info, models.hand_model_path, models.sample_fps)
            hand_ratio = round(m.hand_detection_ratio(hands), 2)
            ratio = hand_ratio if ratio is None else min(ratio, hand_ratio)
            if hand_ratio < MIN_HAND_DETECTION:
                return _unavailable("Không thấy rõ tay bé trong phần lớn video", hand_ratio)
            result += compute(hands, keys, "hands")
    except Exception:  # noqa: BLE001 — số đo là phần bổ sung, không được làm hỏng nhận xét
        log.exception("Pose measurement failed for %s", path)
        return _unavailable("Không đo được vận động cho video này")
    return Evidence(available=bool(result), detection_ratio=ratio, metrics=result,
                    reason="" if result else "Không đo được số liệu nào")
