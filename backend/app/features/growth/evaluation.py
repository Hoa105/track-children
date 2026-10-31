"""Evaluate immutable input snapshots and produce versioned per-indicator results."""

from collections import OrderedDict
from datetime import date
import hashlib
import json
import math
import time
import threading

from . import anthro_client, content

MAPPING = {
    "wfa": ("weight", "zwei", "fwei"),
    "lhfa": ("height", "zlen", "flen"),
    "hcfa": ("head_circumference", "zhc", "fhc"),
    "bmifa": ("weight", "zbmi", "fbmi"),
    "wfl": ("weight", "zwfl", "fwfl"),
    "wfh": ("weight", "zwfl", "fwfl"),
}
MEMO = OrderedDict()
MEMO_LOCK = threading.Lock()


def add_months(day, months):
    import calendar

    year, month = divmod(day.year * 12 + day.month - 1 + months, 12)
    return date(year, month + 1, min(day.day, calendar.monthrange(year, month + 1)[1]))


def digest(profile, rows):
    value = {
        "child": str(profile["id"]),
        "birth": str(profile["date_of_birth"]),
        "sex": profile["gender"],
        "rows": [
            (
                str(r["id"]),
                r["metric"],
                str(r["measured_on"]),
                format(r["value"], ".2f"),
                r["measure_position"],
            )
            for r in rows
        ],
    }
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


def tag(profile, by_metric, indicator):
    primary = MAPPING[indicator][0]
    rows = [by_metric[primary]]
    if indicator in ("bmifa", "wfl", "wfh") and "height" in by_metric:
        rows.append(by_metric["height"])
    return (
        "W06-"
        + hashlib.sha256(
            (
                digest(profile, rows)
                + indicator
                + anthro_client.bundle()
                + content.RULE_HASH
                + "policy1"
            ).encode()
        ).hexdigest()[:24]
    )


