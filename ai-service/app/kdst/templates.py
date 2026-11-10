"""Nhận xét mẫu cho 12 bài K-DST theo mức model chấm — thay cho câu trả lời của LLM.

Không đưa điểm số hay xác suất cho phụ huynh: chỉ mô tả, gợi ý tập và lời khuyên
đi khám khi bé đã quá độ tuổi của bài mà vẫn chưa làm được.
"""

from dataclasses import dataclass

from app.kdst import scorer
from app.kdst.items import ITEM_INDEX, ITEMS
from app.pose import metrics as pose_metrics
from app.pose.metrics import PoseSeries
from app.schemas.insight import InsightResult

VERSION = "kdst-template-3"

DISCLAIMER = (
    "Nhận xét được tạo tự động từ chuyển động cơ thể bé trong video, chỉ để ba mẹ tham khảo "
    "và theo dõi, không thay cho đánh giá của bác sĩ."
)


@dataclass(frozen=True)
class ItemText:
    steady: str
    unsteady: str
    not_yet: str
    practice: tuple[str, ...]  # gợi ý khi bé chưa làm được / còn loạng choạng
    challenge: str  # gợi ý nâng độ khó khi bé đã làm vững


TEXTS: dict[str, ItemText] = {
    "A01": ItemText(
        steady="Bé tự bước lên cầu thang đều chân, thân người giữ thẳng và cân bằng tốt.",
        unsteady="Bé đã bước lên được cầu thang nhưng còn chậm, có lúc dừng lại hoặc thân người chưa vững.",
        not_yet="Bé chưa tự đứng bước lên cầu thang; bé có thể còn bò lên bằng tay chân hoặc cần người lớn đỡ.",
        practice=(
            "Cho bé tập bước lên bậc thấp (10–15 cm) và vịn tay vịn, ba mẹ đứng phía sau bé.",
            "Chơi trò bước lên – bước xuống một bậc thấp, mỗi lần 5–10 lượt.",
        ),
        challenge="Cho bé thử bước lên mỗi bậc một chân (luân phiên chân) khi vẫn vịn tay vịn.",
    ),
    "A02": ItemText(
        steady="Bé tự bước xuống cầu thang chắc chắn, đặt chân vững và giữ được thăng bằng.",
        unsteady="Bé đã bước xuống được nhưng còn dè dặt, thân người có lúc nghiêng hoặc mất thăng bằng.",
        not_yet="Bé chưa tự đứng bước xuống cầu thang; bé có thể còn ngồi trườn xuống hoặc cần người lớn nắm tay.",
        practice=(
            "Tập bước xuống từ một bậc thấp, bé vịn tay vịn và ba mẹ đứng phía trước đỡ.",
            "Cho bé chơi leo – trượt trên cầu trượt thấp để quen cảm giác đi xuống.",
        ),
        challenge="Cho bé thử bước xuống luân phiên chân, ba mẹ vẫn đứng gần để an toàn.",
    ),
    "A03": ItemText(
        steady="Bé đưa tay lên cao qua đầu và ném bóng về phía trước rõ ràng, thân người giữ vững.",
        unsteady="Bé đã ném được bóng nhưng động tác tay còn ngắn hoặc thân người chưa vững khi ném.",
        not_yet="Bé chưa thực hiện được động tác đưa tay qua đầu để ném bóng về phía trước.",
        practice=(
            "Dùng bóng nhẹ, vừa tay; ba mẹ làm mẫu đưa bóng ra sau đầu rồi ném về phía trước.",
            "Chơi ném bóng vào thùng hoặc rổ to đặt cách bé 1 mét.",
        ),
        challenge="Tăng dần khoảng cách ném, hoặc cho bé ném trúng một mục tiêu nhỏ hơn.",
    ),
    "A04": ItemText(
        steady="Bé đứng được trên một chân trong chốc lát, thân người giữ thẳng.",
        unsteady="Bé đã nhấc được một chân lên nhưng giữ rất ngắn, thân người còn chao đảo.",
        not_yet="Bé chưa đứng được trên một chân; bé có thể đặt chân xuống ngay hoặc còn cần vịn.",
        practice=(
            "Cho bé vịn tường hoặc tay ba mẹ rồi nhấc một chân lên, đếm 1–2 rồi đổi chân.",
            "Chơi trò bắt chước 'con cò đứng một chân' cùng ba mẹ.",
        ),
        challenge="Cho bé thử đứng một chân không vịn, đếm tới 3, tập cả hai chân.",
    ),
    "B01": ItemText(
        steady="Bé đứng một chân được lâu, thân người vững và ít phải dang tay giữ thăng bằng.",
        unsteady="Bé đứng được một chân nhưng chưa lâu, thân người hoặc hai tay còn chao để giữ thăng bằng.",
        not_yet="Bé chưa giữ được lâu tư thế đứng một chân; chân kia có thể chạm đất sớm.",
        practice=(
            "Tập đứng một chân có vịn, tăng dần thời gian giữ từ 1 tới 3 giây, tập cả hai chân.",
            "Chơi trò 'tượng đứng một chân' khi tắt nhạc.",
        ),
        challenge="Cho bé đứng một chân lâu hơn (5–10 giây) hoặc đứng một chân trên gối mềm.",
    ),
    "B02": ItemText(
        steady="Bé nhảy lò cò liên tiếp trên một chân, tiếp đất vững và giữ được hướng.",
        unsteady="Bé đã nhảy lò cò được nhưng còn ít bước, tiếp đất chưa vững hoặc phải đặt chân kia xuống.",
        not_yet="Bé chưa nhảy lò cò được; bé có thể còn nhảy bằng hai chân hoặc phải đặt chân kia xuống.",
        practice=(
            "Tập đứng một chân thật vững trước, rồi nắm tay bé nhảy lò cò tại chỗ 1–2 lần.",
            "Vẽ vài ô trên sàn và cùng bé nhảy lò cò từ ô này sang ô kia, có ba mẹ nắm tay.",
        ),
        challenge="Cho bé nhảy lò cò 5 bước liên tiếp, rồi tập đổi chân.",
    ),
    "B03": ItemText(
        steady="Bé bật xa bằng hai chân, hai chân rời đất và tiếp đất cùng lúc, giữ được thăng bằng.",
        unsteady="Bé đã bật nhảy về phía trước nhưng hai chân chưa đều hoặc tiếp đất còn loạng choạng.",
        not_yet="Bé chưa bật xa được bằng hai chân; bé có thể còn bước chân thay vì bật, hoặc chỉ nhảy tại chỗ.",
        practice=(
            "Cùng bé tập khuỵu gối rồi bật lên tại chỗ bằng hai chân trước khi bật về phía trước.",
            "Đặt một sợi dây trên sàn và cho bé nhảy qua bằng hai chân, ba mẹ nắm tay.",
        ),
        challenge="Đánh dấu điểm tiếp đất và khuyến khích bé bật xa hơn lần trước.",
    ),
    "B04": ItemText(
        steady="Bé đưa tay ra đón và bắt được bóng, thân người theo kịp hướng bóng.",
        unsteady="Bé đã đưa tay ra đón bóng nhưng còn chậm hoặc ôm bóng chưa chắc.",
        not_yet="Bé chưa có động tác đưa tay ra đón và giữ bóng rõ ràng.",
        practice=(
            "Dùng bóng to, mềm; tung nhẹ ở khoảng cách gần (1 mét) và nhắc bé 'giơ tay ra đón'.",
            "Cho bé tập lăn bóng qua lại với ba mẹ trước khi chuyển sang tung bóng.",
        ),
        challenge="Tăng khoảng cách hoặc dùng bóng nhỏ hơn để bé tập bắt bằng hai bàn tay.",
    ),
    "C01": ItemText(
        steady="Bé dùng chân chặn được quả bóng đang lăn tới, đứng vững trên chân còn lại.",
        unsteady="Bé đã đưa chân ra chặn bóng nhưng còn chậm hoặc mất thăng bằng khi nhấc chân.",
        not_yet="Bé chưa có động tác nhấc chân chặn bóng rõ ràng.",
        practice=(
            "Lăn bóng thật chậm về phía bé và cho bé đặt bàn chân lên bóng để giữ lại.",
            "Tập đứng một chân có vịn để bé quen nhấc chân mà vẫn đứng vững.",
        ),
        challenge="Lăn bóng nhanh hơn hoặc lệch sang hai bên để bé di chuyển chặn bóng.",
    ),
    "C02": ItemText(
        steady="Bé đập bóng xuống sàn và đón lại liên tiếp, tay và mắt phối hợp tốt.",
        unsteady="Bé đã đập được bóng nhưng chưa liên tục, có lúc bóng nảy lệch khỏi tầm tay.",
        not_yet="Bé chưa có động tác đập bóng xuống và đón lại rõ ràng.",
        practice=(
            "Dùng bóng nảy tốt; cho bé thả bóng rồi bắt lại bằng hai tay trước.",
            "Ba mẹ làm mẫu đập bóng bằng một tay, đếm to từng lần để bé bắt chước.",
        ),
        challenge="Cho bé đập bóng liên tiếp 5 lần, rồi vừa đi vừa đập bóng.",
    ),
    "C03": ItemText(
        steady="Bé bật qua dây bằng hai chân, tiếp đất vững và không vướng dây.",
        unsteady="Bé đã nhảy qua được dây nhưng còn chạm dây hoặc tiếp đất chưa vững.",
        not_yet="Bé chưa bật nhảy bằng hai chân qua dây; bé có thể còn bước qua hoặc dừng lại trước dây.",
        practice=(
            "Đặt dây sát sàn và cho bé bật qua bằng hai chân, sau đó mới nâng dây lên dần.",
            "Tập bật tại chỗ bằng hai chân để bé quen lực bật.",
        ),
        challenge="Nâng dây cao hơn một chút (an toàn, dây lỏng) hoặc nhảy qua lại liên tiếp.",
    ),
    "C04": ItemText(
        steady="Bé quay dây và nhảy qua dây được, động tác tay và chân khớp nhịp.",
        unsteady="Bé đã thử quay dây và nhảy nhưng tay – chân chưa khớp nhịp, dây hay vướng chân.",
        not_yet="Bé chưa phối hợp được động tác quay dây và bật nhảy.",
        practice=(
            "Tách thành hai bước: tập quay dây ra phía trước, rồi tập bật nhảy tại chỗ theo nhịp đếm.",
            "Ba mẹ quay dây chậm cho bé nhảy qua trước khi bé tự quay.",
        ),
        challenge="Khuyến khích bé nhảy dây 2–3 lần liên tiếp không vướng.",
    ),
}

