from datetime import timedelta
import math

from . import content, evaluation as ev, reference, service
from .errors import GrowthError


def anchor(birth, value, unit):
    return (
        birth + timedelta(days=value * 7)
        if unit == "wks"
        else ev.add_months(birth, value)
    )


def make_interval(profile, a, b, metric, tables, entry, period=None):
    age_a = (a["measured_on"] - profile["date_of_birth"]).days
    age_b = (b["measured_on"] - profile["date_of_birth"]).days
    days = (b["measured_on"] - a["measured_on"]).days

    def endpoint(row, age):
        norm = ev.normalized(age, {"height": row}) if metric == "height" else None
        value = float(row["value"])
        if norm and norm["status"] == "READY":
            # Both endpoints on a common length basis if the interval crosses day 731.
            length_basis = age_a < 731
            value = round(
                value
                + (
                    0.7
                    if length_basis and row["measure_position"] == "standing"
                    else (
                        -0.7
                        if not length_basis and row["measure_position"] == "lying"
                        else 0
                    )
                ),
                2,
            )
            norm = {
                **norm,
                "basis": "recumbent_length" if length_basis else "standing_height",
                "normalizedLenheiCm": value,
                "adjustmentCm": round(value - float(row["value"]), 1),
            }
        return {
            "measurementId": str(row["id"]),
            "measuredOn": row["measured_on"],
            "ageDays": age,
            "rawValue": float(row["value"]),
            "comparisonValue": None if norm and norm["status"] != "READY" else value,
            "normalization": norm,
        }

    first, last = endpoint(a, age_a), endpoint(b, age_b)
    status = (
        "INVALID_INTERVAL"
        if days <= 0
        else (
            "INCOMPARABLE_MEASUREMENTS"
            if first["comparisonValue"] is None or last["comparisonValue"] is None
            else "READY"
        )
    )
    delta = (
        (last["comparisonValue"] - first["comparisonValue"])
        * (1000 if metric == "weight" else 1)
        if status == "READY"
        else None
    )
    rate = delta / days * 30.4375 if delta is not None else None
    result = {
        "intervalId": str(a["id"]) + ":" + str(b["id"]),
        "from": first,
        "to": last,
        "elapsedDays": days,
        "calculationStatus": status,
        "deltaValue": delta,
        "deltaUnit": "g" if metric == "weight" else "cm",
        "ratePerMonth": rate,
        "rateUnit": "g/month" if metric == "weight" else "cm/month",
        "referenceStatus": "NOT_REQUESTED",
        "referenceReason": None,
        "matchedReference": None,
        "zScoreStatus": "NOT_REQUESTED",
        "zScoreReason": None,
        "zScore": None,
        "zScoreContent": None,
    }
    code = status
    if status == "READY":
        if b["measured_on"] > ev.add_months(profile["date_of_birth"], 24):
            result.update(
                referenceStatus="REFERENCE_NOT_APPLICABLE",
                referenceReason="OUT_OF_SCOPE_AGE",
            )
            code = "REFERENCE_NOT_APPLICABLE"
        elif not entry:
            result.update(
                referenceStatus="REFERENCE_UNAVAILABLE",
                referenceReason="MISSING_REFERENCE_FILE",
            )
            code = "REFERENCE_UNAVAILABLE"
        elif entry["status"] != "VERIFIED":
            result.update(
                referenceStatus="REFERENCE_UNVERIFIED",
                referenceReason="REFERENCE_NOT_VERIFIED",
            )
            code = "REFERENCE_UNVERIFIED"
        else:
            match = None
            for table in tables:
                if (
                    table["indicator"] != ("length" if metric == "height" else metric)
                    or table["sex"] != profile["gender"]
                    or (period and table["table_interval_months"] != period)
                ):
                    continue
                for row in table["rows"]:
                    if a["measured_on"] == anchor(
                        profile["date_of_birth"], row["start"], row["start_unit"]
                    ) and b["measured_on"] == anchor(
                        profile["date_of_birth"], row["end"], row["end_unit"]
                    ):
                        match = (table, row)
                        break
            if not match:
                result.update(
                    referenceStatus="NO_EXACT_REFERENCE",
                    referenceReason="NO_MATCHING_INTERVAL",
                )
                code = "ACTUAL_ONLY"
            else:
                table, row = match
                code = "REFERENCE_MATCHED"
                source = {
                    "datasetId": table["path"],
                    "sha256": table["sha256"],
                    "sourceUrl": table["source_download_url"]
                    or table["source_page_url"],
                    "version": "WHO-2009",
                    "retrievedOn": table.get("date_retrieved") or entry["retrievedOn"],
                    "sex": profile["gender"],
                    "standard": "WHO-2009",
                    "unit": table["unit"],
                    "xType": "interval",
                    "xMin": row["start"],
                    "xMax": row["end"],
                }
                result.update(
                    referenceStatus="REFERENCE_MATCHED",
                    matchedReference={
                        "source": source,
                        "intervalLabel": (
                            f"{row['start']} {row['start_unit']} - "
                            f"{row['end']} {row['end_unit']}"
                        ),
                        "tableIntervalMonths": table["table_interval_months"],
                        "intervalMonths": (
                            row["end"] - row["start"]
                            if row["start_unit"] == row["end_unit"] == "mo"
                            else None
                        ),
                        "startAgeValue": row["start"],
                        "startAgeUnit": (
                            "weeks" if row["start_unit"] == "wks" else "months"
                        ),
                        "endAgeValue": row["end"],
                        "endAgeUnit": "weeks" if row["end_unit"] == "wks" else "months",
                        "sdValues": row["sdValues"],
                    },
                )
                # Weight method has shifted LMS and linear tails; cm tables remain gated.
                if metric != "weight":
                    try:
                        l, m, s = row["l"], row["m"], row["s"]
                        z = (
                            (
                                ((delta / m) ** l - 1) / (l * s)
                                if l
                                else math.log(delta / m) / s
                            )
                            if delta > 0
                            else None
                        )
                        # Only the central positive LMS branch is enabled; zero/negative/tails remain gated.
                        if z is None or not math.isfinite(z) or abs(z) > 2:
                            result.update(
                                zScoreStatus="UNAVAILABLE",
                                zScoreReason="METHOD_NOT_VERIFIED",
                            )
                        else:
                            result.update(zScoreStatus="READY", zScore=z)
                    except (ValueError, ZeroDivisionError, OverflowError, TypeError):
                        result.update(
                            zScoreStatus="UNAVAILABLE",
                            zScoreReason="METHOD_NOT_VERIFIED",
                        )
                else:
                    try:
                        l, m, s, d = row["l"], row["m"], row["s"], row["shift"]

                        def q(k):
                            return (
                                m
                                * ((1 + l * s * k) ** (1 / l) if l else math.exp(s * k))
                                - d
                            )

                        if delta < q(-3):
                            z = -3 + (delta - q(-3)) / (q(-2) - q(-3))
                        elif delta > q(3):
                            z = 3 + (delta - q(3)) / (q(3) - q(2))
                        else:
                            z = (
                                (((delta + d) / m) ** l - 1) / (l * s)
                                if l
                                else math.log((delta + d) / m) / s
                            )
                        if not math.isfinite(z):
                            raise ValueError()
                        result.update(zScoreStatus="READY", zScore=z)
                    except (ValueError, ZeroDivisionError, OverflowError, TypeError):
                        result.update(
                            zScoreStatus="UNAVAILABLE",
                            zScoreReason="TRANSFORM_DOMAIN_ERROR",
                        )
                if result["zScoreStatus"] == "UNAVAILABLE":
                    result["zScoreContent"] = content.render(
                        "VELOCITY_ZSCORE",
                        "ALL_SUPPORTED_VELOCITY",
                        result["zScoreReason"],
                    )
    values = {
        "start_date": str(a["measured_on"]),
        "end_date": str(b["measured_on"]),
        "delta_value": delta,
        "delta_unit": result["deltaUnit"],
        "rate_per_month": rate,
        "rate_unit": result["rateUnit"],
        "interval_label": (
            result["matchedReference"]["intervalLabel"]
            if result["matchedReference"]
            else None
        ),
    }
    result["content"] = content.render(
        "VELOCITY", "ALL_SUPPORTED_VELOCITY", code, values
    )
    if b["measured_on"] > ev.add_months(profile["date_of_birth"], 24):
        result["content"] = None
    return result


