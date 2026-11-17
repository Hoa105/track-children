"""Thử model K-DST trên một video, giống hệt cách ai-service chấm — để tự kiểm tra kết quả.

Không gọi API, không cần database, không lưu gì ngoài file --overlay (nếu có).
Chạy trong thư mục ai-service:

    python scripts/kdst_check.py be_leo.mp4 A01
    python scripts/kdst_check.py be_leo.mp4 A01 --overlay be_leo_khungxuong.mp4

Tham số thứ hai là mã bài K-DST (A01 … C04, xem app/kdst/items.py).
--overlay xuất video có vẽ khung xương bé mà MediaPipe bắt được: nếu khung xương
bám nhầm người lớn, mất chân hoặc nhảy lung tung thì kết quả chấm không đáng tin.
"""

import argparse
import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings  # noqa: E402
from app.kdst import scorer, templates  # noqa: E402
from app.kdst import skeleton  # noqa: E402
from app.kdst.items import ITEM_INDEX, ITEMS  # noqa: E402
from app.pose import evidence, landmarks  # noqa: E402
from app.pose import metrics as m  # noqa: E402
from app.video import frames  # noqa: E402

LEVEL_VI = {"not_yet": "Chưa làm được", "unsteady": "Làm được, chưa vững", "steady": "Làm vững"}
# cv2.putText không vẽ được chữ có dấu
LEVEL_ASCII = {"not_yet": "chua lam duoc", "unsteady": "chua vung", "steady": "lam vung"}
REASON_VI = {
    scorer.NO_BODY: "không thấy đủ rõ cơ thể bé",
    scorer.OTHER_ITEM: "video giống bài khác hơn bài đã chọn",
    scorer.LOW_CONFIDENCE: "độ tin cậy thấp hơn ngưỡng",
}


def open_video(path: str) -> tuple[str, frames.VideoInfo]:
    """OpenCV không đọc được (vd. AV1) thì chuyển sang H.264 như ai-service."""
    try:
        info = frames.probe(path)
        if info.frame_count > 0:
            return path, info
    except frames.UnreadableVideo:
        pass
    converted = frames.transcode(path)
    if converted is None:
        sys.exit("Không đọc được video (cần ffmpeg để chuyển định dạng)")
    print(f"(Đã chuyển video sang H.264: {converted})")
    return converted, frames.probe(converted)


def bar(p: float, width: int = 20) -> str:
    return "█" * round(p * width) + "·" * (width - round(p * width))


def write_overlay(path: str, out: str, info: frames.VideoInfo, pose: m.PoseSeries, header: str) -> None:
    """Vẽ 21 khớp model dùng lên đúng các khung MediaPipe đã xử lý."""
    fps = settings.pose_sample_fps
    writer = cv2.VideoWriter(out, cv2.VideoWriter_fourcc(*"mp4v"), fps, (info.width, info.height))
    aspect = info.width / info.height
    font = min(1.0, info.width / 900)  # chữ vừa khung cả video nhỏ lẫn video điện thoại
    for i, (t, rgb) in enumerate(frames.iter_rgb(path, info, fps)):
        if i >= len(pose.kp):
            break
        image = cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)
        kp = skeleton.from_mediapipe(pose.kp[i])  # (21, 3), khớp không thấy = 0
        pts = [(int(x / aspect * info.width), int(y * info.height)) for x, y, _ in kp]
        seen = kp[:, 2] > 0
        for a, b in skeleton.EDGES:
            if seen[a] and seen[b]:
                cv2.line(image, pts[a], pts[b], (0, 220, 255), 3)
        for j, p in enumerate(pts):
            if seen[j]:
                cv2.circle(image, p, 5, (0, 90, 255), -1)
        status = "thay be" if seen.any() else "KHONG thay be"
        for row, text in enumerate((header, f"{t:5.1f}s  {status}")):
            y = round((row + 1) * 36 * font)
            cv2.putText(image, text, (10, y), cv2.FONT_HERSHEY_SIMPLEX, font, (0, 0, 0), 4)
            cv2.putText(image, text, (10, y), cv2.FONT_HERSHEY_SIMPLEX, font, (255, 255, 255), 2)
        writer.write(image)
    writer.release()
    print(f"\nĐã ghi video khung xương: {out}")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("video")
    parser.add_argument("item", choices=[i.code for i in ITEMS], help="mã bài K-DST, vd. A01")
    parser.add_argument("--age", type=int, help="tuổi bé (tháng) — để xem nhận xét mẫu")
    parser.add_argument("--overlay", help="xuất video có vẽ khung xương (.mp4)")
    parser.add_argument("--model", default=settings.kdst_model_path)
    args = parser.parse_args()

    kdst = scorer.KdstScorer(args.model)
    item = ITEMS[ITEM_INDEX[args.item]]
    path, info = open_video(args.video)
    print(f"Model: {kdst.version} (ngưỡng tin cậy {kdst.min_confidence:.2f})")
    print(f"Bài: {item.code} – {item.name_vi} (dữ liệu train: trẻ {item.age_from_months}–{item.age_to_months} tháng)")
    print(f"Video: {info.seconds:.1f} giây, {info.width}x{info.height}, {info.fps:.0f} fps\n")

    pose = landmarks.extract_pose(path, info, settings.pose_model_path, settings.pose_sample_fps)
    ratio = m.detection_ratio(pose)
    print(f"Khung thấy bé: {ratio:.0%} (ai-service cần ≥ {evidence.MIN_POSE_DETECTION:.0%})")

    if ratio < evidence.MIN_POSE_DETECTION:
        result = kdst.unusable(item.code, scorer.NO_BODY)
    else:
        result = kdst.assess(pose.kp, item.code)
        probs = kdst.probabilities(pose.kp, item.code)
        if probs is not None:
            score_prob, item_prob = probs
            print(f"\nMức của bài {item.code}:")
            for label, p in zip(LEVEL_VI.values(), score_prob):
                print(f"  {label:<22}{bar(p)} {p:5.1%}")
            print("\nModel nghĩ video là bài:")
            for i in np.argsort(item_prob)[::-1][:3]:
                mark = "  ← bài đã chọn" if ITEMS[i].code == item.code else ""
                print(f"  {ITEMS[i].code} {ITEMS[i].name_vi:<28}{item_prob[i]:5.1%}{mark}")

    print("\nỞ ai-service, video này sẽ:")
    if result.confident:
        print(f"  → Dùng NHẬN XÉT MẪU, không gọi API — mức “{LEVEL_VI[result.level]}”")
        if args.age is not None:
            r = templates.render(result, args.age)
            print(f"  Quan sát: {r.observations[0]}")
            print(f"  Nhận xét: {r.comment}")
            for step in r.next_steps:
                print(f"  Gợi ý: {step}")
            if r.see_specialist:
                print(f"  Lưu ý: {r.specialist_note}")
    else:
        print(f"  → Chuyển sang LLM (Gemini/Claude) vì {REASON_VI[result.reason]}")
        print("    (KDST_LLM_FALLBACK=false: nhờ ba mẹ quay lại — "
              f"“{templates.uncertain(result).video_issue}”)")

    if args.overlay:
        level = LEVEL_ASCII.get(result.level, "-")
        header = f"{item.code} | {level} | {'nhan xet mau' if result.confident else 'chuyen LLM'}"
        write_overlay(path, args.overlay, info, pose, header)

    if path != args.video:
        Path(path).unlink(missing_ok=True)


if __name__ == "__main__":
    main()