_COMMENT = {
    "steady": "Bé thực hiện bài “{name}” khá vững. Ba mẹ tiếp tục cho bé vận động hằng ngày và nâng dần độ khó nhé.",
    "unsteady": "Bé đã làm được bài “{name}” nhưng còn chưa vững — đây là giai đoạn bình thường khi bé đang tập. "
    "Tập đều đặn vài lần mỗi tuần sẽ giúp bé tự tin hơn.",
    "not_yet": "Bé chưa thực hiện được bài “{name}” trong video này. Ba mẹ đừng lo, hãy chia nhỏ động tác "
    "và cùng bé tập qua trò chơi.",
}
_POSITIVE = {
    "steady": "Bé hoàn thành bài “{name}” chắc chắn",
    "unsteady": "Bé đã tự thực hiện được bài “{name}”",
    "not_yet": "Bé đã tham gia và thử bài tập",
}
# ---------------------------------------------------------------------
# Khi không chấm được: lý do cụ thể + hướng dẫn quay lại
# ---------------------------------------------------------------------
MIN_TRY_SECONDS = 6  # ngắn hơn thường chưa đủ trọn một lần thử
MIN_VISIBLE_RATIO = 0.8  # thấp hơn: có đoạn dài không thấy bé
MIN_HIP_SHIFT = 1.5  # bài di chuyển mà hông dời < 1,5 lần thân → máy quay đi theo bé
MOVING_ITEMS = frozenset({"A01", "A02", "B03"})  # bé phải đổi chỗ khi làm bài
STAIR_ITEMS = frozenset({"A01", "A02"})
MAX_REASONS = 3

