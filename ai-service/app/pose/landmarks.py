"""Chạy MediaPipe Pose / Hand Landmarker trên video → PoseSeries / HandSeries.

MediaPipe chỉ được import khi cần, để giai đoạn 1 chạy được cả khi chưa cài
hoặc chưa tải model.
"""

import numpy as np

from app.pose.metrics import CORE, L_HIP, L_SHOULDER, R_HIP, R_SHOULDER, HandSeries, PoseSeries
from app.video.frames import VideoInfo, iter_rgb


def _pick_child(candidates: list[np.ndarray], previous_center: np.ndarray | None) -> np.ndarray:
    """Trong khung có nhiều người (vd. ba mẹ đứng cạnh), chọn bé.

    Khung đầu: người có thân ngắn nhất. Các khung sau: người gần vị trí bé ở khung trước.
    """

    def center(kp):
        return kp[list(CORE), :2].mean(axis=0)

    if previous_center is None:
        def torso(kp):
            return np.linalg.norm(
                (kp[L_SHOULDER, :2] + kp[R_SHOULDER, :2]) / 2 - (kp[L_HIP, :2] + kp[R_HIP, :2]) / 2
            )

        return min(candidates, key=torso)
    return min(candidates, key=lambda kp: np.linalg.norm(center(kp) - previous_center))


def extract_pose(path: str, info: VideoInfo, model_path: str, fps: float) -> PoseSeries:
    import mediapipe as mp
    from mediapipe.tasks.python import BaseOptions
    from mediapipe.tasks.python import vision

    aspect = info.width / info.height
    options = vision.PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=model_path),
        running_mode=vision.RunningMode.VIDEO,
        num_poses=2,
        min_pose_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    times, frames = [], []
    previous_center = None
    with vision.PoseLandmarker.create_from_options(options) as landmarker:
        for t, rgb in iter_rgb(path, info, fps):
            image = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb))
            result = landmarker.detect_for_video(image, int(t * 1000))
            kp = np.full((33, 3), np.nan)
            candidates = [
                np.array([[lm.x * aspect, lm.y, lm.visibility] for lm in pose])
                for pose in result.pose_landmarks
            ]
            if candidates:
                kp = _pick_child(candidates, previous_center)
                previous_center = kp[list(CORE), :2].mean(axis=0)
            times.append(t)
            frames.append(kp)
    return PoseSeries(t=np.array(times), kp=np.array(frames).reshape(-1, 33, 3))


def extract_hands(path: str, info: VideoInfo, model_path: str, fps: float) -> HandSeries:
    import mediapipe as mp
    from mediapipe.tasks.python import BaseOptions
    from mediapipe.tasks.python import vision

    aspect = info.width / info.height
    options = vision.HandLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=model_path),
        running_mode=vision.RunningMode.VIDEO,
        num_hands=2,
        min_hand_detection_confidence=0.5,
    )
    times, frames = [], []
    with vision.HandLandmarker.create_from_options(options) as landmarker:
        for t, rgb in iter_rgb(path, info, fps):
            image = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.ascontiguousarray(rgb))
            result = landmarker.detect_for_video(image, int(t * 1000))
            hands = np.full((2, 21, 2), np.nan)
            for landmarks, handedness in zip(result.hand_landmarks, result.handedness):
                side = 0 if handedness[0].category_name == "Left" else 1
                hands[side] = [[lm.x * aspect, lm.y] for lm in landmarks]
            times.append(t)
            frames.append(hands)
    return HandSeries(t=np.array(times), hands=np.array(frames).reshape(-1, 2, 21, 2))
