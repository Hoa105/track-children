"""Small parent-facing contract; no trends, causes or personalized treatment."""

from datetime import datetime, time, timezone
from functools import lru_cache
import json
from pathlib import Path
from . import service, repository as repo, evaluation, pairing
from .errors import GrowthError
from app.core.database import transaction

TEXT_PATH = (
    Path(__file__).resolve().parents[3]
    / "data/growth/GROWTH-PARENT-ASSESSMENT-TEXT.vi.json"
)


@lru_cache(maxsize=2)
def _load_parent_text(modified_ns):
    document = json.loads(TEXT_PATH.read_text(encoding="utf-8"))
    if document.get("schemaVersion") != "1":
        raise ValueError("Unsupported parent assessment text schema")
    if not all(isinstance(document.get(key), dict) for key in ("bmi", "head", "visualRanges")):
        raise ValueError("Invalid parent assessment text document")
    ranges = document["visualRanges"]
    scale = ranges.get("scale")
    if (
        not isinstance(scale, dict)
        or not isinstance(scale.get("zMin"), (int, float))
        or not isinstance(scale.get("zMax"), (int, float))
        or scale["zMin"] >= scale["zMax"]
        or not all(isinstance(ranges.get(key), list) and ranges[key] for key in ("bmi", "head"))
    ):
        raise ValueError("Invalid visual range configuration")
    for section in ("bmi", "head"):
        for item in ranges[section]:
            if (
                not isinstance(item, dict)
                or not all(
                    key in item
                    for key in (
                        "code",
                        "label",
                        "zMin",
                        "zMinInclusive",
                        "zMax",
                        "zMaxInclusive",
                        "color",
                    )
                )
                or not isinstance(item["code"], str)
                or not isinstance(item["label"], str)
                or not isinstance(item["color"], str)
                or not isinstance(item["zMinInclusive"], bool)
                or not isinstance(item["zMaxInclusive"], bool)
            ):
                raise ValueError("Invalid visual range entry")
    for section in ("bmi", "head"):
        for entry in document[section].values():
            if not isinstance(entry, dict) or not all(
                isinstance(entry.get(key), str) and entry[key]
                for key in ("summary", "action")
            ):
                raise ValueError("Invalid parent assessment text entry")
    return document


def load_parent_text():
    """Reload parent-facing text when the JSON file changes."""
    return _load_parent_text(TEXT_PATH.stat().st_mtime_ns)


REASON_TEXT = {
    "MISSING_PAIRED_MEASUREMENT": {
        "summary": "Cần thêm số đo chiều cao cùng ngày (hoặc cách 1 ngày) để tính chỉ số thể trạng (BMI).",
        "action": "Ghi thêm chiều cao của bé để hoàn thành đánh giá.",
    },
    "PRETERM_REQUIRES_REVIEW": {
        "summary": "Bé sinh non dưới 37 tuần tuổi thai; cần theo dõi theo tuổi hiệu chỉnh hoặc tư vấn cán bộ y tế.",
        "action": "Trao đổi với bác sĩ hoặc nhân viên y tế để đánh giá theo chuẩn tuổi hiệu chỉnh.",
    },
    "OUT_OF_SCOPE_AGE": {
        "summary": "Độ tuổi của bé nằm ngoài phạm vi áp dụng của chuẩn tăng trưởng WHO 0–5 tuổi.",
        "action": "Tham khảo ý kiến chuyên gia y tế cho độ tuổi của bé.",
    },
    "INVALID_MEASURE_POSITION": {
        "summary": "Tư thế đo chiều cao/chiều dài chưa phù hợp với độ tuổi của bé.",
        "action": "Kiểm tra lại tư thế đo (nằm cho trẻ dưới 2 tuổi, đứng cho trẻ từ 2 tuổi).",
    },
    "WHO_OUT_OF_RANGE": {
        "summary": "Số đo nằm ngoài khoảng tính toán của chuẩn WHO.",
        "action": "Kiểm tra lại số đo đã nhập.",
    },
    "WHO_FLAGGED": {
        "summary": "Số đo có dấu hiệu bất thường so với lứa tuổi.",
        "action": "Kiểm tra lại số liệu đã ghi hoặc tham khảo cán bộ y tế.",
    },
    "CALCULATION_UNAVAILABLE": {
        "summary": "Hệ thống tạm thời chưa tính được kết quả.",
        "action": "Vui lòng thử lại sau.",
    },
}


