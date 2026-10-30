"""Verify normalized velocity rows against Excel links on the official WHO pages."""

import hashlib
from html.parser import HTMLParser
import importlib.util
import json
from pathlib import Path
import re
import sys
from urllib.parse import urljoin, unquote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "backend/data/who"
spec = importlib.util.spec_from_file_location(
    "inventory", ROOT / "docs/core_growth/tools/inventory_who_velocity.py"
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.urls = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            for key, value in attrs:
                if key == "href" and ".xlsx" in value.lower():
                    self.urls.append(value)


def fetch(url):
    with urlopen(
        Request(
            url, headers={"User-Agent": "Mozilla/5.0 WHO growth source verification"}
        ),
        timeout=45,
    ) as response:
        return response.read()


def verify():
    tables = json.loads((DATA / "velocity.json").read_text(encoding="utf-8"))
    cache = ROOT / "backend/.runtime/who-verification"
    cache.mkdir(parents=True, exist_ok=True)
    pages = {}
    for table in tables:
        page = table["source_page_url"]
        if page not in pages:
            parser = Links()
            parser.feed(fetch(page).decode("utf-8"))
            pages[page] = [urljoin(page, link) for link in parser.urls]
        if "--list" in sys.argv:
            continue
        sex = "boys" if table["sex"] == "male" else "girls"
        metric = (
            "headc"
            if table["indicator"] == "head_circumference"
            else table["indicator"]
        )
        period = table["table_interval_months"]
        candidates = [
            url
            for url in pages[page]
            if re.search(rf"{metric}[_-]{sex}[_-]{period}mon[_-]z\.xlsx", unquote(url))
        ]
        if len(set(candidates)) != 1:
            raise RuntimeError(f"Ambiguous/missing WHO Excel: {metric}/{sex}/{period}")
        url = candidates[0]
        path = cache / f"{metric}_{sex}_{period}.xlsx"
        if not path.exists():
            path.write_bytes(fetch(url))
        _, _, official = module.read_workbook(path)
        if len(official) != len(table["rows"]):
            raise ValueError("WHO row count mismatch: " + table["path"])
        for original, normalized in zip(official, table["rows"]):
            values = list(original.values())
            interval = module.parse_interval(values[0])
            assert all(
                interval[k] == normalized[k]
                for k in ("start", "start_unit", "end", "end_unit")
            )
            expected = (
                [normalized[k] for k in ("l", "m", "s")]
                + ([normalized["shift"]] if metric == "weight" else [])
                + [point["value"] for point in normalized["sdValues"]]
            )
            assert len(values) - 1 == len(expected)
            assert all(
                abs(float(a) - b) < 1e-9 for a, b in zip(values[1:], expected)
            ), table["path"]
        table.update(
            source_download_url=url,
            date_retrieved="2026-10-29",
            verification_status="VERIFIED",
            official_download_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        )
        print("Verified", table["path"], flush=True)
    if "--list" in sys.argv:
        for urls in pages.values():
            for url in urls:
                print(url)
        return
    encoded = json.dumps(tables, ensure_ascii=False, separators=(",", ":"))
    (DATA / "velocity.json").write_text(encoded, encoding="utf-8")
    manifest = json.loads((DATA / "manifest.json").read_text(encoding="utf-8"))
    entry = next(e for e in manifest["files"] if e["kind"] == "velocity")
    entry.update(
        status="VERIFIED",
        sha256=hashlib.sha256(encoded.encode()).hexdigest(),
        verificationMethod="All 26 local tables matched official WHO linked XLSX interval labels and all numeric values; original/official download hashes retained per table",
    )
    (DATA / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    verify()
