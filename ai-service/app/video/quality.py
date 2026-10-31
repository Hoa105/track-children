"""Kiểm tra chất lượng video trước khi gọi AI.

Lỗi chặn (rejected) trả lý do cho phụ huynh quay lại; lỗi nhẹ chỉ ghi chú cho AI.
"""

from dataclasses import dataclass, field

from app.video.frames import Frame, VideoInfo

DARK_BRIGHTNESS = 45  # độ sáng trung bình 0–255
MIN_SHORT_SIDE = 240  # px


@dataclass
class QualityReport:
    reject_reason: str | None = None
    notes: list[str] = field(default_factory=list)


def assess(
    info: VideoInfo, frames: list[Frame], min_seconds: float, max_seconds: float
) -> QualityReport:
    report = QualityReport()
    if info.seconds < min_seconds:
        report.reject_reason = (
            f"Video quá ngắn ({info.seconds:.1f} giây). Ba mẹ quay ít nhất "
            f"{min_seconds:.0f} giây để AI quan sát được hoạt động nhé."
        )
        return report
    if info.seconds > max_seconds + 1:  # +1 giây dung sai làm tròn của máy quay
        report.reject_reason = (
            f"Video dài {info.seconds:.0f} giây, vượt giới hạn {max_seconds:.0f} giây. "
            "Ba mẹ cắt ngắn đoạn bé thực hiện hoạt động rồi gửi lại nhé."
        )
        return report
    if not frames:
        report.reject_reason = "Không đọc được khung hình nào trong video. Ba mẹ thử quay lại nhé."
        return report

    dark = sum(f.brightness < DARK_BRIGHTNESS for f in frames) / len(frames)
    if dark > 0.8:
        report.reject_reason = (
            "Video quá tối để quan sát. Ba mẹ quay lại ở nơi đủ sáng, "
            "tránh quay ngược sáng nhé."
        )
        return report
    if dark > 0.3:
        report.notes.append("Khoảng một phần video khá tối, một số khung hình khó nhìn rõ.")
    if min(info.width, info.height) < MIN_SHORT_SIDE:
        report.notes.append("Độ phân giải video thấp, chi tiết nhỏ (ngón tay, nét mặt) có thể không rõ.")
    return report