def public_result(profile, rows, weight=None, height=None, head=None, assessment=None):
    parent_text = load_parent_text()
    fallback = parent_text.get(
        "fallback",
        {
            "summary": "Chưa tính được nhận xét. Vui lòng thử lại sau.",
            "action": "Kiểm tra thông tin đã ghi hoặc trao đổi với nhân viên y tế.",
        },
    )
    sources = [service.measurement(r, profile) for r in (weight, height, head) if r]
    indicator = "hcfa" if head else "bmifa"
    primary = head or weight
    if primary is None:
        return None
    a = assessment or {"status": "NOT_ASSESSABLE", "reason": "MISSING_PAIRED_MEASUREMENT"}
    if profile.get("gestational_weeks") is not None and profile["gestational_weeks"] < 37:
        a = {"status": "NOT_ASSESSABLE", "reason": "PRETERM_REQUIRES_REVIEW"}
    norm = evaluation.normalized((weight["measured_on"] - profile["date_of_birth"]).days,
                                 {"height": height}) if weight and height else None
    bmi = float(weight["value"]) / (norm["normalizedLenheiCm"] / 100) ** 2 if norm and norm["status"] == "READY" else None
    code, score = a.get("classificationCode"), a.get("zScore")
    text = parent_text["head" if head else "bmi"].get(code) if a["status"] == "READY" else None
    ready = text is not None
    reason = a.get("reason")
    reason_info = REASON_TEXT.get(reason, {})
    fallback_summary = parent_text.get("status", {}).get(reason) or reason_info.get("summary") or fallback["summary"]
    fallback_action = reason_info.get("action") or fallback["action"]
    return {
        "status": "READY" if ready else a["status"] if a["status"] != "READY" else "NOT_ASSESSABLE", "reason": a.get("reason"),
        "indicator": indicator, "classificationCode": code if ready else None,
        "summary": text["summary"] if ready else fallback_summary,
        "action": text["action"] if ready else fallback_action,
        "classificationLabels": (
            {key: value["label"] for key, value in parent_text["bmi"].items()}
            if indicator == "bmifa" else None
        ),
        "visualRanges": parent_text["visualRanges"]["bmi" if indicator == "bmifa" else "head"],
        "visualScale": parent_text["visualRanges"]["scale"],
        "measuredOn": primary["measured_on"], "sources": sources,
        "bmi": bmi, "zScore": score if ready else None,
        "sourceStandard": a.get("sourceStandard"), "normalization": norm,
        "pairingPolicy": pairing.POLICY if weight and height else None,
    }


def assessment(state, kind, selected_id=None):
    if kind not in ("bmi", "head"):
        raise GrowthError(422, "INVALID_METRIC")
    profile, rows = state["profile"], state["rows"]
    selected = next((r for r in rows if str(r["id"]) == str(selected_id)), None) if selected_id else None
    if selected_id and selected is None:
        raise GrowthError(404, "RESOURCE_NOT_FOUND")
    if kind == "head":
        if selected and selected["metric"] != "head_circumference":
            raise GrowthError(422, "INVALID_METRIC")
        head = selected or max((r for r in rows if r["metric"] == "head_circumference"), key=lambda r: r["measured_on"], default=None)
        current = public_result(profile, rows, head=head, assessment=score_pair(profile, {"head_circumference": head}, "hcfa")) if head else None
        return {**service.common(state), "current": current, "previous": None, "missingMetric": "head_circumference" if not head else None}
    if selected:
        if selected["metric"] != "weight":
            raise GrowthError(422, "INVALID_METRIC")
        anchor, weight = selected, selected
        height = pairing.nearest(weight, [r for r in rows if r["metric"] == "height"])
    else:
        anchor, weight, height = pairing.latest_pair(rows)
    current = public_result(profile, rows, weight=weight, height=height,
        assessment=score_pair(profile, {"weight": weight, "height": height}, "bmifa")) if weight and height else None
    previous = None
    if current is None and selected is None:
        for w in sorted((r for r in rows if r["metric"] == "weight"), key=lambda r: r["measured_on"], reverse=True):
            h = pairing.nearest(w, [r for r in rows if r["metric"] == "height"])
            if h:
                previous = public_result(profile, rows, weight=w, height=h, assessment=score_pair(profile, {"weight": w, "height": h}, "bmifa"))
                break
    return {**service.common(state), "current": current, "previous": previous,
            "anchor": service.measurement(anchor, profile) if anchor else None,
            "missingMetric": ("weight" if anchor["metric"] == "height" else "height") if anchor and not current else None}


