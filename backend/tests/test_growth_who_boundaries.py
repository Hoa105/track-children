from datetime import date, timedelta

import pytest

from app.features.growth import evaluation, reference, velocity
from app.features.growth import service


def test_wfa_full_domain_is_independent_of_child_age_and_date_filter():
    birth = date(2025, 1, 1)
    state = {"profile": {"date_of_birth": birth, "gender": "female"},
             "scope": {"startOn": date(2025, 3, 1), "endBefore": date(2025, 4, 1)}}
    chart = service.chart(state, "wfa", [])
    assert chart["xAxis"]["min"] == 0
    assert chart["xAxis"]["max"] == 1826
    assert chart["childPoints"] == []
    for curve in chart["reference"]["segments"][0]["curves"]:
        assert curve["points"][0]["x"] == 0
        assert curve["points"][-1]["x"] == 1826
        assert len(curve["points"]) == 1827


@pytest.mark.parametrize("birth", [date(2023, 1, 15), date(2024, 2, 29)])
def test_exact_24_months_matches_but_next_day_is_recording_only(birth):
    tables, entry = reference.velocity_tables()
    def reading(month, value, extra=0):
        return {"id": str(month)+str(extra), "metric": "weight", "value": value,
                "measured_on": evaluation.add_months(birth, month)+timedelta(days=extra),
                "measure_position": None}
    profile = {"date_of_birth": birth, "gender": "female"}
    a, b = reading(22, 11), reading(24, 11.4)
    exact = velocity.make_interval(profile, a, b, "weight", tables, entry, 2)
    assert exact["referenceStatus"] == "REFERENCE_MATCHED"
    after = velocity.make_interval(profile, a, reading(24, 11.4, 1), "weight", tables, entry, 2)
    assert after["referenceStatus"] == "REFERENCE_NOT_APPLICABLE"
    assert after["deltaValue"] == pytest.approx(400)
    assert after["content"] is None and after["zScore"] is None
    head_a = {**a, "metric": "head_circumference", "value": 48}
    head_b = {**b, "metric": "head_circumference", "value": 48.2}
    # WHO head circumference two-month tables end at 12 months, not 24.
    head = velocity.make_interval(profile, head_a, head_b, "head_circumference", tables, entry, 2)
    assert head["referenceStatus"] == "NO_EXACT_REFERENCE"


def test_after_24_response_suppresses_trend_and_content_in_both_modes(monkeypatch):
    birth = date(2022, 1, 1)
    rows = [{"id": str(m), "metric": "weight", "value": 10+m/10,
             "measured_on": evaluation.add_months(birth, m), "measure_position": None}
            for m in (23, 24, 25)]
    state = {"profile": {"date_of_birth": birth, "gender": "female"}, "rows": rows}
    monkeypatch.setattr(velocity.service, "common", lambda _: {})
    monkeypatch.setattr(velocity.service, "in_scope", lambda *_: True)
    monkeypatch.setattr(velocity.service, "capabilities", lambda: {})
    for mode, period in (("actual", None), ("who", 2)):
        result = velocity.build(state, "weight", mode, period)
        assert result["content"] is None and result["trend"] is None
        assert result["actualIntervals"][-1]["content"] is None


def test_hcfa_assessment_and_curves_report_2007():
    value = evaluation.make({"date_of_birth": date(2025, 1, 1)}, date(2026, 1, 1),
        {"head_circumference": {"id": "hc", "metric": "head_circumference", "value": 46}},
        "hcfa", "READY", None, 0.81, None)
    assert value["sourceStandard"] == "WHO-2007"
    curves = reference.curves("hcfa", "female", 0, 365)
    assert curves["standard"] == "WHO-2007"
    assert all(s["standard"] == "WHO-2007" for s in curves["sources"])
    assert reference.curves("wfa", "female", 0, 365)["standard"] == "WHO-2006"
