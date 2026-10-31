"""Tiêu chí quan sát theo nhóm hoạt động — đưa vào prompt cho AI.

Đây là "điều cần nhìn" khi xem video, không phải chuẩn để chấm đạt / chưa đạt.
Video chỉ gửi khung hình (không có âm thanh) nên các nhóm ngôn ngữ / âm nhạc /
kể chuyện chỉ quan sát cử chỉ, nét mặt, sự chú ý.
"""

GROUPS: dict[str, dict] = {
    "gross_motor": {
        "name": "Vận động thô",
        "focus": [
            "Tư thế và sự cân bằng của thân người trong lúc thực hiện",
            "Cách bé chuyển tư thế (lẫy, ngồi dậy, đứng lên, ngồi xuống)",
            "Phối hợp tay – chân; hai bên cơ thể cử động có tương đương không",
            "Mức độ bé cần người lớn đỡ, dắt hoặc vịn đồ vật",
            "Sự hứng thú, nét mặt và lúc bé muốn dừng",
            "Độ an toàn của không gian: mặt sàn, vật cản, chỗ cao",
        ],
        "avoid": [
            "Kết luận về trương lực cơ, sức cơ hay vấn đề thần kinh",
            "Tự đếm số bước / số lần nhảy khi không có số đo tự động",
        ],
    },
    "fine_motor": {
        "name": "Vận động tinh",
        "focus": [
            "Cách cầm nắm: cả bàn tay hay dùng ngón cái – ngón trỏ",
            "Phối hợp tay – mắt: bé có nhìn vào đồ vật khi với, nhặt, đặt không",
            "Dùng hai tay phối hợp (một tay giữ, một tay làm)",
            "Sự kiên nhẫn, số lần thử lại khi chưa làm được",
            "Đồ vật có an toàn không (đủ to để không nuốt được)",
        ],
        "avoid": [
            "Kết luận bé thuận tay nào khi video ngắn",
            "Đánh giá lực cầm nắm",
        ],
    },
    "language": {
        "name": "Ngôn ngữ",
        "focus": [
            "Cử chỉ giao tiếp: chỉ tay, vẫy tay, gật / lắc đầu",
            "Giao tiếp mắt và cùng chú ý với người lớn vào sách, đồ vật",
            "Khẩu hình, lượt lời: bé có chờ và đáp lại người lớn không",
            "Phản ứng khi được gọi tên hoặc được hỏi",
            "Cách người lớn khơi gợi: câu hỏi mở, chờ bé, nhắc lại lời bé",
        ],
        "avoid": [
            "Kết luận về phát âm, vốn từ hay khả năng nghe (video không có âm thanh)",
        ],
    },
    "cognitive_social": {
        "name": "Nhận thức & Cảm xúc xã hội",
        "focus": [
            "Sự chú ý và thời gian bé tập trung vào hoạt động",
            "Cách bé giải quyết vấn đề: thử – sai, đổi cách khác",
            "Bé bắt chước người lớn như thế nào",
            "Biểu lộ cảm xúc và cách bé tự điều chỉnh khi gặp khó",
            "Tương tác, chia sẻ, chờ lượt với người khác",
        ],
        "avoid": [
            "Kết luận về tự kỷ, rối loạn chú ý hay mức trí tuệ",
        ],
    },
    "music": {
        "name": "Âm nhạc & âm thanh",
        "focus": [
            "Chuyển động theo nhịp: vỗ tay, lắc lư, gõ",
            "Sự chú ý tới người hát hoặc nguồn âm thanh",
            "Bé bắt chước động tác của người lớn",
            "Niềm vui và mức độ tham gia",
        ],
        "avoid": [
            "Đánh giá cảm âm, cao độ hay giọng hát (video không có âm thanh)",
        ],
    },
    "storytelling": {
        "name": "Kể chuyện",
        "focus": [
            "Sự chú ý vào sách, tranh hoặc người kể",
            "Bé chỉ tay vào hình, lật trang",
            "Nét mặt phản ứng theo diễn biến câu chuyện",
            "Tương tác hỏi – đáp bằng cử chỉ",
        ],
        "avoid": [
            "Đánh giá khả năng hiểu câu chuyện hay ngôn ngữ (video không có âm thanh)",
        ],
    },
}

# Giai đoạn 2: số đo MediaPipe cho nhóm vận động (khóa trong ai-service app/pose/evidence.py).
# Theo id hoạt động phía mobile (lib/models/activity.dart); hoạt động không có trong
# bảng dùng mặc định của nhóm.
DEFAULT_METRICS: dict[str, list[str]] = {
    "gross_motor": ["upright_seconds", "hip_travel"],
    "fine_motor": ["hand_visible_seconds", "two_hand_seconds"],
}
ACTIVITY_METRICS: dict[str, list[str]] = {
    "g0-0": ["prone_seconds", "head_lift_seconds"],  # Tummy time
    "g0-1": ["prone_seconds", "upright_seconds"],  # Lẫy, lăn người
    "g0-2": ["upright_seconds"],  # Ngồi có hỗ trợ
    "g0-3": ["crawl_posture_seconds", "hip_travel"],  # Bò qua vật cản
    "g0-4": ["standing_seconds"],  # Đứng vịn
    "g0-5": ["standing_seconds", "step_count", "hip_travel"],  # Bước chững
    "g0-6": ["step_count", "hip_travel", "standing_seconds"],  # Đi bộ tự do
    "g0-7": ["arm_raise_count", "standing_seconds"],  # Ném – bắt bóng
    "g0-8": ["step_count", "single_leg_max_seconds"],  # Bậc thang thấp
    "g0-9": ["jump_count"],  # Nhảy tại chỗ hai chân
    "g0-10": ["hip_travel"],  # Đạp xe
    "g0-11": ["step_count", "single_leg_max_seconds", "hip_travel"],  # Đi trên vạch
    "g1-1": ["two_hand_seconds", "hand_visible_seconds"],  # Chuyển đồ qua tay
    "g1-2": ["pinch_count", "hand_visible_seconds"],  # Nhón nhặt vật nhỏ
    "g1-4": ["pinch_count", "two_hand_seconds"],  # Xâu hạt
    "g1-9": ["pinch_count", "two_hand_seconds"],  # Cài / mở cúc áo
}


def metrics_for(activity_id: str, group: str) -> list[str]:
    if group not in DEFAULT_METRICS:
        return []
    return ACTIVITY_METRICS.get(activity_id, DEFAULT_METRICS[group])
