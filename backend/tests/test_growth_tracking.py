"""Unit tests for the parent growth tracking logic."""

from datetime import date, datetime
import pytest
from app.features.growth import evaluation, pairing, tracking


def test_normalized_lenhei_positions():
    # Infant under 9 months standing is invalid
    infant = evaluation.normalized(120, {"height": {"value": 65.0, "measure_position": "standing"}})
    assert infant["status"] == "RECHECK_DATA"
    assert infant["reason"] == "INVALID_MEASURE_POSITION"

    # Child under 2 years standing has +0.7 cm adjustment
    standing_toddler = evaluation.normalized(400, {"height": {"value": 75.0, "measure_position": "standing"}})
    assert standing_toddler["status"] == "READY"
    assert standing_toddler["adjustmentCm"] == 0.7
    assert standing_toddler["normalizedLenheiCm"] == 75.7

    # Child >= 2 years lying has -0.7 cm adjustment
    lying_older = evaluation.normalized(800, {"height": {"value": 90.0, "measure_position": "lying"}})
    assert lying_older["status"] == "READY"
    assert lying_older["adjustmentCm"] == -0.7
    assert lying_older["normalizedLenheiCm"] == 89.3


def test_classify_bmi_and_head():
    # BMI classifications
    assert evaluation.classify("bmifa", -3.5) == "SEVERE_THINNESS"
    assert evaluation.classify("bmifa", -2.5) == "THINNESS"
    assert evaluation.classify("bmifa", -2.0) == "WITHIN_RANGE"
    assert evaluation.classify("bmifa", 0.0) == "WITHIN_RANGE"
    assert evaluation.classify("bmifa", 1.0) == "WITHIN_RANGE"
    assert evaluation.classify("bmifa", 1.5) == "RISK_OVERWEIGHT"
    assert evaluation.classify("bmifa", 2.0) == "RISK_OVERWEIGHT"
    assert evaluation.classify("bmifa", 2.5) == "OVERWEIGHT"
    assert evaluation.classify("bmifa", 3.0) == "OVERWEIGHT"
    assert evaluation.classify("bmifa", 3.5) == "OBESITY"

    # Head circumference classifications
    assert evaluation.classify("hcfa", -3.5) == "VERY_LOW_HC"
    assert evaluation.classify("hcfa", -2.5) == "LOW_HC"
    assert evaluation.classify("hcfa", 0.0) == "WITHIN_RANGE"
    assert evaluation.classify("hcfa", 2.5) == "HIGH_HC"
    assert evaluation.classify("hcfa", 3.5) == "VERY_HIGH_HC"


def test_public_result_parent_text():
    profile = {
        "id": "11111111-1111-1111-1111-111111111111",
        "full_name": "Nguyen Van A",
        "date_of_birth": date(2025, 1, 1),
        "gender": "male",
        "growth_access": "edit",
        "gestational_weeks": 40,
    }
    weight = {
        "id": "22222222-2222-2222-2222-222222222222",
        "metric": "weight",
        "value": 10.0,
        "measured_on": date(2026, 1, 1),
        "measured_at": datetime(2026, 1, 1, 8, 0),
        "measure_position": None,
        "note": None,
        "created_at": datetime.now(),
        "updated_at": datetime.now(),
    }
    height = {
        "id": "33333333-3333-3333-3333-333333333333",
        "metric": "height",
        "value": 75.0,
        "measured_on": date(2026, 1, 1),
        "measured_at": datetime(2026, 1, 1, 8, 0),
        "measure_position": "lying",
        "note": None,
        "created_at": datetime.now(),
        "updated_at": datetime.now(),
    }
    assessment = {
        "status": "READY",
        "reason": None,
        "zScore": 0.5,
        "classificationCode": "WITHIN_RANGE",
        "sourceStandard": "WHO-2006",
    }
    result = tracking.public_result(profile, [weight, height], weight=weight, height=height, assessment=assessment)
    assert result["status"] == "READY"
    assert result["classificationCode"] == "WITHIN_RANGE"
    assert "cân đối" in result["summary"].lower()
    assert result["action"]
    assert len(result["visualRanges"]) == 6
    assert result["bmi"] is not None
    assert result["zScore"] == 0.5


def test_preterm_child_assessment():
    profile = {
        "id": "11111111-1111-1111-1111-111111111111",
        "full_name": "Nguyen Van B",
        "date_of_birth": date(2025, 1, 1),
        "gender": "male",
        "growth_access": "edit",
        "gestational_weeks": 34,
    }
    weight = {
        "id": "22222222-2222-2222-2222-222222222222",
        "metric": "weight",
        "value": 9.0,
        "measured_on": date(2026, 1, 1),
        "measured_at": datetime(2026, 1, 1, 8, 0),
        "measure_position": None,
        "note": None,
        "created_at": datetime.now(),
        "updated_at": datetime.now(),
    }
    result = tracking.public_result(profile, [weight], weight=weight, assessment=None)
    assert result["status"] == "NOT_ASSESSABLE"
    assert result["reason"] == "PRETERM_REQUIRES_REVIEW"
    assert "sinh non" in result["summary"].lower()


def test_pairing_nearest_calendar_day():
    w = {"id": "w1", "metric": "weight", "measured_on": date(2026, 5, 10)}
    h_same = {"id": "h1", "metric": "height", "measured_on": date(2026, 5, 10)}
    h_adjacent = {"id": "h2", "metric": "height", "measured_on": date(2026, 5, 11)}
    h_far = {"id": "h3", "metric": "height", "measured_on": date(2026, 5, 15)}

    # Same day should win
    assert pairing.nearest(w, [h_same, h_adjacent, h_far]) == h_same
    # Adjacent day accepted if same day absent
    assert pairing.nearest(w, [h_adjacent, h_far]) == h_adjacent
    # Far day rejected
    assert pairing.nearest(w, [h_far]) is None
