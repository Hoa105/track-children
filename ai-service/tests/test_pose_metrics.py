"""Số đo vận động trên chuỗi khung xương tổng hợp (không cần MediaPipe)."""

import numpy as np
import pytest

from app.pose import metrics as m

FPS = 10


def standing_pose(n: int) -> np.ndarray:
    """Bé đứng thẳng: vai y=0.3, hông y=0.5 (thân dài 0.2), cổ chân y=0.85."""
    kp = np.zeros((n, 33, 3))
    kp[:, :, 2] = 1.0  # visibility
    kp[:, m.NOSE, :2] = [0.5, 0.2]
    kp[:, m.L_SHOULDER, :2] = [0.45, 0.3]
    kp[:, m.R_SHOULDER, :2] = [0.55, 0.3]
    kp[:, m.L_WRIST, :2] = [0.4, 0.5]
    kp[:, m.R_WRIST, :2] = [0.6, 0.5]
    kp[:, m.L_HIP, :2] = [0.47, 0.5]
    kp[:, m.R_HIP, :2] = [0.53, 0.5]
    kp[:, m.L_KNEE, :2] = [0.47, 0.68]
    kp[:, m.R_KNEE, :2] = [0.53, 0.68]
    kp[:, m.L_ANKLE, :2] = [0.47, 0.85]
    kp[:, m.R_ANKLE, :2] = [0.53, 0.85]
    return kp


def series(kp: np.ndarray) -> m.PoseSeries:
    return m.PoseSeries(t=np.arange(len(kp)) / FPS, kp=kp)


def test_standing_counts_as_upright_and_standing():
    p = series(standing_pose(30))
    assert m.detection_ratio(p) == 1.0
    assert m.upright_seconds(p) == pytest.approx(3.0)
    assert m.standing_seconds(p) == pytest.approx(3.0)
    assert m.prone_seconds(p) == 0
    assert m.jump_count(p) == 0
    assert m.step_count(p) == 0


def test_missing_frames_reduce_detection_and_return_none_when_empty():
    kp = standing_pose(10)
    kp[:5] = np.nan
    assert m.detection_ratio(series(kp)) == 0.5
    assert m.upright_seconds(series(np.full((5, 33, 3), np.nan))) is None


def test_jump_count_detects_both_feet_off_ground():
    kp = standing_pose(60)
    for start in (10, 30, 50):  # 3 cú nhảy, mỗi cú 3 khung
        kp[start:start + 3, [m.L_ANKLE, m.R_ANKLE], 1] -= 0.06
        kp[start:start + 3, [m.L_HIP, m.R_HIP, m.L_SHOULDER, m.R_SHOULDER], 1] -= 0.04
    assert m.jump_count(series(kp)) == 3


def test_single_leg_longest_run():
    kp = standing_pose(80)
    kp[10:20, m.L_ANKLE, 1] -= 0.05  # 1 giây
    kp[40:65, m.R_ANKLE, 1] -= 0.05  # 2,5 giây
    assert m.single_leg_max_seconds(series(kp)) == pytest.approx(2.5)


def test_step_count_from_side_view_crossings():
    kp = standing_pose(80)
    for i in range(80):
        phase = 1 if (i // 10) % 2 == 0 else -1  # đổi chân trước mỗi 1 giây
        kp[i, m.L_ANKLE, 0] = 0.5 + 0.05 * phase
        kp[i, m.R_ANKLE, 0] = 0.5 - 0.05 * phase
        hip_x = 0.2 + i * 0.006  # đi sang phải
        kp[i, [m.L_HIP, m.R_HIP, m.L_SHOULDER, m.R_SHOULDER], 0] = hip_x
    p = series(kp)
    assert m.step_count(p) == 7
    assert m.hip_travel(p) == pytest.approx(2.0)


def test_crawl_and_prone_posture():
    kp = standing_pose(20)
    # Thân nằm ngang: vai bên trái, hông bên phải cùng độ cao; tay, gối chống xuống sàn
    kp[:, [m.L_SHOULDER, m.R_SHOULDER], :2] = [0.3, 0.5]
    kp[:, [m.L_HIP, m.R_HIP], :2] = [0.5, 0.5]
    kp[:, [m.L_WRIST, m.R_WRIST], :2] = [0.3, 0.65]
    kp[:, [m.L_KNEE, m.R_KNEE], :2] = [0.5, 0.65]
    kp[:, m.NOSE, :2] = [0.22, 0.42]
    p = series(kp)
    assert m.prone_seconds(p) == pytest.approx(2.0)
    assert m.crawl_posture_seconds(p) == pytest.approx(2.0)
    assert m.head_lift_seconds(p) == pytest.approx(2.0)
    assert m.upright_seconds(p) == 0


def test_arm_raise_count():
    kp = standing_pose(40)
    kp[5:10, m.R_WRIST, 1] = 0.1
    kp[25:30, m.L_WRIST, 1] = 0.1
    assert m.arm_raise_count(series(kp)) == 2


def test_hand_metrics_pinch_and_two_hands():
    n = 40
    hands = np.full((n, 2, 21, 2), np.nan)
    hand = np.zeros((21, 2))
    hand[m.H_WRIST] = [0.5, 0.8]
    hand[m.H_MIDDLE_MCP] = [0.5, 0.6]  # cỡ bàn tay 0.2
    hand[m.H_THUMB_TIP] = [0.45, 0.55]
    hand[m.H_INDEX_TIP] = [0.6, 0.5]  # mở
    hands[:, 1] = hand
    for start in (5, 20, 32):  # 3 lần chụm
        hands[start:start + 3, 1, m.H_INDEX_TIP] = [0.47, 0.55]
    hands[:10, 0] = hand  # tay trái chỉ thấy 1 giây
    h = m.HandSeries(t=np.arange(n) / FPS, hands=hands)
    assert m.pinch_count(h) == 3
    assert m.hand_detection_ratio(h) == 1.0
    assert m.hand_visible_seconds(h) == pytest.approx(4.0)
    assert m.two_hand_seconds(h) == pytest.approx(1.0)
