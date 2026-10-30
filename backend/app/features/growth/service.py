from collections import defaultdict
from datetime import date, datetime, time as day_time, timedelta, timezone
from decimal import Decimal
import hashlib
import json
import time

from app.core.database import transaction
from . import anthro_client, content, evaluation as ev, reference, repository as repo
from .errors import GrowthError

TZ = timezone(timedelta(hours=7))
METRICS = ("weight", "height", "head_circumference", "bmi")
CHARTS = {
    "wfa": "WFA_AGE",
    "lhfa": "LHFA_AGE",
    "hcfa": "HCFA_AGE",
    "bmifa": "BMIFA_AGE",
    "wfl": "WFL_LENGTH",
    "wfh": "WFH_HEIGHT",
}
INDICATOR = {
    "weight": "wfa",
    "height": "lhfa",
    "head_circumference": "hcfa",
    "bmi": "bmifa",
}


def today():
    return datetime.now(TZ).date()


def validate_day(day, birth):
    if day < birth or day > today():
        raise GrowthError(
            422, "INVALID_DATE", {"measuredOn": "Must be between birth date and today"}
        )
    if day >= ev.add_months(birth, 60):
        raise GrowthError(422, "OUT_OF_SCOPE_AGE")


def public_child(profile):
    return {
        "id": str(profile["id"]),
        "fullName": profile["full_name"],
        "dateOfBirth": profile["date_of_birth"],
        "sex": profile["gender"],
        "growthAccess": profile["growth_access"],
    }


def measurement(row, profile):
    return {
        "id": str(row["id"]),
        "metric": row["metric"],
        "value": float(row["value"]),
        "unit": "kg" if row["metric"] == "weight" else "cm",
        "measuredOn": row["measured_on"],
        "measuredAt": row["measured_at"],
        "ageDays": (row["measured_on"] - profile["date_of_birth"]).days,
        "measurePosition": row["measure_position"],
        "note": row["note"],
        "createdAt": row["created_at"],
        "updatedAt": row["updated_at"],
    }


def sample(profile, day, values, assessments, metric):
    primary = values.get("weight" if metric == "bmi" else metric)
    if not primary:
        return None
    age = (day - profile["date_of_birth"]).days
    norm = ev.normalized(age, values) if metric in ("height", "bmi") else None
    if metric == "bmi" and (not norm or norm["status"] != "READY"):
        return None
    value = float(primary["value"])
    if metric == "height" and norm and norm["normalizedLenheiCm"]:
        value = norm["normalizedLenheiCm"]
    if metric == "bmi":
        value = value / (norm["normalizedLenheiCm"] / 100) ** 2
    paired = values.get("height") if metric == "bmi" else None
    chosen = [
        a
        for i, a in assessments.items()
        if i == INDICATOR[metric]
        or (metric == "weight" and i in ("bmifa", "wfl", "wfh"))
    ]
    return {
        "measurementId": str(primary["id"]),
        "pairedMeasurementId": str(paired["id"]) if paired else None,
        "measuredOn": day,
        "ageDays": age,
        "ageLabel": f"{age} ngày",
        "value": value,
        "unit": "kg" if metric == "weight" else "kg/m2" if metric == "bmi" else "cm",
        "raw": {
            "weightKg": (
                float(values["weight"]["value"]) if "weight" in values else None
            ),
            "heightCm": (
                float(values["height"]["value"]) if "height" in values else None
            ),
            "headCircumferenceCm": (
                float(values["head_circumference"]["value"])
                if "head_circumference" in values
                else None
            ),
            "measurePosition": (
                values["height"]["measure_position"] if "height" in values else None
            ),
        },
        "normalization": norm,
        "assessments": chosen,
    }


def capabilities():
    _, entry = reference.velocity_tables()
    return {
        "metrics": list(METRICS),
        "velocity": [
            {
                "metric": m,
                "actualSupported": True,
                "whoIntervalMonths": [1, 2, 3, 4, 6] if m == "weight" else [2, 3, 4, 6],
                "referenceImportStatus": entry["status"] if entry else None,
            }
            for m in METRICS[:3]
        ],
        "bmiVelocitySupported": False,
        "whoVelocityEndAgeMonthsExclusive": 24,
        "maxAgeMonthsExclusive": 60,
    }