def score_pair(profile, values, indicator):
    return evaluation.score_pair(profile, values, indicator)


def read_assessment(child_id, user_id, kind, selected_id=None):
    profile, rows, _ = repo.snapshot(child_id, user_id)
    state = {"profile": profile, "rows": rows,
             "meta": {"schemaVersion": "1", "pairingPolicy": pairing.POLICY},
             "scope": {"startOn": profile["date_of_birth"], "endBefore": service.today()}}
    return assessment(state, kind, selected_id)


def snapshot(child_id, user_id):
    profile, rows, _ = repo.snapshot(child_id, user_id)
    anchor, w, h = pairing.latest_pair(rows)
    return {"meta": {"schemaVersion": "1"}, "child": service.public_child(profile),
            "measurements": [service.measurement(r, profile) for r in rows],
            "pairing": {"policy": pairing.POLICY, "ready": bool(w and h),
                        "missingMetric": ("weight" if anchor and anchor["metric"] == "height" else "height") if not (w and h) else None}}


def write(child_id, user_id, body, measurement_id=None):
    with transaction() as db:
        profile = repo.child(db, child_id, user_id, edit=True, lock=True)
        service.validate_day(body.measuredOn, profile["date_of_birth"])
        old = None
        if measurement_id:
            old = db.execute("SELECT * FROM growth.measurements WHERE id=%s AND child_id=%s AND deleted_at IS NULL", (measurement_id, child_id)).fetchone()
            if old is None:
                raise GrowthError(404, "RESOURCE_NOT_FOUND")
        metric = old["metric"] if old else body.metric
        previous_latest = db.execute("SELECT max(measured_on) AS latest FROM growth.measurements WHERE child_id=%s AND metric=%s AND deleted_at IS NULL", (child_id, metric)).fetchone()["latest"]
        if (metric == "height") != (body.measurePosition is not None):
            raise GrowthError(422, "INVALID_MEASURE_POSITION")
        duplicate = db.execute("SELECT id FROM growth.measurements WHERE child_id=%s AND metric=%s AND measured_on=%s AND deleted_at IS NULL", (child_id, metric, body.measuredOn)).fetchone()
        if duplicate and (old is None or duplicate["id"] != old["id"]):
            raise GrowthError(409, "MEASUREMENT_EXISTS", {"measurementId": str(duplicate["id"])})
        stamp = datetime.combine(body.measuredOn, time(), service.TZ)
        if old:
            result = db.execute("UPDATE growth.measurements SET value=%s, measured_on=%s, measured_at=%s, measure_position=%s, updated_at=now() WHERE id=%s RETURNING *", (body.value, body.measuredOn, stamp, body.measurePosition, measurement_id)).fetchone()
        else:
            result = db.execute("INSERT INTO growth.measurements(child_id,metric,value,measured_on,measured_at,measure_position,created_by) VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING *", (child_id, metric, body.value, body.measuredOn, stamp, body.measurePosition, user_id)).fetchone()
        # A newly preferred neighbour can replace an existing pair too.
        db.execute("DELETE FROM growth.evaluations WHERE child_id=%s", (child_id,))
        next_latest = db.execute("SELECT max(measured_on) AS latest FROM growth.measurements WHERE child_id=%s AND metric=%s AND deleted_at IS NULL", (child_id, metric)).fetchone()["latest"]
        if previous_latest != next_latest:
            db.execute("UPDATE growth.reminder_settings SET snoozed_until=NULL WHERE child_id=%s AND metric=%s", (child_id, metric))
    # Never invoke the R engine after a committed write.
    return {"measurementSaved": True, "measurement": service.measurement(result, profile)}
