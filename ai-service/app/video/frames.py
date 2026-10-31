"""Video metadata and frame sampling (OpenCV)."""

import shutil
import subprocess
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np


class UnreadableVideo(Exception):
    pass


@dataclass(frozen=True)
class VideoInfo:
    fps: float
    frame_count: int
    width: int
    height: int

    @property
    def seconds(self) -> float:
        return self.frame_count / self.fps


@dataclass(frozen=True)
class Frame:
    t: float  # giây kể từ đầu video
    jpeg: bytes
    brightness: float  # độ sáng trung bình 0–255


def probe(path: str) -> VideoInfo:
    cap = cv2.VideoCapture(path)
    try:
        if not cap.isOpened():
            raise UnreadableVideo("Không mở được video")
        fps = cap.get(cv2.CAP_PROP_FPS)
        count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    finally:
        cap.release()
    if not fps or fps <= 0 or count <= 0 or width <= 0 or height <= 0:
        raise UnreadableVideo("Video không có khung hình hợp lệ")
    return VideoInfo(fps=fps, frame_count=count, width=width, height=height)


def _resize(image: np.ndarray, max_side: int) -> np.ndarray:
    h, w = image.shape[:2]
    scale = max_side / max(h, w)
    if scale >= 1:
        return image
    return cv2.resize(image, (round(w * scale), round(h * scale)), interpolation=cv2.INTER_AREA)


def sample_times(seconds: float, count: int) -> list[float]:
    """`count` mốc cách đều, bỏ nửa khoảng đầu / cuối (tránh khung đen lúc bắt đầu quay)."""
    if count <= 0 or seconds <= 0:
        return []
    step = seconds / count
    return [round(step * (i + 0.5), 2) for i in range(count)]


def sample(path: str, info: VideoInfo, count: int, max_side: int) -> list[Frame]:
    """Khung hình JPEG cách đều để gửi cho AI."""
    frames: list[Frame] = []
    cap = cv2.VideoCapture(path)
    try:
        for t in sample_times(info.seconds, count):
            cap.set(cv2.CAP_PROP_POS_FRAMES, min(int(t * info.fps), info.frame_count - 1))
            ok, image = cap.read()
            if not ok:
                continue
            image = _resize(image, max_side)
            ok, buf = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, 85])
            if ok:
                gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
                frames.append(Frame(t=t, jpeg=buf.tobytes(), brightness=float(gray.mean())))
    finally:
        cap.release()
    return frames


def transcode(path: str) -> str | None:
    """Chuyển video sang H.264 / 30 fps cố định bằng ffmpeg.

    Dùng khi OpenCV không giải mã được (AV1, một số HEVC, video tốc độ khung
    thay đổi). Trả None nếu máy chủ không có ffmpeg hoặc chuyển thất bại.
    """
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        return None
    out = str(Path(path).with_name(f"{Path(path).stem}.h264.mp4"))
    try:
        subprocess.run(
            [ffmpeg, "-y", "-loglevel", "error", "-i", path, "-an",
             "-vf", "scale='min(1280,iw)':-2", "-r", "30",
             "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", out],
            check=True, timeout=180, capture_output=True,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        Path(out).unlink(missing_ok=True)
        return None
    return out


def iter_rgb(path: str, info: VideoInfo, target_fps: float) -> Iterator[tuple[float, np.ndarray]]:
    """(giây, ảnh RGB) với tần suất ~target_fps — đầu vào cho MediaPipe."""
    step = max(1, round(info.fps / target_fps))
    cap = cv2.VideoCapture(path)
    try:
        index = 0
        while True:
            ok = cap.grab()
            if not ok:
                break
            if index % step == 0:
                ok, image = cap.retrieve()
                if ok:
                    yield index / info.fps, cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            index += 1
    finally:
        cap.release()