def read(child_id, user_id, start=None, end=None, selected=None):
    deadline = time.monotonic() + 15
    for attempt in range(2):
        profile, rows, cached = repo.snapshot(child_id, user_id)
        if start and end and start >= end:
            raise GrowthError(
                422, "INVALID_DATE", {"endBefore": "Must be after startOn"}
            )
        scope_end = min(
            today() + timedelta(days=1), ev.add_months(profile["date_of_birth"], 60)
        )
        lower = min(
            max(start or profile["date_of_birth"], profile["date_of_birth"]), scope_end
        )
        upper = min(max(end or scope_end, profile["date_of_birth"]), scope_end)
        upper = max(lower, upper)
        if selected and not any(str(r["id"]) == str(selected) for r in rows):
            raise GrowthError(404, "RESOURCE_NOT_FOUND")
        days, outputs, computed = ev.evaluate(
            profile, rows, cached, selected, budget=deadline - time.monotonic()
        )
        fingerprint = ev.digest(profile, rows)
        with transaction() as db:
            current = repo.child(db, child_id, user_id, lock=True)
            active = db.execute(
                "SELECT * FROM growth.measurements WHERE child_id=%s AND deleted_at IS NULL ORDER BY measured_on,metric",
                (child_id,),
            ).fetchall()
            if ev.digest(current, active) != fingerprint:
                continue
            tags = [
                a["cacheTag"]
                for values in outputs.values()
                for a in values.values()
                if a["cacheTag"]
            ]
            db.execute(
                "DELETE FROM growth.evaluations WHERE child_id=%s AND NOT(standard_version=ANY(%s::text[]))",
                (child_id, tags),
            )
            for tag, a in computed:
                db.execute(
                    """INSERT INTO growth.evaluations(child_id,measurement_id,paired_measurement_id,indicator,z_score,classification,standard_version)
                    VALUES (%s,%s,%s,%s,%s,%s,%s) ON CONFLICT(measurement_id,indicator) DO UPDATE SET
                    paired_measurement_id=excluded.paired_measurement_id,z_score=excluded.z_score,
                    classification=excluded.classification,standard_version=excluded.standard_version,created_at=now()""",
                    (
                        child_id,
                        a["measurementId"],
                        a["pairedMeasurementId"],
                        a["indicator"],
                        a["zScore"],
                        a["classificationCode"],
                        tag,
                    ),
                )
        return {
            "profile": profile,
            "rows": rows,
            "days": days,
            "assessments": outputs,
            "scope": {"startOn": lower, "endBefore": upper},
            "meta": {
                "schemaVersion": "1",
                "snapshotToken": fingerprint,
                "generatedAt": datetime.now(timezone.utc),
                "engineBundleId": anthro_client.bundle(),
                "contentVersion": content.VERSION,
                "calculationPending": any(
                    a["status"] == "PENDING_CALCULATION"
                    for d in outputs.values()
                    for a in d.values()
                ),
            },
        }
    raise GrowthError(503, "DATABASE_UNAVAILABLE")


def common(state):
    return {
        "meta": state["meta"],
        "child": public_child(state["profile"]),
        "scope": state["scope"],
    }


def in_scope(state, day):
    return state["scope"]["startOn"] <= day < state["scope"]["endBefore"]


def overview(state):
    cards = []
    for metric in METRICS:
        samples = [
            sample(state["profile"], d, v, state["assessments"][d], metric)
            for d, v in sorted(state["days"].items())
        ]
        samples = [s for s in samples if s]
        cards.append(
            {
                "metric": metric,
                "latest": samples[-1] if samples else None,
                "sparkline": [s for s in samples if in_scope(state, s["measuredOn"])],
            }
        )
    return {**common(state), "cards": cards, "capabilities": capabilities()}


def point_key(point, indicator):
    return {
        "measurementId": point["measurementId"],
        "pairedMeasurementId": point["pairedMeasurementId"],
        "indicator": indicator,
    }


