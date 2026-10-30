"""Static, checksum-validated reference data; never a database WHO table."""

from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path

DATA = Path(__file__).resolve().parents[3] / "data/who"


@lru_cache(maxsize=1)
def datasets():
    manifest = json.loads((DATA / "manifest.json").read_text(encoding="utf-8"))
    result = {}
    for entry in manifest["files"]:
        path = (DATA / entry["path"]).resolve()
        if DATA.resolve() not in path.parents:
            raise ValueError("Reference path escaped data root")
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError("Reference checksum mismatch")
        result[entry["kind"]] = (json.loads(path.read_text(encoding="utf-8")), entry)
    return result


def quantile(row, k):
    l, m, s = (float(row[key]) for key in ("l", "m", "s"))
    base = 1 + l * s * k
    if l and base <= 0:
        return None
    return m * (base ** (1 / l) if l else math.exp(s * k))


def curves(indicator, sex, x_min=None, x_max=None):
    missing = {
        "importStatus": None,
        "reason": "MISSING_REFERENCE_FILE",
        "standard": "WHO-2006",
        "sources": [],
        "segments": [],
    }
    try:
        data, entry = datasets()["attained"]
    except (OSError, ValueError, KeyError):
        return missing
    if entry["status"] != "VERIFIED" or sex not in ("male", "female"):
        return {
            **missing,
            "importStatus": entry["status"],
            "reason": "REFERENCE_NOT_VERIFIED",
        }
    rows = [
        r
        for r in data["tables"][indicator]
        if int(r["sex"]) == (1 if sex == "male" else 2)
    ]
    xkey = "length" if indicator == "wfl" else "height" if indicator == "wfh" else "age"
    rows = [
        r
        for r in rows
        if (x_min is None or r[xkey] >= x_min) and (x_max is None or r[xkey] <= x_max)
    ]
    groups = {}
    for row in rows:
        basis = (
            (
                "recumbent_length"
                if row.get("loh", row.get("lorh")) == "L"
                else "standing_height"
            )
            if indicator in ("lhfa", "bmifa", "wfl", "wfh")
            else None
        )
        if xkey == "age" and row["age"] > 1826:
            continue
        key = f'{indicator}-{basis or "age"}'
        groups.setdefault(key, {"basis": basis, "rows": []})["rows"].append(row)
    sources = []
    segments = []
    for key, group in groups.items():
        values = group["rows"]
        source = {
            "datasetId": key,
            "sha256": entry["sha256"],
            "sourceUrl": entry["sourceUrl"],
            "version": entry["version"],
            "retrievedOn": entry["retrievedOn"],
            "sex": sex,
            "standard": "WHO-2006",
            "unit": (
                "kg"
                if indicator in ("wfa", "wfl", "wfh")
                else "kg/m2" if indicator == "bmifa" else "cm"
            ),
            "xType": (
                "length_cm"
                if indicator == "wfl"
                else "height_cm" if indicator == "wfh" else "age_days"
            ),
            "xMin": values[0][xkey],
            "xMax": values[-1][xkey],
        }
        sources.append(source)
        segments.append(
            {
                "id": key,
                "datasetId": key,
                "basis": group["basis"],
                "xMin": source["xMin"],
                "xMax": source["xMax"],
                "curves": [
                    {
                        "sd": k,
                        "points": [
                            {"x": r[xkey], "y": quantile(r, k)}
                            for r in values
                            if quantile(r, k) is not None
                        ],
                    }
                    for k in range(-3, 4)
                ],
            }
        )
    return {
        "importStatus": "VERIFIED",
        "reason": None,
        "standard": "WHO-2006",
        "sources": sources,
        "segments": segments,
    }


def velocity_tables():
    try:
        return datasets()["velocity"]
    except (OSError, ValueError, KeyError):
        return None, None
