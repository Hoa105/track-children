"""Normalized length/height and versioned WHO anthro evaluation for parent tracking."""

import calendar
from datetime import date
import json
import math
from pathlib import Path

from . import anthro_client

TEXT_PATH = (
    Path(__file__).resolve().parents[3]
    / "data/growth/GROWTH-PARENT-ASSESSMENT-TEXT.vi.json"
)


def load_visual_ranges() -> dict:
    data = json.loads(TEXT_PATH.read_text(encoding="utf-8"))
    return data.get("visualRanges", {})


def classify(indicator: str, z: float | None) -> str | None:
    if z is None or not math.isfinite(z):
        return None
    ranges = load_visual_ranges().get("head" if indicator == "hcfa" else "bmi", [])
    for item in ranges:
        lo = item.get("zMin")
        hi = item.get("zMax")
        if lo is not None and (z < lo or (z == lo and not item.get("zMinInclusive", True))):
            continue
        if hi is not None and (z > hi or (z == hi and not item.get("zMaxInclusive", True))):
            continue
        return item["code"]
    return None


def add_months(day: date, months: int) -> date:
    year, month = divmod(day.year * 12 + day.month - 1 + months, 12)
    return date(year, month + 1, min(day.day, calendar.monthrange(year, month + 1)[1]))


def normalized(age: int, by_metric: dict) -> dict | None:
    h = by_metric.get("height")
    if not h:
        return None
    raw = float(h["value"])
    pos = h.get("measure_position") if isinstance(h, dict) else getattr(h, "measurePosition", None)
    invalid = pos == "standing" and age / 30.4375 < 9
    adjustment = (
        0.7
        if age < 731 and pos == "standing"
        else -0.7
        if age >= 731 and pos == "lying"
        else 0
    )
    return {
        "status": "RECHECK_DATA" if invalid else "READY",
        "reason": "INVALID_MEASURE_POSITION" if invalid else None,
        "basis": (
            None if invalid else "recumbent_length" if age < 731 else "standing_height"
        ),
        "normalizedLenheiCm": None if invalid else round(raw + adjustment, 2),
        "adjustmentCm": None if invalid else adjustment,
    }


def score_pair(profile: dict, values: dict, indicator: str) -> dict:
    if profile.get("gestational_weeks") is not None and profile["gestational_weeks"] < 37:
        return {"status": "NOT_ASSESSABLE", "reason": "PRETERM_REQUIRES_REVIEW"}

    if profile.get("gender") not in ("male", "female"):
        return {"status": "NOT_ASSESSABLE", "reason": "MISSING_SEX"}

    primary = values.get("head_circumference" if indicator == "hcfa" else "weight")
    if primary is None:
        return {"status": "NOT_ASSESSABLE", "reason": "MISSING_PRIMARY_MEASUREMENT"}

    day = primary["measured_on"]
    birth = profile["date_of_birth"]
    age = (day - birth).days

    if day < birth or day >= add_months(birth, 60):
        return {"status": "NOT_APPLICABLE", "reason": "OUT_OF_SCOPE_AGE"}

    norm = None
    if indicator == "bmifa":
        if "height" not in values or values["height"] is None:
            return {"status": "NOT_ASSESSABLE", "reason": "MISSING_PAIRED_MEASUREMENT"}
        norm = normalized(age, values)
        if norm and norm["status"] != "READY":
            return {"status": "RECHECK_DATA", "reason": "INVALID_MEASURE_POSITION"}

    request_row = {
        "row_id": str(day),
        "sex": "m" if profile["gender"] == "male" else "f",
        "age_days": age,
        "weight_kg": (
            float(values["weight"]["value"]) if "weight" in values and values["weight"] else None
        ),
        "lenhei_cm": (
            float(values["height"]["value"]) if "height" in values and values["height"] else None
        ),
        "measure": (
            (
                "l"
                if values["height"].get("measure_position") == "lying"
                else "h"
            )
            if "height" in values and values["height"]
            else None
        ),
        "headc_cm": (
            float(values["head_circumference"]["value"])
            if "head_circumference" in values and values["head_circumference"]
            else None
        ),
    }

    try:
        results = anthro_client.calculate([request_row])
        raw = results[0] if results else None
    except anthro_client.EngineUnavailable as exc:
        return {"status": "CALCULATION_UNAVAILABLE", "reason": exc.reason}

    if not raw:
        return {"status": "CALCULATION_UNAVAILABLE", "reason": "NO_RESPONSE"}

    zc = "zbmi" if indicator == "bmifa" else "zhc"
    fc = "fbmi" if indicator == "bmifa" else "fhc"
    z = raw.get(zc)
    flag = raw.get(fc)

    if z is None:
        return {"status": "NOT_ASSESSABLE", "reason": "WHO_OUT_OF_RANGE"}

    if (
        isinstance(z, bool)
        or not isinstance(z, (int, float))
        or not math.isfinite(z)
        or flag not in (0, 1)
        or isinstance(flag, bool)
    ):
        return {"status": "CALCULATION_UNAVAILABLE", "reason": "INVALID_R_RESPONSE"}

    if flag == 1:
        return {"status": "RECHECK_DATA", "reason": "WHO_FLAGGED", "zScore": z}

    classification = classify(indicator, z)
    return {
        "status": "READY",
        "reason": None,
        "zScore": z,
        "classificationCode": classification,
        "sourceStandard": "WHO-2007" if indicator == "hcfa" else "WHO-2006",
    }