def chart(state, indicator, samples, selected=None, view="radius5"):
    points = []
    omitted = []
    profile = state["profile"]
    for source in samples:
        source = dict(source)
        values = state["days"][source["measuredOn"]]
        a = state["assessments"][source["measuredOn"]].get(indicator)
        if not a:
            continue
        norm = (
            ev.normalized(source["ageDays"], values)
            if indicator in ("lhfa", "bmifa", "wfl", "wfh")
            else None
        )
        if indicator in ("lhfa", "bmifa", "wfl", "wfh") and (
            not norm or norm["status"] != "READY"
        ):
            omitted.append(
                {
                    "measurementId": source["measurementId"],
                    "pairedMeasurementId": a["pairedMeasurementId"],
                    "measuredOn": source["measuredOn"],
                    "raw": source["raw"],
                    "reason": norm["reason"] if norm else "MISSING_PAIRED_MEASUREMENT",
                }
            )
            continue
        x = (
            norm["normalizedLenheiCm"]
            if indicator in ("wfl", "wfh")
            else source["ageDays"]
        )
        if indicator in ("wfl", "wfh") and not (
            (45 <= x <= 110) if indicator == "wfl" else (65 <= x <= 120)
        ):
            omitted.append(
                {
                    "measurementId": source["measurementId"],
                    "pairedMeasurementId": a["pairedMeasurementId"],
                    "measuredOn": source["measuredOn"],
                    "raw": source["raw"],
                    "reason": "WHO_OUT_OF_RANGE",
                }
            )
            continue
        basis = norm["basis"] if norm else None
        source.update(normalization=norm, pairedMeasurementId=a["pairedMeasurementId"])
        points.append(
            {
                **source,
                "x": x,
                "y": source["value"],
                "segmentId": f'{indicator}-{basis or "age"}',
                "assessment": a,
            }
        )
    xmin, xmax = (
        state["scope"]["startOn"] - profile["date_of_birth"],
        state["scope"]["endBefore"] - profile["date_of_birth"],
    )
    xmin, xmax = xmin.days, max(xmin.days, xmax.days - 1)
    if indicator in ("wfl", "wfh"):
        xmin, xmax = (45, 110) if indicator == "wfl" else (65, 120)
        if points and view != "all":
            radius = 5 if view == "radius5" else 10
            center = points[-1]["x"]
            xmin, xmax = max(xmin, center - radius), min(xmax, center + radius)
        points = [p for p in points if xmin <= p["x"] <= xmax]
    ref = reference.curves(indicator, profile["gender"], xmin, xmax)
    chosen = next(
        (p for p in points if p["measurementId"] == str(selected)),
        points[-1] if points else None,
    )
    unit = (
        "kg"
        if indicator in ("wfa", "wfl", "wfh")
        else "kg/m2" if indicator == "bmifa" else "cm"
    )
    return {
        "chartId": CHARTS[indicator],
        "indicator": indicator,
        "xAxis": {
            "type": (
                "length_cm"
                if indicator == "wfl"
                else "height_cm" if indicator == "wfh" else "age_days"
            ),
            "unit": "cm" if indicator in ("wfl", "wfh") else "days",
            "displayUnit": "cm" if indicator in ("wfl", "wfh") else "calendar_months",
            "min": xmin,
            "max": xmax,
        },
        "yAxis": {
            "type": (
                "weight"
                if unit == "kg"
                else (
                    "bmi"
                    if unit == "kg/m2"
                    else "head_circumference" if indicator == "hcfa" else "length"
                )
            ),
            "unit": unit,
            "displayUnit": unit,
            "min": None,
            "max": None,
        },
        "reference": ref,
        "childPoints": points,
        "omittedPoints": omitted,
        "selectedPointKey": point_key(chosen, indicator) if chosen else None,
        "evidence": [],
        "warnings": (
            []
            if ref["importStatus"] == "VERIFIED"
            else [
                {
                    "scope": "reference",
                    "status": (
                        "REFERENCE_UNAVAILABLE"
                        if ref["importStatus"] is None
                        else "REFERENCE_UNVERIFIED"
                    ),
                    "reason": ref["reason"],
                }
            ]
        ),
    }