_PLACEMENT = {
    "A01": "Đặt máy ở chân cầu thang, chếch sang một bên khoảng 45°, để thấy bé đi lên cao dần "
    "qua 3–4 bậc. Không đứng ở đầu cầu thang chĩa xuống và không quay từ sau lưng bé.",
    "A02": "Đặt máy ở chân cầu thang, chếch sang một bên khoảng 45°, để thấy bé đi xuống qua 3–4 bậc. "
    "Không quay từ sau lưng bé.",
    "A04": "Đặt máy trước mặt bé hoặc chếch 45°, cách khoảng 2–3 mét, thấy rõ cả hai chân.",
    "B01": "Đặt máy trước mặt bé hoặc chếch 45°, cách khoảng 2–3 mét, thấy rõ cả hai chân.",
}
_PLACEMENT_JUMP = (
    "Đặt máy chếch 45° so với hướng bé nhảy, cách khoảng 2–3 mét, chừa khoảng trống phía trước "
    "và phía trên đầu bé."
)
_PLACEMENT_BALL = "Đặt máy trước mặt bé hoặc chếch 45°, cách khoảng 2–3 mét, thấy cả bé và quả bóng."
_GENERAL_GUIDE = (
    "Kê hoặc dựng điện thoại cố định ngang tầm bé, không cầm máy đi theo bé.",
    "Thấy trọn người bé từ đầu tới bàn chân trong suốt video, đủ sáng, không có người hay vật che.",
    "Mỗi video chỉ có một bé và một lần thực hiện bài, dài khoảng 8–15 giây, quay trực tiếp bằng "
    "camera (không quay lại màn hình, không cắt ghép).",
)