def compare_who_increments(intervals, period):
    """Compare full-interval gains across adjacent, equal WHO periods."""
    eligible = sorted((i for i in intervals
        if i['calculationStatus'] == 'READY'
        and i['referenceStatus'] == 'REFERENCE_MATCHED'
        and (i.get('matchedReference') or {}).get('intervalMonths') == period
        and i.get('deltaValue') is not None),
        key=lambda i: (i['to']['measuredOn'], i['from']['measuredOn']))
    if not eligible:
        return None
    current = eligible[-1]
    previous = next((i for i in reversed(eligible[:-1])
        if i['to']['measuredOn'] == current['from']['measuredOn']
        and i['to']['measurementId'] == current['from']['measurementId']
        and i['deltaUnit'] == current['deltaUnit']), None)
    if previous is None:
        return None
    return {
        'previousIntervalId': previous['intervalId'],
        'currentIntervalId': current['intervalId'],
        'intervalMonths': period,
        'previousIncrement': previous['deltaValue'],
        'currentIncrement': current['deltaValue'],
        'incrementDifference': round(current['deltaValue'] - previous['deltaValue'], 6),
        'unit': current['deltaUnit'],
    }


def build(state, metric, mode="actual", period=None):
    if metric not in service.METRICS[:3]:
        raise GrowthError(422, "INVALID_METRIC")
    if (
        mode not in ("actual", "who")
        or (
            mode == "who"
            and (period not in (1, 2, 3, 4, 6) or (period == 1 and metric != "weight"))
        )
        or (mode == "actual" and period is not None)
    ):
        raise GrowthError(
            422,
            "INVALID_VALUE",
            {"intervalMonths": "Choose a supported WHO period only in who mode"},
        )
    tables, entry = reference.velocity_tables()
    rows = [r for r in state["rows"] if r["metric"] == metric]
    actual = [
        make_interval(state["profile"], a, b, metric, tables, entry)
        for a, b in zip(rows, rows[1:])
        if service.in_scope(state, b["measured_on"])
    ]
    who = []
    if mode == "who" and entry and entry["status"] == "VERIFIED":
        by_day = {r["measured_on"]: r for r in rows}
        for table in tables:
            if (
                table["indicator"] != ("length" if metric == "height" else metric)
                or table["sex"] != state["profile"]["gender"]
                or table["table_interval_months"] != period
            ):
                continue
            for interval in table["rows"]:
                start = anchor(
                    state["profile"]["date_of_birth"],
                    interval["start"],
                    interval["start_unit"],
                )
                end = anchor(
                    state["profile"]["date_of_birth"],
                    interval["end"],
                    interval["end_unit"],
                )
                if start in by_day and end in by_day and service.in_scope(state, end):
                    item = make_interval(
                        state["profile"],
                        by_day[start],
                        by_day[end],
                        metric,
                        tables,
                        entry,
                        period,
                    )
                    if item["referenceStatus"] == "REFERENCE_MATCHED":
                        who.append(item)
    latest = actual[-1] if actual else None
    status = latest["calculationStatus"] if latest else "INSUFFICIENT_MEASUREMENTS"
    ref_status = latest["referenceStatus"] if latest else "NOT_REQUESTED"
    reason = latest["referenceReason"] if latest else None
    selected = who[-1] if who else None
    if mode == "who" and status == "READY":
        ref_status = (
            selected["referenceStatus"]
            if selected
            else (
                "REFERENCE_NOT_APPLICABLE"
                if rows[-1]["measured_on"]
                > ev.add_months(state["profile"]["date_of_birth"], 24)
                else (
                    "REFERENCE_UNAVAILABLE"
                    if not entry
                    else (
                        "REFERENCE_UNVERIFIED"
                        if entry["status"] != "VERIFIED"
                        else "NO_EXACT_REFERENCE"
                    )
                )
            )
        )
        reason = (
            None
            if selected
            else {
                "REFERENCE_NOT_APPLICABLE": "OUT_OF_SCOPE_AGE",
                "REFERENCE_UNAVAILABLE": "MISSING_REFERENCE_FILE",
                "REFERENCE_UNVERIFIED": "REFERENCE_NOT_VERIFIED",
                "NO_EXACT_REFERENCE": "NO_MATCHING_INTERVAL",
            }[ref_status]
        )
    trend = None
    recording_only = bool(rows) and rows[-1]["measured_on"] > ev.add_months(
        state["profile"]["date_of_birth"], 24
    )
    if recording_only:
        selected = None
        ref_status = "REFERENCE_NOT_APPLICABLE"
        reason = "OUT_OF_SCOPE_AGE"
    if mode == "actual" and len(actual) >= 2 and not recording_only:
        a, b = actual[-2:]
        if (
            a["calculationStatus"] == b["calculationStatus"] == "READY"
            and a["to"]["measurementId"] == b["from"]["measurementId"]
            and (a["from"]["normalization"] or {}).get("basis")
            == (b["from"]["normalization"] or {}).get("basis")
        ):
            delta = b["ratePerMonth"] - a["ratePerMonth"]
            code = (
                "TREND_FASTER"
                if delta > 0
                else "TREND_SLOWER" if delta < 0 else "TREND_UNCHANGED"
            )
            trend = {
                "code": code,
                "previousIntervalId": a["intervalId"],
                "currentIntervalId": b["intervalId"],
                "previousRatePerMonth": a["ratePerMonth"],
                "currentRatePerMonth": b["ratePerMonth"],
                "rateDifference": abs(delta),
                "rateUnit": b["rateUnit"],
                "content": content.render(
                    "VELOCITY_TREND",
                    "ALL_SUPPORTED_VELOCITY",
                    code,
                    {
                        "indicator_name": metric,
                        "rate_difference": abs(delta),
                        "rate_unit": b["rateUnit"],
                    },
                ),
            }
    code = (
        status
        if status != "READY"
        else "ACTUAL_ONLY" if ref_status == "NO_EXACT_REFERENCE" else ref_status
    )
    return {
        **service.common(state),
        "metric": metric,
        "mode": mode,
        "intervalMonths": period,
        "calculationStatus": status,
        "referenceStatus": ref_status,
        "referenceReason": reason,
        "actualIntervals": actual,
        "whoIntervals": who,
        "referenceIntervals": [
            {
                "start": row["start"], "end": row["end"],
                "startUnit": row["start_unit"], "endUnit": row["end_unit"],
                "sdValues": row["sdValues"], "unit": table["unit"],
                "intervalMonths": table["table_interval_months"],
            }
            for table in tables
            if mode == "who" and entry and entry["status"] == "VERIFIED"
            and table["indicator"] == ("length" if metric == "height" else metric)
            and table["sex"] == state["profile"]["gender"]
            and table["table_interval_months"] == period
            for row in table["rows"]
        ],
        "selectedActualIntervalId": latest["intervalId"] if latest else None,
        "selectedWhoIntervalId": selected["intervalId"] if selected else None,
        "trend": trend,
        "incrementComparison": compare_who_increments(who, period) if mode == 'who' and not recording_only else None,
        "content": (
            None if recording_only else selected["content"]
            if selected
            else (
                latest["content"]
                if latest and mode == "actual"
                else content.render("VELOCITY", "ALL_SUPPORTED_VELOCITY", code)
            )
        ),
        "capabilities": service.capabilities(),
    }
