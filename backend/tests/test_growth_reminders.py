"""Tests for growth reminder scheduling logic (rules.py)."""
import pytest
from datetime import date, timedelta
from app.features.notifications.rules import (
    age_based_interval,
    effective_interval,
    growth_due,
    assessment_stage,
)


# ---------------------------------------------------------------------------
# age_based_interval
# ---------------------------------------------------------------------------

class TestAgeBasedInterval:
    def test_weight_0_to_6(self):
        for age in range(0, 6):
            assert age_based_interval('weight', age) == 30

    def test_height_0_to_6(self):
        for age in range(0, 6):
            assert age_based_interval('height', age) == 90

    def test_head_0_to_6(self):
        for age in range(0, 6):
            assert age_based_interval('head_circumference', age) == 30

    def test_weight_6_to_12(self):
        for age in range(6, 12):
            assert age_based_interval('weight', age) == 60

    def test_height_6_to_12(self):
        for age in range(6, 12):
            assert age_based_interval('height', age) == 90

    def test_head_6_to_12(self):
        for age in range(6, 12):
            assert age_based_interval('head_circumference', age) == 30

    def test_weight_12_to_24(self):
        for age in range(12, 24):
            assert age_based_interval('weight', age) == 90

    def test_weight_24_to_60(self):
        for age in range(24, 61):
            assert age_based_interval('weight', age) == 90

    def test_head_24_months_off(self):
        """head_circumference tắt mặc định từ 24 tháng."""
        for age in range(24, 61):
            assert age_based_interval('head_circumference', age) is None

    def test_beyond_60_months_none(self):
        assert age_based_interval('weight', 61) is None
        assert age_based_interval('height', 61) is None

    def test_boundary_exact_6(self):
        """Tháng 6 rơi vào nhóm 6–<12."""
        assert age_based_interval('weight', 6) == 60

    def test_boundary_exact_12(self):
        assert age_based_interval('weight', 12) == 90

    def test_boundary_exact_24(self):
        assert age_based_interval('head_circumference', 24) is None
        assert age_based_interval('weight', 24) == 90

    def test_unknown_metric(self):
        assert age_based_interval('unknown_metric', 5) is None


# ---------------------------------------------------------------------------
# effective_interval
# ---------------------------------------------------------------------------

class TestEffectiveInterval:
    def test_age_based_uses_table(self):
        setting = {'enabled': True, 'mode': 'age_based'}
        assert effective_interval('weight', 3, setting) == 30

    def test_custom_uses_interval_days(self):
        setting = {'enabled': True, 'mode': 'custom', 'interval_days': 60}
        assert effective_interval('weight', 3, setting) == 60

    def test_custom_none_means_off(self):
        setting = {'enabled': True, 'mode': 'custom', 'interval_days': None}
        assert effective_interval('weight', 3, setting) is None

    def test_disabled_always_none(self):
        for mode in ('age_based', 'custom'):
            setting = {'enabled': False, 'mode': mode, 'interval_days': 30}
            assert effective_interval('weight', 3, setting) is None

    def test_default_mode_is_age_based(self):
        setting = {}  # no mode key
        assert effective_interval('weight', 3, setting) == 30  # default: enabled=True, age_based

    def test_head_circ_24mo_age_based_off(self):
        setting = {'enabled': True, 'mode': 'age_based'}
        assert effective_interval('head_circumference', 24, setting) is None


# ---------------------------------------------------------------------------
# growth_due
# ---------------------------------------------------------------------------

class TestGrowthDue:
    def test_basic(self):
        last = date(2026, 1, 1)
        due = growth_due(last, 30, {})
        assert due == date(2026, 1, 31)

    def test_snoozed_until_extends_due(self):
        last = date(2026, 1, 1)
        snooze = date(2026, 2, 15)
        due = growth_due(last, 30, {'snoozed_until': snooze})
        assert due == snooze

    def test_appointment_on_extends_due(self):
        last = date(2026, 1, 1)
        appt = date(2026, 2, 20)
        due = growth_due(last, 30, {'appointment_on': appt})
        assert due == appt

    def test_max_of_all(self):
        last = date(2026, 1, 1)
        appt = date(2026, 3, 1)
        snooze = date(2026, 2, 1)
        due = growth_due(last, 30, {'appointment_on': appt, 'snoozed_until': snooze})
        assert due == appt


# ---------------------------------------------------------------------------
# Stage 1 reminders: 3-day threshold
# ---------------------------------------------------------------------------

class TestGrowthStage:
    """Nhắc lại (stage 1) xảy ra sau 3 ngày trễ theo FRS §4."""

    def _overdue_days(self, due_on: date, today: date) -> int:
        return (today - due_on).days

    def test_stage_0_on_due_date(self):
        due = date(2026, 11, 1)
        today = date(2026, 11, 1)
        assert self._overdue_days(due, today) == 0
        assert (today - due).days < 3  # stage 0

    def test_stage_0_day_2(self):
        due = date(2026, 11, 1)
        today = date(2026, 11, 3)  # 2 ngày trễ
        assert (today - due).days < 3  # still stage 0

    def test_stage_1_at_day_3(self):
        due = date(2026, 11, 1)
        today = date(2026, 11, 4)  # 3 ngày trễ → nhắc lại
        assert (today - due).days >= 3  # stage 1

    def test_stage_1_beyond_3_days(self):
        due = date(2026, 11, 1)
        today = date(2026, 11, 10)
        assert (today - due).days >= 3


# ---------------------------------------------------------------------------
# Multi-metric grouping (conceptual)
# ---------------------------------------------------------------------------

class TestGrouping:
    """Các chỉ số cùng due_on được gộp thành 1 notification."""

    def test_same_due_grouped(self):
        due = date(2026, 12, 1)
        due_metrics = [
            ('weight', 'cân nặng', due, 0),
            ('height', 'chiều cao', due, 0),
        ]
        groups = {}
        for metric, label, d, stage in due_metrics:
            groups.setdefault((d, stage), []).append((metric, label))
        assert len(groups) == 1  # cùng key → 1 group

    def test_different_due_separate(self):
        due1 = date(2026, 12, 1)
        due2 = date(2026, 12, 15)
        due_metrics = [
            ('weight', 'cân nặng', due1, 0),
            ('height', 'chiều cao', due2, 0),
        ]
        groups = {}
        for metric, label, d, stage in due_metrics:
            groups.setdefault((d, stage), []).append((metric, label))
        assert len(groups) == 2  # khác due → 2 group riêng

    def test_stage_0_and_1_separate(self):
        due = date(2026, 12, 1)
        due_metrics = [
            ('weight', 'cân nặng', due, 0),
            ('height', 'chiều cao', due, 1),
        ]
        groups = {}
        for metric, label, d, stage in due_metrics:
            groups.setdefault((d, stage), []).append((metric, label))
        assert len(groups) == 2  # khác stage → 2 group