def filming_guide(item: str) -> list[str]:
    """Hướng dẫn quay lại cho bài K-DST: vị trí đặt máy riêng của bài + quy tắc chung."""
    if item in _PLACEMENT:
        placement = _PLACEMENT[item]
    elif item in {"A03", "B04", "C01", "C02"}:
        placement = _PLACEMENT_BALL
    else:
        placement = _PLACEMENT_JUMP
    return [placement, *_GENERAL_GUIDE]


def diagnose(
    assessment: scorer.KdstAssessment,
    seconds: float | None = None,
    visible_ratio: float | None = None,
    hip_shift: float | None = None,
) -> list[str]:
    """Lý do (tiếng Việt, cho phụ huynh) vì sao model không chấm được video, rõ nhất trước."""
    item = assessment.item
    predicted = assessment.predicted_item
    reasons: list[str] = []

    if assessment.reason == scorer.NO_BODY:
        reasons.append(
            "Không thấy rõ toàn thân bé trong phần lớn video (bé bị che, ra khỏi khung hình hoặc thiếu sáng)."
        )
    if seconds is not None and seconds < MIN_TRY_SECONDS:
        reasons.append(f"Video chỉ dài khoảng {seconds:.0f} giây, chưa đủ cho trọn một lần thực hiện bài.")
    if (
        assessment.reason != scorer.NO_BODY
        and visible_ratio is not None
        and visible_ratio < MIN_VISIBLE_RATIO
    ):
        reasons.append("Có đoạn không thấy bé: bé ra khỏi khung hình, đi quá sát máy hoặc bị che.")
    flipped = assessment.reason == scorer.OTHER_ITEM and {item, predicted} == STAIR_ITEMS
    if flipped:
        direction = "đi xuống" if item == "A01" else "đi lên"
        reasons.append(
            f"Trong video, bé trông như đang {direction} cầu thang. Thường do máy đặt quá cao "
            "(ở đầu cầu thang chĩa xuống) hoặc quá thấp so với cầu thang."
        )
    if (
        assessment.reason != scorer.NO_BODY
        and not flipped  # máy đặt sai độ cao đã giải thích được: không đoán thêm
        and item in MOVING_ITEMS
        and hip_shift is not None
        and hip_shift < MIN_HIP_SHIFT
    ):
        reasons.append(
            "Bé gần như không đổi vị trí trong khung hình, thường do máy quay đi theo bé. "
            "AI cần máy đứng yên để thấy bé di chuyển."
        )

    if not reasons:
        if assessment.reason == scorer.OTHER_ITEM and predicted in ITEM_INDEX:
            reasons.append(
                f"Chuyển động trong video giống bài “{ITEMS[ITEM_INDEX[predicted]].name_vi}” hơn bài đã chọn. "
                "Có thể video có đoạn bé làm việc khác, hoặc góc quay khiến động tác khó nhận ra."
            )
        elif assessment.reason != scorer.NO_BODY:
            reasons.append(
                "Động tác của bé chưa đủ rõ để AI chấm chắc chắn, thường do quay từ sau lưng, "
                "góc quay quá chéo hoặc bé bị che một phần."
            )
    return reasons[:MAX_REASONS]


