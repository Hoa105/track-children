"""Nhận xét mẫu cho 12 bài K-DST theo mức model chấm — thay cho câu trả lời của LLM.

Không đưa điểm số hay xác suất cho phụ huynh: chỉ mô tả, gợi ý tập và lời khuyên
đi khám khi bé đã quá độ tuổi của bài mà vẫn chưa làm được.
"""

from dataclasses import dataclass

from app.kdst import scorer
from app.kdst.items import ITEM_INDEX, ITEMS
from app.schemas.insight import InsightResult

VERSION = "kdst-template-1"

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
        not_yet="Bé chưa tự bước lên cầu thang được; chuyển động cho thấy bé còn cần người lớn đỡ.",
        practice=(
            "Cho bé tập bước lên bậc thấp (10–15 cm) và vịn tay vịn, ba mẹ đứng phía sau bé.",
            "Chơi trò bước lên – bước xuống một bậc thấp, mỗi lần 5–10 lượt.",
        ),
        challenge="Cho bé thử bước lên mỗi bậc một chân (luân phiên chân) khi vẫn vịn tay vịn.",
    ),
    "A02": ItemText(
        steady="Bé tự bước xuống cầu thang chắc chắn, đặt chân vững và giữ được thăng bằng.",
        unsteady="Bé đã bước xuống được nhưng còn dè dặt, thân người có lúc nghiêng hoặc mất thăng bằng.",
        not_yet="Bé chưa tự bước xuống cầu thang được; bé còn cần người lớn nắm tay hoặc bế.",
        practice=(
            "Tập bước xuống từ một bậc thấp, bé vịn tay vịn và ba mẹ đứng phía trước đỡ.",
            "Cho bé chơi leo – trượt trên cầu trượt thấp để quen cảm giác đi xuống.",
        ),
        challenge="Cho bé thử bước xuống luân phiên chân, ba mẹ vẫn đứng gần để an toàn.",
    ),
    "A03": ItemText(
        steady="Bé đưa tay lên cao qua đầu và ném bóng về phía trước rõ ràng, thân người giữ vững.",
        unsteady="Bé đã ném được bóng nhưng động tác tay còn ngắn hoặc thân người chưa vững khi ném.",
        not_yet="Bé chưa thực hiện được động tác ném bóng qua đầu; bóng thường rơi xuống ngay hoặc bé thả bóng.",
        practice=(
            "Dùng bóng nhẹ, vừa tay; ba mẹ làm mẫu đưa bóng ra sau đầu rồi ném về phía trước.",
            "Chơi ném bóng vào thùng hoặc rổ to đặt cách bé 1 mét.",
        ),
        challenge="Tăng dần khoảng cách ném, hoặc cho bé ném trúng một mục tiêu nhỏ hơn.",
    ),
    "A04": ItemText(
        steady="Bé đứng được trên một chân trong chốc lát, thân người giữ thẳng.",
        unsteady="Bé đã nhấc được một chân lên nhưng giữ rất ngắn, thân người còn chao đảo.",
        not_yet="Bé chưa đứng được trên một chân; bé đặt chân xuống ngay hoặc cần vịn.",
        practice=(
            "Cho bé vịn tường hoặc tay ba mẹ rồi nhấc một chân lên, đếm 1–2 rồi đổi chân.",
            "Chơi trò bắt chước 'con cò đứng một chân' cùng ba mẹ.",
        ),
        challenge="Cho bé thử đứng một chân không vịn, đếm tới 3, tập cả hai chân.",
    ),
    "B01": ItemText(
        steady="Bé đứng một chân được lâu, thân người vững và ít phải dang tay giữ thăng bằng.",
        unsteady="Bé đứng được một chân nhưng chưa lâu, thân người hoặc hai tay còn chao để giữ thăng bằng.",
        not_yet="Bé chưa giữ được tư thế đứng một chân; bé đặt chân xuống rất nhanh.",
        practice=(
            "Tập đứng một chân có vịn, tăng dần thời gian giữ từ 1 tới 3 giây, tập cả hai chân.",
            "Chơi trò 'tượng đứng một chân' khi tắt nhạc.",
        ),
        challenge="Cho bé đứng một chân lâu hơn (5–10 giây) hoặc đứng một chân trên gối mềm.",
    ),
    "B02": ItemText(
        steady="Bé nhảy lò cò liên tiếp trên một chân, tiếp đất vững và giữ được hướng.",
        unsteady="Bé đã nhảy lò cò được nhưng còn ít bước, tiếp đất chưa vững hoặc phải đặt chân kia xuống.",
        not_yet="Bé chưa nhảy lò cò được; bé thường nhảy bằng hai chân hoặc đặt chân kia xuống.",
        practice=(
            "Tập đứng một chân thật vững trước, rồi nắm tay bé nhảy lò cò tại chỗ 1–2 lần.",
            "Vẽ vài ô trên sàn và cùng bé nhảy lò cò từ ô này sang ô kia, có ba mẹ nắm tay.",
        ),
        challenge="Cho bé nhảy lò cò 5 bước liên tiếp, rồi tập đổi chân.",
    ),
    "B03": ItemText(
        steady="Bé bật xa bằng hai chân, hai chân rời đất và tiếp đất cùng lúc, giữ được thăng bằng.",
        unsteady="Bé đã bật nhảy về phía trước nhưng hai chân chưa đều hoặc tiếp đất còn loạng choạng.",
        not_yet="Bé chưa bật xa được bằng hai chân; bé thường bước chân hoặc chỉ nhảy tại chỗ.",
        practice=(
            "Cùng bé tập khuỵu gối rồi bật lên tại chỗ bằng hai chân trước khi bật về phía trước.",
            "Đặt một sợi dây trên sàn và cho bé nhảy qua bằng hai chân, ba mẹ nắm tay.",
        ),
        challenge="Đánh dấu điểm tiếp đất và khuyến khích bé bật xa hơn lần trước.",
    ),
    "B04": ItemText(
        steady="Bé đưa tay ra đón và bắt được bóng, thân người theo kịp hướng bóng.",
        unsteady="Bé đã đưa tay ra đón bóng nhưng còn chậm hoặc ôm bóng chưa chắc.",
        not_yet="Bé chưa bắt được bóng; bé thường đứng yên hoặc đưa tay ra quá muộn.",
        practice=(
            "Dùng bóng to, mềm; tung nhẹ ở khoảng cách gần (1 mét) và nhắc bé 'giơ tay ra đón'.",
            "Cho bé tập lăn bóng qua lại với ba mẹ trước khi chuyển sang tung bóng.",
        ),
        challenge="Tăng khoảng cách hoặc dùng bóng nhỏ hơn để bé tập bắt bằng hai bàn tay.",
    ),
    "C01": ItemText(
        steady="Bé dùng chân chặn được quả bóng đang lăn tới, đứng vững trên chân còn lại.",
        unsteady="Bé đã đưa chân ra chặn bóng nhưng còn chậm hoặc mất thăng bằng khi nhấc chân.",
        not_yet="Bé chưa chặn được bóng bằng chân; bé thường để bóng lăn qua hoặc dùng tay.",
        practice=(
            "Lăn bóng thật chậm về phía bé và cho bé đặt bàn chân lên bóng để giữ lại.",
            "Tập đứng một chân có vịn để bé quen nhấc chân mà vẫn đứng vững.",
        ),
        challenge="Lăn bóng nhanh hơn hoặc lệch sang hai bên để bé di chuyển chặn bóng.",
    ),
    "C02": ItemText(
        steady="Bé đập bóng xuống sàn và đón lại liên tiếp, tay và mắt phối hợp tốt.",
        unsteady="Bé đã đập được bóng nhưng chưa liên tục, có lúc bóng nảy lệch khỏi tầm tay.",
        not_yet="Bé chưa đập bóng nảy được; bé thường thả bóng hoặc ném bóng đi.",
        practice=(
            "Dùng bóng nảy tốt; cho bé thả bóng rồi bắt lại bằng hai tay trước.",
            "Ba mẹ làm mẫu đập bóng bằng một tay, đếm to từng lần để bé bắt chước.",
        ),
        challenge="Cho bé đập bóng liên tiếp 5 lần, rồi vừa đi vừa đập bóng.",
    ),
    "C03": ItemText(
        steady="Bé bật qua dây bằng hai chân, tiếp đất vững và không vướng dây.",
        unsteady="Bé đã nhảy qua được dây nhưng còn chạm dây hoặc tiếp đất chưa vững.",
        not_yet="Bé chưa nhảy qua được dây; bé thường bước qua hoặc dừng lại trước dây.",
        practice=(
            "Đặt dây sát sàn và cho bé bật qua bằng hai chân, sau đó mới nâng dây lên dần.",
            "Tập bật tại chỗ bằng hai chân để bé quen lực bật.",
        ),
        challenge="Nâng dây cao hơn một chút (an toàn, dây lỏng) hoặc nhảy qua lại liên tiếp.",
    ),
    "C04": ItemText(
        steady="Bé quay dây và nhảy qua dây được, động tác tay và chân khớp nhịp.",
        unsteady="Bé đã thử quay dây và nhảy nhưng tay – chân chưa khớp nhịp, dây hay vướng chân.",
        not_yet="Bé chưa nhảy dây được; bé quay dây và nhảy chưa phối hợp được với nhau.",
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
    "not_yet": "Bé đã tham gia và thử bài tập cùng ba mẹ",
}
_VIDEO_ISSUE = {
    scorer.NO_BODY: "Video chưa thấy rõ toàn thân bé. Ba mẹ quay ngang tầm bé, thấy cả đầu và bàn chân, "
    "đủ sáng, rồi gửi lại nhé.",
    scorer.OTHER_ITEM: "Video có vẻ chưa đúng bài “{name}”. Ba mẹ quay lại lúc bé đang thực hiện bài này, "
    "mỗi video một lần thử nhé.",
    scorer.LOW_CONFIDENCE: "Video chưa đủ rõ để nhận xét bài “{name}”. Ba mẹ quay toàn thân bé từ phía trước, "
    "giữ máy cố định, mỗi video một lần thử rồi gửi lại nhé.",
}


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


def uncertain(assessment: scorer.KdstAssessment) -> InsightResult:
    """Khi model không chắc chắn và không dùng LLM dự phòng: nhờ ba mẹ quay lại."""
    name = ITEMS[ITEM_INDEX[assessment.item]].name_vi
    issue = _VIDEO_ISSUE.get(assessment.reason, _VIDEO_ISSUE[scorer.LOW_CONFIDENCE])
    return InsightResult(can_assess=False, video_issue=issue.format(name=name))
