"""Chạy model K-DST (ONNX, CPU) trên khung xương MediaPipe của video phụ huynh.

Model và meta do `python -m training.kdst.export` tạo: <version>.onnx + <version>.json
cùng thư mục. Đầu vào phải đi qua đúng các bước như lúc train (app/kdst/skeleton.py).
"""

import json
import logging
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from app.kdst import skeleton
from app.kdst.items import ITEM_INDEX, ITEMS, SCORE_LABELS

log = logging.getLogger(__name__)

# Lúc train, chuỗi được lưu ở 128 khung rồi mới lấy về SEQ_LEN (training/kdst/prepare.py
# STORE_LEN, train.eval_input) — làm y hệt để đầu vào khớp từng khung.
STORE_LEN = 128

# Lý do không dùng kết quả của model (lưu DB, không hiển thị nguyên văn)
NO_BODY = "no_body"
OTHER_ITEM = "other_item"
LOW_CONFIDENCE = "low_confidence"


@dataclass(frozen=True)
class KdstAssessment:
    model_version: str
    item: str  # bài phụ huynh chọn (A01 … C04)
    level: str | None = None  # not_yet | unsteady | steady
    confidence: float | None = None  # xác suất của mức trên
    predicted_item: str | None = None  # bài model nghĩ video đang làm
    item_confidence: float | None = None
    reason: str = ""  # rỗng = đủ tin cậy để trả nhận xét mẫu

    @property
    def confident(self) -> bool:
        return self.level is not None and not self.reason

    def to_json(self) -> dict:
        return {
            "modelVersion": self.model_version,
            "item": self.item,
            "level": self.level,
            "confidence": self.confidence,
            "predictedItem": self.predicted_item,
            "itemConfidence": self.item_confidence,
            "reason": self.reason,
        }


def _softmax(x: np.ndarray) -> np.ndarray:
    e = np.exp(x - x.max())
    return e / e.sum()


class KdstScorer:
    def __init__(self, model_path: str | Path):
        import onnxruntime as ort

        path = Path(model_path)
        self.meta = json.loads(path.with_suffix(".json").read_text(encoding="utf-8"))
        if self.meta["normalization_version"] != skeleton.NORMALIZATION_VERSION:
            raise ValueError(
                f"{path.name} train với chuẩn hóa v{self.meta['normalization_version']}, "
                f"code đang là v{skeleton.NORMALIZATION_VERSION}"
            )
        if [i["code"] for i in self.meta["items"]] != [i.code for i in ITEMS]:
            raise ValueError(f"{path.name} có danh sách bài khác app/kdst/items.py")
        self.version: str = self.meta["version"]
        self.min_confidence = float(self.meta["min_confidence"])
        self.session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])

    def unusable(self, item: str, reason: str) -> KdstAssessment:
        return KdstAssessment(model_version=self.version, item=item, reason=reason)

    def probabilities(self, keypoints: np.ndarray, item: str) -> tuple[np.ndarray, np.ndarray] | None:
        """(xác suất 3 mức của bài `item`, xác suất 12 bài); None khi không thấy đủ cơ thể bé.

        keypoints: (T, 33, 3) x, y, visibility của bé (app/pose/landmarks.extract_pose).
        """
        seq = None
        if len(keypoints):
            seq = skeleton.normalize(np.stack([skeleton.from_mediapipe(f) for f in keypoints]))
        if seq is None:
            return None
        x = skeleton.to_model_input(skeleton.resample(skeleton.resample(seq, STORE_LEN)))[None]
        score_logits, item_logits = self.session.run(None, {"skeleton": x})
        return _softmax(score_logits[0, ITEM_INDEX[item]]), _softmax(item_logits[0])

    def assess(self, keypoints: np.ndarray, item: str) -> KdstAssessment:
        """keypoints: (T, 33, 3) x, y, visibility của bé (app/pose/landmarks.extract_pose)."""
        probs = self.probabilities(keypoints, item)
        if probs is None:
            return self.unusable(item, NO_BODY)
        score_prob, item_prob = probs
        level = int(score_prob.argmax())
        predicted = int(item_prob.argmax())

        reason = ""
        if ITEMS[predicted].code != item:
            reason = OTHER_ITEM  # quay nhầm bài / không phải bài này → không chấm theo bài đã chọn
        elif score_prob[level] < self.min_confidence:
            reason = LOW_CONFIDENCE
        return KdstAssessment(
            model_version=self.version,
            item=item,
            level=SCORE_LABELS[level],
            confidence=round(float(score_prob[level]), 3),
            predicted_item=ITEMS[predicted].code,
            item_confidence=round(float(item_prob[predicted]), 3),
            reason=reason,
        )


def load(model_path: str) -> KdstScorer | None:
    """None khi chưa có model hoặc chưa cài onnxruntime — các bài K-DST quay về nhánh LLM."""
    if not Path(model_path).is_file():
        log.warning("Không có model K-DST %s — các bài K-DST sẽ dùng AI qua API", model_path)
        return None
    try:
        scorer = KdstScorer(model_path)
    except (ImportError, ValueError, OSError, KeyError) as e:
        log.warning("Không nạp được model K-DST %s (%s)", model_path, e)
        return None
    log.info("Model K-DST: %s (ngưỡng tin cậy %.2f)", scorer.version, scorer.min_confidence)
    return scorer
