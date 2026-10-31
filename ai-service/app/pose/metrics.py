"""Số đo vận động từ chuỗi khung xương — hàm thuần numpy, không phụ thuộc MediaPipe.

Tọa độ: x, y đã đổi về cùng tỉ lệ (x nhân với width / height), y hướng xuống.
Khoảng cách được chia cho chiều dài thân (vai ↔ hông) để không phụ thuộc
khoảng cách máy quay. Mọi số đo là ước lượng; trả None khi không đo được.
"""

from dataclasses import dataclass

import numpy as np

# Chỉ số khớp BlazePose (33 điểm)
NOSE = 0
L_SHOULDER, R_SHOULDER = 11, 12
L_WRIST, R_WRIST = 15, 16
L_HIP, R_HIP = 23, 24
L_KNEE, R_KNEE = 25, 26
L_ANKLE, R_ANKLE = 27, 28
CORE = (L_SHOULDER, R_SHOULDER, L_HIP, R_HIP)

# Chỉ số khớp bàn tay (21 điểm)
H_WRIST, H_THUMB_TIP, H_INDEX_TIP, H_MIDDLE_MCP = 0, 4, 8, 9

VISIBLE = 0.5


@dataclass
class PoseSeries:
    """t: [T] giây; kp: [T, 33, 3] (x, y, visibility), NaN khi khung không thấy bé."""

    t: np.ndarray
    kp: np.ndarray


@dataclass
class HandSeries:
    """t: [T]; hands: [T, 2, 21, 2] (tay trái, tay phải theo MediaPipe), NaN khi không thấy."""

    t: np.ndarray
    hands: np.ndarray


# ---------------------------------------------------------------------
# Tiện ích
# ---------------------------------------------------------------------
def _frame_dt(t: np.ndarray) -> float:
    return float(np.median(np.diff(t))) if len(t) > 1 else 0.0


def _visible(kp: np.ndarray, joints) -> np.ndarray:
    vis = kp[:, list(joints), 2]
    return np.all(np.nan_to_num(vis, nan=0.0) >= VISIBLE, axis=1)


def _xy(kp: np.ndarray, joint: int) -> np.ndarray:
    return kp[:, joint, :2]


def _mid(kp: np.ndarray, a: int, b: int) -> np.ndarray:
    return (_xy(kp, a) + _xy(kp, b)) / 2


def _core_mask(p: PoseSeries) -> np.ndarray:
    return _visible(p.kp, CORE)


def _scale(p: PoseSeries) -> float | None:
    """Chiều dài thân trung vị (vai giữa ↔ hông giữa)."""
    mask = _core_mask(p)
    if not mask.any():
        return None
    torso = np.linalg.norm(
        _mid(p.kp, L_SHOULDER, R_SHOULDER)[mask] - _mid(p.kp, L_HIP, R_HIP)[mask], axis=1
    )
    value = float(np.median(torso))
    return value if value > 1e-6 else None


def _torso_angle(p: PoseSeries) -> np.ndarray:
    """Góc thân so với phương thẳng đứng (độ): 0 = đứng / ngồi thẳng, 90 = nằm ngang."""
    v = _mid(p.kp, L_SHOULDER, R_SHOULDER) - _mid(p.kp, L_HIP, R_HIP)
    return np.degrees(np.arctan2(np.abs(v[:, 0]), -v[:, 1]))


def _rising_edges(active: np.ndarray, t: np.ndarray, min_gap: float) -> int:
    """Số lần chuyển False → True, hai lần cách nhau ít nhất min_gap giây."""
    count, last = 0, -np.inf
    prev = False
    for on, ti in zip(active, t):
        if on and not prev and ti - last >= min_gap:
            count += 1
            last = ti
        prev = bool(on)
    return count


def _hysteresis_switches(signal: np.ndarray, threshold: float) -> int:
    """Số lần tín hiệu đổi dấu, chỉ tính khi vượt ±threshold (lọc rung)."""
    state, switches = 0, 0
    for value in signal:
        if np.isnan(value):
            continue
        if value > threshold and state != 1:
            switches += state == -1
            state = 1
        elif value < -threshold and state != -1:
            switches += state == 1
            state = -1
    return switches


def _seconds(mask: np.ndarray, t: np.ndarray) -> float:
    return round(float(mask.sum()) * _frame_dt(t), 1)


