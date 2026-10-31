"""No database required: normalized thresholds, content and error explanations."""
from datetime import date
import json
from pathlib import Path

import pytest

from app.features.growth import content, evaluation

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = json.loads(
    (ROOT / "docs/core_growth/GROWTH-STATUS-CONTRACT.json").read_text(encoding="utf-8")
)


@pytest.mark.parametrize("rule", content.RULES)
def test_every_classification_renders_with_actual_assessment_inputs(rule):
    lo, hi = rule["z_min"], rule["z_max"]
    z = (float(lo) + float(hi)) / 2 if lo and hi else float(lo) + 0.5 if lo else float(hi) - 0.5
    indicator = rule["indicator"].lower()
    assert content.classify(indicator, z) == rule["classification_code"]
    # Same placeholders supplied by evaluation.make; no invented context required.
    value = content.render("ATTAINED", rule["indicator"], rule["classification_code"], {
        "indicator_name": rule["indicator"], "age_label": "365 ngày",
        "current_value": 9.5, "unit": "kg", "z_score": z,
    })
    assert value["comment"]["status"] == "READY"
    assert all(a["status"] == "READY" for a in value["advice"])
    assert rule["ui_label"].lower() in value["comment"]["text"]
    assert "{{" not in value["comment"]["text"]


REASONS = [(status, reason) for status, reasons in CONTRACT["assessment_reasons_by_status"].items()
           for reason in reasons]


@pytest.mark.parametrize("status,reason", REASONS)
def test_non_ready_result_explains_exact_reason_without_classifying(status, reason):
    result = evaluation.make(
        {"date_of_birth": date(2025, 1, 1)}, date(2026, 1, 1),
        {"weight": {"id": "test", "metric": "weight", "value": 9.5}},
        "wfa", status, reason, None, None,
    )
    assert result["classificationCode"] is None
    assert result["zScore"] is None
    assert result["content"]["comment"]["status"] == "READY"
    assert CONTRACT["assessment_reason_text"][reason] in result["content"]["comment"]["text"]
    assert result["content"]["advice"][0]["status"] == "READY"


def test_actual_only_uses_available_velocity_context():
    value = content.render("VELOCITY", "ALL_SUPPORTED_VELOCITY", "ACTUAL_ONLY", {
        "start_date": "2026-01-01", "end_date": "2026-02-02", "delta_value": -100,
        "delta_unit": "g", "rate_per_month": -95.12, "rate_unit": "g/month",
        "interval_label": None,
    })
    assert value["comment"]["status"] == "READY"
    assert "-100" in value["comment"]["text"]
    assert "chưa kết luận" in value["comment"]["text"]