def detail(state, metric, selected=None, branch=None, view="radius5"):
    if metric not in METRICS:
        raise GrowthError(422, "INVALID_METRIC")
    rows = [
        r
        for r in state["rows"]
        if in_scope(state, r["measured_on"])
        and r["metric"]
        in (("weight", "height") if metric in ("weight", "bmi") else (metric,))
    ]
    primary = "weight" if metric == "bmi" else metric
    if selected and not any(
        str(r["id"]) == str(selected) and r["metric"] == primary for r in rows
    ):
        raise GrowthError(
            422,
            "INVALID_VALUE",
            {"selectedMeasurementId": "Outside requested metric or range"},
        )
    samples = [
        sample(state["profile"], d, v, state["assessments"][d], metric)
        for d, v in sorted(state["days"].items())
        if in_scope(state, d)
    ]
    samples = [s for s in samples if s]
    charts = [chart(state, INDICATOR[metric], samples, selected)]
    if metric == "weight":
        pairs = [s for s in samples if s["raw"]["heightCm"] is not None]
        age = (
            pairs[-1]["ageDays"]
            if pairs
            else (today() - state["profile"]["date_of_birth"]).days
        )
        branch = branch or ("wfl" if age < 731 else "wfh")
        charts.append(chart(state, branch, samples, selected, view))
    return {
        **common(state),
        "metric": metric,
        "measurements": [measurement(r, state["profile"]) for r in rows],
        "samples": samples,
        "charts": charts,
        "selectedPointKey": charts[0]["selectedPointKey"],
        "capabilities": capabilities(),
    }


def day_result(state, day):
    validate_day(day, state["profile"]["date_of_birth"])
    values = state["days"].get(day, {})
    return {
        "meta": state["meta"],
        "child": public_child(state["profile"]),
        "measuredOn": day,
        "measurements": [measurement(r, state["profile"]) for r in values.values()],
        "bmi": sample(
            state["profile"], day, values, state["assessments"].get(day, {}), "bmi"
        ),
        "assessments": list(state["assessments"].get(day, {}).values()),
    }


def save(child_id, user_id, day, body):
    changed = []
    with transaction() as db:
        profile = repo.child(db, child_id, user_id, edit=True, lock=True)
        validate_day(day, profile["date_of_birth"])
        if body.measuredAt and (
            body.measuredAt.astimezone(TZ).date() != day
            or body.measuredAt > datetime.now(timezone.utc)
        ):
            raise GrowthError(
                422,
                "INVALID_DATE",
                {"measuredAt": "Must match business day and not be future"},
            )
        for field, metric in [
            ("weightKg", "weight"),
            ("height", "height"),
            ("headCircumferenceCm", "head_circumference"),
        ]:
            if field not in body.model_fields_set:
                continue
            item = getattr(body, field)
            value = item.value if metric == "height" else item
            pos = item.measurePosition if metric == "height" else None
            old = db.execute(
                "SELECT * FROM growth.measurements WHERE child_id=%s AND metric=%s AND measured_on=%s AND deleted_at IS NULL",
                (child_id, metric, day),
            ).fetchone()
            note = (
                body.note
                if "note" in body.model_fields_set
                else old["note"] if old else None
            )
            timestamp = body.measuredAt or (
                old["measured_at"] if old else datetime.combine(day, day_time(), TZ)
            )
            if old and (
                old["value"],
                old["measure_position"],
                old["note"],
                old["measured_at"],
            ) == (value, pos, note, timestamp):
                continue
            record = db.execute(
                """INSERT INTO growth.measurements(child_id,metric,value,measure_position,measured_at,measured_on,note,created_by)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT(child_id,metric,measured_on) WHERE deleted_at IS NULL
                DO UPDATE SET value=excluded.value,measure_position=excluded.measure_position,
                measured_at=excluded.measured_at,note=excluded.note,updated_at=now() RETURNING id""",
                (child_id, metric, value, pos, timestamp, day, note, user_id),
            ).fetchone()
            if not old or old["value"] != value or old["measure_position"] != pos:
                repo.invalidate(db, [record["id"]])
            changed.append(metric)
    # A committed save must never be reported as a failed write because R failed.
    state = read(child_id, user_id)
    return {
        "measurementSaved": True,
        "changedMetrics": changed,
        "day": day_result(state, day),
    }


def delete(child_id, user_id, measurement_id):
    with transaction() as db:
        repo.child(db, child_id, user_id, edit=True, lock=True)
        row = db.execute(
            "SELECT id FROM growth.measurements WHERE id=%s AND child_id=%s",
            (measurement_id, child_id),
        ).fetchone()
        if not row:
            raise GrowthError(404, "RESOURCE_NOT_FOUND")
        db.execute(
            "UPDATE growth.measurements SET deleted_at=coalesce(deleted_at,now()),updated_at=now() WHERE id=%s",
            (measurement_id,),
        )
        repo.invalidate(db, [measurement_id])