def _longest_run_seconds(mask: np.ndarray, t: np.ndarray, max_gap: int = 1) -> float:
    """Đoạn liên tục dài nhất (cho phép hụt max_gap khung do nhận diện chập chờn)."""
    best = run = gap = 0
    for on in mask:
        if on:
            run += 1 + gap
            gap = 0
            best = max(best, run)
        elif run and gap < max_gap:
            gap += 1
        else:
            run = gap = 0
    return round(best * _frame_dt(t), 1)


# ---------------------------------------------------------------------
# Số đo khung xương
# ---------------------------------------------------------------------
def detection_ratio(p: PoseSeries) -> float:
    return float(_core_mask(p).mean()) if len(p.t) else 0.0


def upright_seconds(p: PoseSeries) -> float | None:
    """Thân thẳng đứng (ngồi hoặc đứng)."""
    mask = _core_mask(p)
    if not mask.any():
        return None
    return _seconds(mask & (_torso_angle(p) < 35), p.t)


def standing_seconds(p: PoseSeries) -> float | None:
    """Đứng: thân thẳng và cổ chân ở thấp hơn hông ít nhất ~1 chiều dài thân."""
    scale = _scale(p)
    mask = _core_mask(p) & _visible(p.kp, (L_ANKLE, R_ANKLE))
    if scale is None or not mask.any():
        return None
    hip_y = _mid(p.kp, L_HIP, R_HIP)[:, 1]
    ankle_y = _mid(p.kp, L_ANKLE, R_ANKLE)[:, 1]
    legs_down = (ankle_y - hip_y) > 0.9 * scale
    return _seconds(mask & (_torso_angle(p) < 35) & legs_down, p.t)


def prone_seconds(p: PoseSeries) -> float | None:
    """Thân nằm ngang (nằm sấp / bò)."""
    mask = _core_mask(p)
    if not mask.any():
        return None
    angle = _torso_angle(p)
    return _seconds(mask & (angle > 60) & (angle < 120), p.t)


def head_lift_seconds(p: PoseSeries) -> float | None:
    """Nằm ngang và mũi cao hơn vai — ngẩng đầu khi nằm sấp."""
    scale = _scale(p)
    mask = _core_mask(p) & _visible(p.kp, (NOSE,))
    if scale is None or not mask.any():
        return None
    angle = _torso_angle(p)
    shoulder_y = _mid(p.kp, L_SHOULDER, R_SHOULDER)[:, 1]
    lifted = (shoulder_y - _xy(p.kp, NOSE)[:, 1]) > 0.25 * scale
    return _seconds(mask & (angle > 50) & lifted, p.t)


def crawl_posture_seconds(p: PoseSeries) -> float | None:
    """Tư thế bò: thân ngang, gối dưới hông và cổ tay dưới vai (chống tay + gối)."""
    scale = _scale(p)
    mask = _core_mask(p) & _visible(p.kp, (L_KNEE, R_KNEE, L_WRIST, R_WRIST))
    if scale is None or not mask.any():
        return None
    knees_below = (_mid(p.kp, L_KNEE, R_KNEE)[:, 1] - _mid(p.kp, L_HIP, R_HIP)[:, 1]) > 0.3 * scale
    hands_below = (
        _mid(p.kp, L_WRIST, R_WRIST)[:, 1] - _mid(p.kp, L_SHOULDER, R_SHOULDER)[:, 1]
    ) > 0.3 * scale
    return _seconds(mask & (_torso_angle(p) > 50) & knees_below & hands_below, p.t)