def normalized(age, by_metric):
    h = by_metric.get("height")
    if not h:
        return None
    raw = float(h["value"])
    invalid = h["measure_position"] == "standing" and age / 30.4375 < 9
    adjustment = (
        0.7
        if age < 731 and h["measure_position"] == "standing"
        else -0.7 if age >= 731 and h["measure_position"] == "lying" else 0
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


def evaluate(profile, rows, cached, selected=None, budget=15):
    days = {}
    for row in rows:
        days.setdefault(row["measured_on"], {})[row["metric"]] = row
    outputs = {}
    needed = []
    requests = []
    cache = {(str(c["measurement_id"]), c["indicator"]): c for c in cached}
    order = sorted(days, reverse=True)
    if selected:
        order.sort(
            key=lambda day: not any(
                str(r["id"]) == str(selected) for r in days[day].values()
            )
        )
    for day in order:
        values = days[day]
        age = (day - profile["date_of_birth"]).days
        indicators = [
            i
            for i, (metric, _, _) in MAPPING.items()
            if metric in values
            and (i not in ("wfl", "wfh") or (i == "wfl") == (age < 731))
        ]
        result = {}
        outputs[day] = result
        for indicator in indicators:
            pre_status = pre_reason = None
            norm = normalized(age, values)
            if profile["gender"] not in ("male", "female"):
                pre_status, pre_reason = "NOT_ASSESSABLE", "MISSING_SEX"
            elif day < profile["date_of_birth"] or day >= add_months(
                profile["date_of_birth"], 60
            ):
                pre_status, pre_reason = "NOT_APPLICABLE", "OUT_OF_SCOPE_AGE"
            elif indicator in ("bmifa", "wfl", "wfh") and "height" not in values:
                pre_status, pre_reason = "NOT_ASSESSABLE", "MISSING_PAIRED_MEASUREMENT"
            elif (
                indicator in ("lhfa", "bmifa", "wfl", "wfh")
                and norm
                and norm["status"] != "READY"
            ):
                pre_status, pre_reason = "RECHECK_DATA", "INVALID_MEASURE_POSITION"
            if pre_status:
                result[indicator] = make(
                    profile, day, values, indicator, pre_status, pre_reason, None, None
                )
                continue
            key = tag(profile, values, indicator)
            stored = cache.get((str(values[MAPPING[indicator][0]]["id"]), indicator))
            if (
                stored
                and stored["standard_version"] == key
                and math.isfinite(float(stored["z_score"]))
                and content.classify(indicator, float(stored["z_score"]))
                == stored["classification"]
            ):
                result[indicator] = make(
                    profile,
                    day,
                    values,
                    indicator,
                    "READY",
                    None,
                    float(stored["z_score"]),
                    key,
                )
            else:
                with MEMO_LOCK:
                    memo = MEMO.get(key)
                    if memo and memo[0] > time.monotonic():
                        result[indicator] = memo[1]
        if len(result) < len(indicators):
            needed.append((day, indicators))
            requests.append(
                {
                    "row_id": str(day),
                    "sex": "m" if profile["gender"] == "male" else "f",
                    "age_days": age,
                    "weight_kg": (
                        float(values["weight"]["value"]) if "weight" in values else None
                    ),
                    "lenhei_cm": (
                        float(values["height"]["value"]) if "height" in values else None
                    ),
                    "measure": (
                        (
                            "l"
                            if values["height"]["measure_position"] == "lying"
                            else "h"
                        )
                        if "height" in values
                        else None
                    ),
                    "headc_cm": (
                        float(values["head_circumference"]["value"])
                        if "head_circumference" in values
                        else None
                    ),
                }
            )
    deadline = time.monotonic() + max(0, budget)
    computed = []
    for offset in range(0, len(needed), 128):
        pending = needed[offset : offset + 128]
        remaining = deadline - time.monotonic()
        response = {}
        failure = None
        if remaining > 0.1:
            try:
                response = {
                    r["row_id"]: r
                    for r in anthro_client.calculate(
                        requests[offset : offset + 128], remaining
                    )
                }
            except anthro_client.EngineUnavailable as exc:
                failure = exc.reason
        else:
            failure = "PENDING"
        for day, indicators in pending:
            values = days[day]
            age = (day - profile["date_of_birth"]).days
            norm = normalized(age, values)
            raw = response.get(str(day))
            for indicator in indicators:
                if indicator in outputs[day]:
                    continue
                status, reason, z = "READY", None, None
                if day < profile["date_of_birth"] or day >= add_months(
                    profile["date_of_birth"], 60
                ):
                    status, reason = "NOT_APPLICABLE", "OUT_OF_SCOPE_AGE"
                elif indicator in ("bmifa", "wfl", "wfh") and "height" not in values:
                    status, reason = "NOT_ASSESSABLE", "MISSING_PAIRED_MEASUREMENT"
                elif (
                    indicator in ("lhfa", "bmifa", "wfl", "wfh")
                    and norm
                    and norm["status"] != "READY"
                ):
                    status, reason = "RECHECK_DATA", "INVALID_MEASURE_POSITION"
                elif failure:
                    status, reason = (
                        ("PENDING_CALCULATION", None)
                        if failure == "PENDING"
                        else ("CALCULATION_UNAVAILABLE", failure)
                    )
                else:
                    _, zc, fc = MAPPING[indicator]
                    z = raw[zc]
                    flag = raw[fc]
                    if z is None:
                        status, reason = "NOT_ASSESSABLE", "WHO_OUT_OF_RANGE"
                    elif (
                        isinstance(z, bool)
                        or not isinstance(z, (int, float))
                        or not math.isfinite(z)
                        or flag not in (0, 1)
                        or isinstance(flag, bool)
                    ):
                        status, reason = "CALCULATION_UNAVAILABLE", "INVALID_R_RESPONSE"
                    elif flag == 1:
                        status, reason = "RECHECK_DATA", "WHO_FLAGGED"
                key = tag(profile, values, indicator)
                value = make(
                    profile,
                    day,
                    values,
                    indicator,
                    status,
                    reason,
                    z if status == "READY" else None,
                    key if status == "READY" else None,
                )
                outputs[day][indicator] = value
                if status == "READY" and value["classificationCode"]:
                    computed.append((key, value))
                if status != "PENDING_CALCULATION":
                    with MEMO_LOCK:
                        MEMO[key] = (
                            time.monotonic()
                            + (5 if status == "CALCULATION_UNAVAILABLE" else 30),
                            value,
                        )
                        MEMO.move_to_end(key)
                        while len(MEMO) > 1000:
                            MEMO.popitem(last=False)
    return days, outputs, computed


def make(profile, day, values, indicator, status, reason, z, cache_tag):
    primary = values[MAPPING[indicator][0]]
    paired = values.get("height") if indicator in ("bmifa", "wfl", "wfh") else None
    classification = content.classify(indicator, z) if status == "READY" else None
    params = {
        "indicator_name": indicator.upper(),
        "age_label": f"{(day-profile['date_of_birth']).days} ngày",
        "current_value": float(primary["value"]),
        "unit": "kg" if primary["metric"] == "weight" else "cm",
        "z_score": z,
    }
    if indicator == "bmifa" and paired:
        norm = normalized((day - profile["date_of_birth"]).days, values)
        if norm and norm["normalizedLenheiCm"]:
            params.update(
                current_value=float(primary["value"])
                / (norm["normalizedLenheiCm"] / 100) ** 2,
                unit="kg/m²",
            )
    kind = "ATTAINED" if status == "READY" else "ASSESSMENT_STATUS"
    code = classification or (
        content.classify(indicator, z, approved=False) if status == "READY" else status
    )
    rendered = content.render(
        kind, indicator.upper() if kind == "ATTAINED" else "ALL_ATTAINED", code, params
    )
    if status != "READY" and reason:
        detail = content.render("ASSESSMENT_REASON", "ALL_ATTAINED", reason, params)
        if rendered["comment"]["status"] == detail["comment"]["status"] == "READY":
            rendered["comment"]["text"] += " " + detail["comment"]["text"]
        if rendered["advice"][0]["status"] == detail["advice"][0]["status"] == "READY":
            rendered["advice"][0]["text"] += " " + detail["advice"][0]["text"]
    if status == "READY" and classification:
        age_code = (
            "AGE_0_5_MONTHS"
            if day < add_months(profile["date_of_birth"], 6)
            else (
                "AGE_6_23_MONTHS"
                if day < add_months(profile["date_of_birth"], 24)
                else "AGE_24_59_MONTHS"
            )
        )
        rendered["ageContext"] = [
            content.block("AGE_CONTEXT", "ALL", age_code, params, True)
        ]
    if status == "READY" and classification is None:
        rendered['overview'] = {'status': 'NOT_AVAILABLE', 'text': ''}
        for block in [rendered["comment"], *rendered["advice"]]:
            block.update(status="MAPPING_NOT_APPROVED", text=content.FALLBACK)
    return {
        "indicator": indicator,
        "measurementId": str(primary["id"]),
        "pairedMeasurementId": str(paired["id"]) if paired else None,
        "status": status,
        "reason": reason,
        "zScore": z,
        "classificationCode": classification,
        "zScorePrecision": 2,
        "precisionSource": "anthro_public_output",
        "sourceStandard": "WHO-2007" if indicator == "hcfa" else "WHO-2006",
        "cacheTag": cache_tag if classification else None,
        "content": rendered,
    }
