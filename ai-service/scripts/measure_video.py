"""Đo vận động trên video thật để chỉnh ngưỡng trong app/pose/metrics.py.

Không gọi Claude, không cần database. Ví dụ (chạy trong thư mục ai-service):

    python scripts/measure_video.py be_tap_di.mp4 g0-6
    python scripts/measure_video.py be_bo.mp4 g0-3 --frames be_bo.csv

Tham số thứ hai là id hoạt động phía mobile (bảng ACTIVITY_METRICS bên backend)
hoặc danh sách khóa số đo cách nhau bởi dấu phẩy, vd. step_count,hip_travel.
--frames ghi từng khung (góc thân, độ nhấc cổ chân…) ra CSV để xem vì sao một
số đo đếm sai.
"""

import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings  # noqa: E402
from app.pose import evidence, landmarks  # noqa: E402
from app.pose import metrics as m  # noqa: E402
from app.video import frames  # noqa: E402


def metric_keys(spec: str) -> list[str]:
    if spec in evidence.METRICS or "," in spec:
        return [k.strip() for k in spec.split(",")]
    # Bảng của backend; nạp thẳng file vì backend cũng có package tên "app"
    import importlib.util

    path = Path(__file__).resolve().parents[2] / "backend/app/features/diary_ai/criteria.py"
    module_spec = importlib.util.spec_from_file_location("backend_criteria", path)
    criteria = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(criteria)
    ACTIVITY_METRICS = criteria.ACTIVITY_METRICS
    if spec not in ACTIVITY_METRICS:
        sys.exit(f"Không biết hoạt động {spec}. Dùng id trong ACTIVITY_METRICS hoặc khóa số đo.")
    return ACTIVITY_METRICS[spec]


def write_frames(path: str, pose: m.PoseSeries) -> None:
    scale = m._scale(pose) or float("nan")
    angle = m._torso_angle(pose)
    hip_y = m._mid(pose.kp, m.L_HIP, m.R_HIP)[:, 1]
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["t", "detected", "torso_angle", "hip_y_norm",
                    "l_ankle_y_norm", "r_ankle_y_norm", "ankle_dx_norm"])
        core = m._core_mask(pose)
        for i, t in enumerate(pose.t):
            la, ra = pose.kp[i, m.L_ANKLE], pose.kp[i, m.R_ANKLE]
            w.writerow([
                round(t, 2), int(core[i]), round(float(angle[i]), 1),
                round(hip_y[i] / scale, 3), round(la[1] / scale, 3), round(ra[1] / scale, 3),
                round((la[0] - ra[0]) / scale, 3),
            ])
    print(f"Đã ghi từng khung vào {path} (đơn vị: chiều dài thân bé)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("video")
    parser.add_argument("activity", help="id hoạt động (vd. g0-6) hoặc khóa số đo")
    parser.add_argument("--frames", help="ghi số liệu từng khung ra CSV")
    args = parser.parse_args()

    keys = metric_keys(args.activity)
    info = frames.probe(args.video)
    print(f"Video: {info.seconds:.1f} giây, {info.width}x{info.height}, {info.fps:.0f} fps")
    print(f"Số đo: {', '.join(keys)}\n")

    sources = {evidence.METRICS[k].source for k in keys}
    if "pose" in sources:
        pose = landmarks.extract_pose(args.video, info, settings.pose_model_path, settings.pose_sample_fps)
        print(f"Khung nhận diện được bé: {m.detection_ratio(pose):.0%} "
              f"(ngưỡng dùng số đo: {evidence.MIN_POSE_DETECTION:.0%})")
        for item in evidence.compute(pose, keys, "pose"):
            print(f"  {item.label}: {item.value} {item.unit}")
        if args.frames:
            write_frames(args.frames, pose)
    if "hands" in sources:
        hands = landmarks.extract_hands(args.video, info, settings.hand_model_path, settings.pose_sample_fps)
        print(f"Khung thấy tay bé: {m.hand_detection_ratio(hands):.0%} "
              f"(ngưỡng: {evidence.MIN_HAND_DETECTION:.0%})")
        for item in evidence.compute(hands, keys, "hands"):
            print(f"  {item.label}: {item.value} {item.unit}")


if __name__ == "__main__":
    main()
