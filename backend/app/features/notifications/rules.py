"""Scheduling policy, independent of storage and transport."""
from datetime import date, timedelta


# FRS §2: Chu kỳ mặc định theo độ tuổi (ngày)
# Thứ tự: (weight, height/length, head_circumference)
# None = Tắt mặc định
_AGE_BASED_TABLE = [
    # (min_months, max_months_exclusive, weight, height, head)
    (0,  6,  30, 90, 30),
    (6,  12, 60, 90, 30),
    (12, 24, 90, 90, 90),
    (24, 61, 90, 90, None),   # head_circumference tắt sau 24 tháng
]

_METRIC_INDEX = {'weight': 0, 'height': 1, 'head_circumference': 2}


def age_based_interval(metric: str, age_months: int) -> int | None:
    """Trả về chu kỳ mặc định (ngày) theo độ tuổi và chỉ số.
    Trả về None nếu chỉ số không áp dụng ở độ tuổi này (tắt mặc định).
    """
    idx = _METRIC_INDEX.get(metric)
    if idx is None:
        return None
    for min_m, max_m, *intervals in _AGE_BASED_TABLE:
        if min_m <= age_months < max_m:
            return intervals[idx]
    return None  # ngoài phạm vi 0–60 tháng


def assessment_stage(state, day):
    if not state['set'] or state['latest_completed'] or state['age_months'] is None:
        return None
    milestone = next((m for m in state['milestones'] if m['age_months'] == state['age_months']), None)
    if not milestone or not milestone['opens_on'] <= day < milestone['closes_on']:
        return None
    return 'repeat' if (day - milestone['opens_on']).days >= 7 else 'open'


def growth_due(last: date, interval_days: int, settings: dict) -> date:
    """Tính ngày đến hạn kế tiếp cho một chỉ số."""
    return max(
        last + timedelta(days=interval_days),
        settings.get('snoozed_until') or last,
        settings.get('appointment_on') or last,
    )


def effective_interval(metric: str, age_months: int, setting: dict) -> int | None:
    """Trả về chu kỳ hiệu lực (ngày) dựa trên mode.
    - mode=age_based: dùng bảng mặc định theo tuổi
    - mode=custom: dùng interval_days của user; None = Tắt
    - Nếu enabled=False: trả về None (tắt)
    """
    if not setting.get('enabled', True):
        return None
    mode = setting.get('mode', 'age_based')
    if mode == 'custom':
        return setting.get('interval_days')  # None = Tắt khi custom
    # age_based
    return age_based_interval(metric, age_months)
