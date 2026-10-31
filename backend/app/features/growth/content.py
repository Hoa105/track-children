"""Immutable, exact-key classification and template lookup."""

import csv
import hashlib
import json
from pathlib import Path
import re

BACKEND = Path(__file__).resolve().parents[3]
DATA = BACKEND / "data/growth"
APPROVAL = json.loads((DATA / "approval.json").read_text(encoding="utf-8"))
for filename, expected_hash in APPROVAL["files"].items():
    if hashlib.sha256((DATA / filename).read_bytes()).hexdigest() != expected_hash:
        raise ValueError("Growth content approval fingerprint mismatch")


def load(name):
    with (DATA / name).open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


RULES = load("GROWTH-WHO-CLASSIFICATION-MAP.csv")
OVERVIEWS = {(r['indicator'], r['classification_code']): r
             for r in load('GROWTH-OVERVIEW-TEMPLATES.csv')}
COMMENTS = {
    (r["mapping_type"], r["indicator"], r["code"]): r
    for r in load("GROWTH-COMMENT-MAPPING.csv")
}
ADVICE = {
    (r["mapping_type"], r["applies_to"], r["condition_code"]): r
    for r in load("GROWTH-ADVICE-MAPPING.csv")
}
VERSION = hashlib.sha256(
    b"".join(p.read_bytes() for p in sorted(DATA.glob("*.csv")))
).hexdigest()
RULE_HASH = hashlib.sha256(
    (DATA / "GROWTH-WHO-CLASSIFICATION-MAP.csv").read_bytes()
).hexdigest()
FALLBACK = "Nội dung giải thích hiện chưa sẵn có."


def classify(indicator, z, approved=True):
    for row in RULES:
        if row["indicator"] != indicator.upper():
            continue
        lo, hi = row["z_min"], row["z_max"]
        if lo and (
            z < float(lo) or (z == float(lo) and row["z_min_inclusive"] != "true")
        ):
            continue
        if hi and (
            z > float(hi) or (z == float(hi) and row["z_max_inclusive"] != "true")
        ):
            continue
        return (
            row["classification_code"]
            if not approved or row["review_status"] == "APPROVED"
            else None
        )
    return None


def block(kind, scope, code, values, advice=False):
    row = (ADVICE if advice else COMMENTS).get((kind, scope, code))
    status = (
        "MAPPING_NOT_FOUND"
        if row is None
        else "MAPPING_NOT_APPROVED" if row["review_status"] != "APPROVED" else "READY"
    )
    text = FALLBACK
    if status == "READY":
        template = row["advice_template" if advice else "summary_template"]
        fields = re.findall(r"\{\{([a-z_]+)\}\}", template)
        if any(values.get(key) is None for key in fields):
            status = "TEMPLATE_DATA_MISSING"
        else:
            text = re.sub(
                r"\{\{([a-z_]+)\}\}",
                lambda match: (
                    f"{values[match[1]]:.2f}".rstrip("0").rstrip(".").replace(".", ",")
                    if isinstance(values[match[1]], float)
                    else str(values[match[1]])
                ),
                template,
            )
    return {
        "status": status,
        "mappingType": kind,
        "code": code,
        "adviceCode": row.get("advice_code") if row else None,
        "text": text,
    }


def render(kind, scope, code, values=None):
    values = values or {}
    return {
        "comment": block(kind, scope, code, values),
        "overview": {
            "status": "READY" if kind == "ATTAINED" and (scope, code) in OVERVIEWS
                and OVERVIEWS[scope, code]['review_status'] == 'APPROVED' else "NOT_AVAILABLE",
            "text": OVERVIEWS.get((scope, code), {}).get('overview_template', '') if kind == "ATTAINED" else '',
        },
        "advice": [block(kind, scope, code, values, True)],
        "ageContext": [],
    }
