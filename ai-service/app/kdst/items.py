"""12 bài vận động thô K-DST trong dataset Multiview (GigaDB 10.5524/102382).

Thứ tự trong ITEMS là chỉ số đầu ra của model (đầu chấm điểm thứ i ↔ ITEMS[i]).
Tên file dataset: {mã trẻ}_GMS_{bài 1-4}_{lần thử}_{góc quay 1-3}.json,
nhóm tuổi lấy từ chữ cái đầu của mã trẻ (A/B/C).
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class KdstItem:
    code: str  # A01 … C04
    name_vi: str
    name_en: str
    age_from_months: int
    age_to_months: int


_AGE = {"A": (20, 35), "B": (36, 53), "C": (54, 71)}

ITEMS: tuple[KdstItem, ...] = tuple(
    KdstItem(code, vi, en, *_AGE[code[0]])
    for code, vi, en in [
        ("A01", "Đi lên cầu thang", "climb the stairs"),
        ("A02", "Đi xuống cầu thang", "go down the stairs"),
        ("A03", "Ném bóng qua đầu", "throw the ball"),
        ("A04", "Đứng một chân 1 giây", "standing with one leg for 1 sec"),
        ("B01", "Đứng một chân trên 3 giây", "standing with one leg for 3 sec"),
        ("B02", "Nhảy lò cò 2–3 bước", "hopping with one leg"),
        ("B03", "Bật xa bằng hai chân", "long jump"),
        ("B04", "Bắt bóng", "catching the ball"),
        ("C01", "Chặn bóng lăn bằng chân", "stopping a rolling ball with foot"),
        ("C02", "Đập bóng nảy", "bouncing the ball"),
        ("C03", "Nhảy qua dây", "jumping over the rope"),
        ("C04", "Nhảy dây", "jump a rope once"),
    ]
)

ITEM_INDEX = {item.code: i for i, item in enumerate(ITEMS)}

# Nhãn của chuyên gia trong dataset: Bad / Good / Perfect
SCORE_LABELS = ("not_yet", "unsteady", "steady")  # 0 / 1 / 2


def item_code(age_group: str, action: int) -> str:
    return f"{age_group}{action:02d}"
