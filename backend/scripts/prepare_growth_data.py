"""Normalize local WHO velocity files and fingerprint the exported WHO package tables."""

import importlib.util
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "backend/data/who"
spec = importlib.util.spec_from_file_location(
    "inventory", ROOT / "docs/core_growth/tools/inventory_who_velocity.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
inventory = json.loads(
    (ROOT / "docs/core_growth/WHO-VELOCITY-INVENTORY.json").read_text(encoding="utf-8")
)
tables = []
for item in inventory["files"]:
    path = ROOT / "docs/core_growth" / item["path"]
    if hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
        raise ValueError("Source checksum changed: " + str(path))
    sheet, headers, rows = module.read_workbook(path)
    tables.append(
        {
            **item,
            "rows": [
                {
                    **interval,
                    "l": float(row["L"]),
                    "m": float(row["M"]),
                    "s": float(row["S"]),
                    "shift": float(row.get("Delta", 0)),
                    "sdValues": [
                        {"sd": k, "value": float(row[label])}
                        for k, label in zip(range(-3, 4), headers[-7:])
                    ],
                }
                for interval, row in zip(item["intervals"], rows)
            ],
        }
    )
DATA.mkdir(parents=True, exist_ok=True)
(DATA / "velocity.json").write_text(
    json.dumps(tables, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
)
files = []
for kind, status, url, version in [
    (
        "attained",
        "VERIFIED",
        "https://cran.r-project.org/package=anthro",
        "anthro-1.1.0-WHO",
    ),
    (
        "velocity",
        "LOCAL_STRUCTURE_CHECKED",
        "https://www.who.int/tools/child-growth-standards/standards/growth-velocity-based-on-weight-length-and-head-circumference",
        "WHO-2009",
    ),
]:
    path = DATA / (kind + ".json")
    files.append(
        {
            "kind": kind,
            "path": path.name,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "status": status,
            "sourceUrl": url,
            "version": version,
            "retrievedOn": "2026-10-29",
            "verificationMethod": (
                "Export of installed official WHO anthro 1.1.0 tables; checksum and public-engine anchor checks"
                if kind == "attained"
                else "Local source inventory only; official download provenance verification still required"
            ),
        }
    )
(DATA / "manifest.json").write_text(
    json.dumps({"schemaVersion": "1", "files": files}, indent=2) + "\n",
    encoding="utf-8",
)
print("Prepared attained reference and", len(tables), "velocity tables")
