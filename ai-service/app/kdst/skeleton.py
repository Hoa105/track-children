"""Định dạng khung xương chung cho cả dataset (OpenPose BODY_25) và app (MediaPipe 33 điểm).

Model chỉ thấy 21 khớp mà cả hai công cụ đều có: 17 khớp COCO + gót chân + mũi bàn chân.
Mọi dữ liệu (train lẫn video thật) phải qua cùng `normalize()` + `resample()` để
model không phân biệt được nguồn.

Kênh đầu vào: (x, y, mask). Không dùng trực tiếp độ tin cậy vì score của OpenPose và
visibility của MediaPipe có thang khác nhau — chỉ giữ ngưỡng "nhìn thấy / không".
"""

import numpy as np

JOINTS = (
    "nose", "l_eye", "r_eye", "l_ear", "r_ear",
    "l_shoulder", "r_shoulder", "l_elbow", "r_elbow", "l_wrist", "r_wrist",
    "l_hip", "r_hip", "l_knee", "r_knee", "l_ankle", "r_ankle",
    "l_heel", "r_heel", "l_toe", "r_toe",
)
NUM_JOINTS = len(JOINTS)

# Chỉ số nguồn cho từng khớp trong JOINTS
FROM_BODY25 = (0, 16, 15, 18, 17, 5, 2, 6, 3, 7, 4, 12, 9, 13, 10, 14, 11, 21, 24, 19, 22)
FROM_MEDIAPIPE = (0, 2, 5, 7, 8, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32)

EDGES = (
    (0, 1), (0, 2), (1, 3), (2, 4), (0, 5), (0, 6), (5, 6),
    (5, 7), (7, 9), (6, 8), (8, 10), (5, 11), (6, 12), (11, 12),
    (11, 13), (13, 15), (12, 14), (14, 16),
    (15, 17), (15, 19), (17, 19), (16, 18), (16, 20), (18, 20),
)
# Cặp trái ↔ phải, dùng khi lật ngang (augmentation)
FLIP_PERM = (0, 2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11, 14, 13, 16, 15, 18, 17, 20, 19)

L_SHOULDER, R_SHOULDER, L_HIP, R_HIP = 5, 6, 11, 12
MIN_CONF = 0.3
SEQ_LEN = 64
NORMALIZATION_VERSION = 1


def from_body25(pose: list[float], score: list[float]) -> np.ndarray:
    """Một người trong 1 khung OpenPose (50 số + 25 score) → (21, 3) = x, y, conf."""
    xy = np.asarray(pose, dtype=np.float32).reshape(25, 2)
    conf = np.asarray(score, dtype=np.float32)
    kp = np.concatenate([xy, conf[:, None]], axis=1)[list(FROM_BODY25)]
    kp[kp[:, 2] < MIN_CONF] = 0.0  # OpenPose ghi (0, 0) cho khớp không thấy
    return kp


def from_mediapipe(landmarks: np.ndarray) -> np.ndarray:
    """(33, 3) = x, y, visibility của app/pose/landmarks.py (NaN khi không thấy) → (21, 3)."""
    kp = np.nan_to_num(np.asarray(landmarks, dtype=np.float32)[list(FROM_MEDIAPIPE)], nan=0.0)
    kp[kp[:, 2] < MIN_CONF] = 0.0
    return kp


def _center(kp: np.ndarray) -> np.ndarray | None:
    core = kp[[L_SHOULDER, R_SHOULDER, L_HIP, R_HIP]]
    seen = core[core[:, 2] > 0]
    return seen[:, :2].mean(axis=0) if len(seen) else None


def _torso(kp: np.ndarray) -> float:
    if kp[[L_SHOULDER, R_SHOULDER, L_HIP, R_HIP], 2].min() <= 0:
        return float("inf")
    shoulder = (kp[L_SHOULDER, :2] + kp[R_SHOULDER, :2]) / 2
    hip = (kp[L_HIP, :2] + kp[R_HIP, :2]) / 2
    return float(np.linalg.norm(shoulder - hip))


def pick_child(frames: list[list[np.ndarray]]) -> np.ndarray:
    """Mỗi khung có thể có nhiều người (người lớn đứng cạnh) → chuỗi (T, 21, 3) của bé.

    Cùng quy tắc với app/pose/landmarks.py: lần đầu thấy người → chọn người thân ngắn
    nhất; các khung sau → người gần vị trí bé ở khung trước. Khung không có ai → 0.
    """
    out = np.zeros((len(frames), NUM_JOINTS, 3), dtype=np.float32)
    previous = None
    for t, candidates in enumerate(frames):
        candidates = [c for c in candidates if _center(c) is not None]
        if not candidates:
            continue
        if previous is None:
            kp = min(candidates, key=_torso)
        else:
            kp = min(candidates, key=lambda c: float(np.linalg.norm(_center(c) - previous)))
        out[t] = kp
        previous = _center(kp)
    return out


def normalize(seq: np.ndarray) -> np.ndarray | None:
    """(T, 21, 3) x, y, conf → (T', 21, 3) x, y, mask đã chuẩn hóa; None nếu không dùng được.

    - Cắt các khung đầu/cuối không thấy bé.
    - Gốc tọa độ = trung điểm hông trung bình CẢ chuỗi (không theo từng khung), để giữ
      chuyển động toàn thân như bật nhảy, đi lên cầu thang.
    - Đơn vị = trung vị chiều dài thân → không phụ thuộc chiều cao bé, khoảng cách camera.
    """
    seen = seq[:, :, 2] > 0
    has_body = np.array([_center(f) is not None for f in seq])
    if has_body.sum() < 4:
        return None
    first, last = np.flatnonzero(has_body)[[0, -1]]
    seq, seen = seq[first:last + 1], seen[first:last + 1]

    hips = seq[:, [L_HIP, R_HIP]]
    hip_ok = hips[:, :, 2] > 0
    if not hip_ok.any():
        return None
    origin = hips[hip_ok][:, :2].mean(axis=0)
    torsos = np.array([_torso(f) for f in seq])
    torsos = torsos[np.isfinite(torsos) & (torsos > 0)]
    if not len(torsos):
        return None
    scale = float(np.median(torsos))

    out = np.zeros_like(seq)
    out[:, :, :2] = (seq[:, :, :2] - origin) / scale
    out[:, :, 2] = seen
    out[~seen] = 0.0
    return out


def resample(seq: np.ndarray, length: int = SEQ_LEN) -> np.ndarray:
    """Lấy mẫu đều theo thời gian về đúng `length` khung (nearest)."""
    idx = np.linspace(0, len(seq) - 1, length).round().astype(int)
    return seq[idx]


def to_model_input(seq: np.ndarray) -> np.ndarray:
    """(T, V, C) → (C, T, V) float32 — thứ tự model nhận."""
    return np.ascontiguousarray(seq.transpose(2, 0, 1), dtype=np.float32)
