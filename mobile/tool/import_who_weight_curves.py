"""Extract unmodified monthly display thresholds from downloaded WHO XLSX.

Read-only XLSX processing; does not calculate LMS, Z-scores or assessments.
Run from any directory: python mobile/tool/import_who_weight_curves.py
"""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "assets/data/who"
NS = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
SOURCES = {
    "boys": "https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/weight-for-age/wfa_boys_0-to-5-years_zscores.xlsx?sfvrsn=97a05331_9",
    "girls": "https://cdn.who.int/media/docs/default-source/child-growth/child-growth-standards/indicators/weight-for-age/wfa_girls_0-to-5-years_zscores.xlsx?sfvrsn=4c03b8db_7",
}


def read_rows(path):
    with ZipFile(path) as archive:
        strings = []
        if "xl/sharedStrings.xml" in archive.namelist():
            strings = ["".join(si.itertext()) for si in ET.fromstring(archive.read("xl/sharedStrings.xml"))]
        sheet = ET.fromstring(archive.read("xl/worksheets/sheet1.xml"))
        rows = []
        for row in sheet.findall("s:sheetData/s:row", NS):
            values = {}
            for cell in row.findall("s:c", NS):
                col = "".join(c for c in cell.attrib["r"] if c.isalpha())
                raw = cell.findtext("s:v", namespaces=NS)
                kind = cell.attrib.get("t")
                if kind == "s":
                    value = strings[int(raw)] if raw else ""
                elif kind == "inlineStr":
                    value = "".join(cell.find("s:is", NS).itertext())
                else:
                    value = float(raw) if raw is not None else None
                values[col] = value
            rows.append(values)
        return rows


def main():
    existing = json.loads((ROOT / "assets/data/who_growth.json").read_text(encoding="utf-8"))
    data = {"indicator": "weight-for-age", "unit": "kg", "age_unit": "months",
            "columns": ["month", "sd_neg3", "sd_neg2", "median", "sd_pos2", "sd_pos3"],
            "source_page": "https://www.who.int/tools/child-growth-standards/standards/weight-for-age",
            "sources": {}, "tables": {}}
    report = {"checked_at": datetime.now(timezone.utc).isoformat(), "checks": {}}
    for sex, url in SOURCES.items():
        path = DATA / "sources" / url.split("/")[-1].split("?")[0]
        raw = read_rows(path)
        headers = {str(value).strip().lower(): col for col, value in raw[0].items()}
        names = ["month", "sd3neg", "sd2neg", "sd0", "sd2", "sd3"]
        cols = [headers[name] for name in names]
        rows = [[row[col] for col in cols] for row in raw[1:] if isinstance(row.get(cols[0]), (int, float))]
        assert len(rows) == 61 and [row[0] for row in rows] == list(range(61)), f"{sex}: invalid ages"
        assert all(all(isinstance(v, (int, float)) for v in row) for row in rows), f"{sex}: missing number"
        assert all(row[1:] == sorted(row[1:]) and all(v > 0 for v in row[1:]) for row in rows), f"{sex}: unordered thresholds"
        assert [[row[0], row[2], row[3], row[4]] for row in rows] == existing["weight"][sex], f"{sex}: existing table mismatch"
        rows = [[int(row[0]), *row[1:]] for row in rows]
        data["tables"][sex] = rows
        data["sources"][sex] = {"url": url, "file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        report["checks"][sex] = {"rows": len(rows), "age_domain": [0, 60], "sd_order_valid": True,
            "existing_three_curves_match_all_rows": True,
            "spot_checks": [row for row in rows if row[0] in (0, 6, 12, 24, 60)]}
    target = DATA / "weight_for_age_curves.json"
    target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    report["output_sha256"] = hashlib.sha256(target.read_bytes()).hexdigest()
    (DATA / "weight_for_age_validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Validated 61 monthly rows for each sex; all existing -2/median/+2 values match WHO sources.")


if __name__ == "__main__":
    main()