def render(assessment: scorer.KdstAssessment, child_age_months: int) -> InsightResult:
    """Nhận xét khi model đủ tin cậy (assessment.confident)."""
    item = ITEMS[ITEM_INDEX[assessment.item]]
    text = TEXTS[item.code]
    level = assessment.level
    name = item.name_vi

    comment = _COMMENT[level].format(name=name)
    if child_age_months < item.age_from_months and level != "steady":
        comment += f" Bài này thường dành cho bé từ {item.age_from_months} tháng, nên bé chưa làm được là bình thường."
    comment += " " + DISCLAIMER

    late = level == "not_yet" and child_age_months > item.age_to_months
    return InsightResult(
        can_assess=True,
        observations=[getattr(text, level)],
        comment=comment,
        positives=[_POSITIVE[level].format(name=name)],
        next_steps=[text.challenge] if level == "steady" else list(text.practice),
        see_specialist=late,
        specialist_note=(
            f"Đa số bé làm được bài “{name}” trong khoảng {item.age_from_months}–{item.age_to_months} tháng. "
            "Ba mẹ cho bé tập thêm 2–4 tuần; nếu bé vẫn chưa làm được, hãy trao đổi với bác sĩ nhi "
            "hoặc chuyên gia vận động để được đánh giá kỹ hơn."
            if late else ""
        ),
    )


def uncertain(
    assessment: scorer.KdstAssessment,
    seconds: float | None = None,
    pose: PoseSeries | None = None,
) -> InsightResult:
    """Khi model không chắc chắn và không dùng LLM dự phòng: nêu lý do và cách quay lại.

    video_issue = các lý do (mỗi dòng một ý); next_steps = hướng dẫn quay lại.
    """
    name = ITEMS[ITEM_INDEX[assessment.item]].name_vi
    reasons = diagnose(
        assessment,
        seconds=seconds,
        visible_ratio=pose_metrics.detection_ratio(pose) if pose is not None and len(pose.t) else None,
        hip_shift=pose_metrics.hip_shift(pose) if pose is not None else None,
    )
    issue = f"Chưa chấm được bài “{name}” từ video này. Lý do:\n" + "\n".join(f"• {r}" for r in reasons)
    return InsightResult(can_assess=False, video_issue=issue, next_steps=filming_guide(assessment.item))