def hip_travel(p: PoseSeries) -> float | None:
    """Quãng di chuyển ngang của hông giữa đầu và cuối video, tính bằng số lần chiều dài thân.

    Giả định máy quay đứng yên; quay lia theo bé thì số này thấp hơn thực tế.
    """
    scale = _scale(p)
    mask = _core_mask(p)
    if scale is None or mask.sum() < 6:
        return None
    x = _mid(p.kp, L_HIP, R_HIP)[mask, 0]
    edge = max(1, len(x) * 15 // 100)
    return round(float(abs(np.median(x[-edge:]) - np.median(x[:edge]))) / scale, 1)


def step_count(p: PoseSeries) -> float | None:
    """Số bước: hai cổ chân luân phiên vượt nhau (quay ngang) hoặc luân phiên nhấc lên (quay chính diện)."""
    scale = _scale(p)
    mask = _core_mask(p) & _visible(p.kp, (L_ANKLE, R_ANKLE))
    if scale is None or mask.sum() < 6:
        return None
    left, right = _xy(p.kp, L_ANKLE), _xy(p.kp, R_ANKLE)
    dx = np.where(mask, (left[:, 0] - right[:, 0]) / scale, np.nan)
    dy = np.where(mask, (left[:, 1] - right[:, 1]) / scale, np.nan)
    return float(max(_hysteresis_switches(dx, 0.15), _hysteresis_switches(dy, 0.08)))


def _ankle_lift(p: PoseSeries, scale: float, mask: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Độ nhấc của từng cổ chân so với mặt sàn (mặt sàn = vị trí thấp nhất thường gặp)."""
    lifts = []
    for joint in (L_ANKLE, R_ANKLE):
        y = _xy(p.kp, joint)[:, 1]
        ground = np.percentile(y[mask], 90)
        lifts.append(np.where(mask, (ground - y) / scale, np.nan))
    return lifts[0], lifts[1]


def jump_count(p: PoseSeries) -> float | None:
    """Số lần bật nhảy: cả hai cổ chân cùng rời sàn và hông nâng lên."""
    scale = _scale(p)
    mask = _core_mask(p) & _visible(p.kp, (L_ANKLE, R_ANKLE))
    if scale is None or mask.sum() < 6:
        return None
    left, right = _ankle_lift(p, scale, mask)
    hip_y = _mid(p.kp, L_HIP, R_HIP)[:, 1]
    hip_lift = (np.median(hip_y[mask]) - hip_y) / scale
    airborne = mask & (np.nan_to_num(left) > 0.12) & (np.nan_to_num(right) > 0.12) & (hip_lift > 0.08)
    return float(_rising_edges(airborne, p.t, min_gap=0.25))


def single_leg_max_seconds(p: PoseSeries) -> float | None:
    """Thời gian đứng một chân dài nhất: một cổ chân nhấc, chân kia chạm sàn."""
    scale = _scale(p)
    mask = _core_mask(p) & _visible(p.kp, (L_ANKLE, R_ANKLE))
    if scale is None or mask.sum() < 6:
        return None
    left, right = np.nan_to_num(_ankle_lift(p, scale, mask), nan=0.0)
    one_leg = mask & (
        ((left > 0.12) & (right < 0.05)) | ((right > 0.12) & (left < 0.05))
    )
    return _longest_run_seconds(one_leg, p.t)


def arm_raise_count(p: PoseSeries) -> float | None:
    """Số lần đưa tay lên cao hơn đầu (ném bóng qua đầu)."""
    mask = _visible(p.kp, (NOSE,))
    if mask.sum() < 6:
        return None
    nose_y = _xy(p.kp, NOSE)[:, 1]
    raised = np.zeros(len(p.t), dtype=bool)
    for wrist in (L_WRIST, R_WRIST):
        ok = mask & _visible(p.kp, (wrist,))
        raised |= ok & (_xy(p.kp, wrist)[:, 1] < nose_y)
    return float(_rising_edges(raised, p.t, min_gap=0.5))


# ---------------------------------------------------------------------
# Số đo bàn tay
# ---------------------------------------------------------------------
def _hand_present(h: HandSeries) -> np.ndarray:
    """[T, 2] — tay trái / phải có trong khung."""
    return ~np.isnan(h.hands[:, :, H_WRIST, 0])


def hand_detection_ratio(h: HandSeries) -> float:
    return float(_hand_present(h).any(axis=1).mean()) if len(h.t) else 0.0


def hand_visible_seconds(h: HandSeries) -> float | None:
    if not len(h.t):
        return None
    return _seconds(_hand_present(h).any(axis=1), h.t)


def two_hand_seconds(h: HandSeries) -> float | None:
    if not len(h.t):
        return None
    return _seconds(_hand_present(h).all(axis=1), h.t)


def pinch_count(h: HandSeries) -> float | None:
    """Số lần chụm ngón cái – ngón trỏ (nhón nhặt), cộng cả hai tay."""
    present = _hand_present(h)
    if not present.any():
        return None
    total = 0
    for side in (0, 1):
        hand = h.hands[:, side]
        size = np.linalg.norm(hand[:, H_MIDDLE_MCP] - hand[:, H_WRIST], axis=1)
        gap = np.linalg.norm(hand[:, H_THUMB_TIP] - hand[:, H_INDEX_TIP], axis=1)
        with np.errstate(invalid="ignore", divide="ignore"):
            ratio = gap / size
        # Chụm khi < 0.35, mở khi > 0.5: đếm số lần đóng lại
        closed, count = False, 0
        for value in ratio:
            if np.isnan(value):
                continue
            if not closed and value < 0.35:
                closed, count = True, count + 1
            elif closed and value > 0.5:
                closed = False
        total += count
    return float(total)
