"""Tải model MediaPipe (Google, giấy phép Apache 2.0) khi máy chủ chưa có."""

import logging
import urllib.request
from pathlib import Path

log = logging.getLogger(__name__)

URLS = {
    "pose_landmarker_full.task": "https://storage.googleapis.com/mediapipe-models/"
    "pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task",
    "hand_landmarker.task": "https://storage.googleapis.com/mediapipe-models/"
    "hand_landmarker/hand_landmarker/float16/latest/hand_landmarker.task",
}


def download(path: Path) -> None:
    """Tải một model về `path` (tên file phải có trong URLS). Bỏ qua nếu đã có."""
    if path.is_file() and path.stat().st_size > 0:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".part")
    try:
        urllib.request.urlretrieve(URLS[path.name], tmp)
        tmp.replace(path)
    finally:
        tmp.unlink(missing_ok=True)


def ensure(paths: list[str]) -> None:
    """Tải các model còn thiếu; lỗi mạng chỉ ghi log (đo vận động tạm thời bị bỏ qua)."""
    for raw in paths:
        path = Path(raw)
        if path.is_file():
            continue
        if path.name not in URLS:
            log.warning("Không có model %s và không biết tải ở đâu", path)
            continue
        try:
            log.info("Đang tải model %s…", path.name)
            download(path)
            log.info("Đã tải %s", path)
        except OSError as e:
            log.warning("Chưa tải được %s (%s) — video vẫn được phân tích, chỉ thiếu số đo", path.name, e)
