"""Bounded, versioned public WHO anthro subprocess adapter."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import threading
import time
import math

BACKEND = Path(__file__).resolve().parents[3]
BRIDGE = BACKEND / "scripts/anthro_bridge.R"
LIMIT = 1024 * 1024
SLOTS = threading.BoundedSemaphore(2)
HEALTH = {"status": "not_checked"}


class EngineUnavailable(Exception):
    def __init__(self, reason):
        self.reason = reason


def bundle():
    return hashlib.sha256(
        BRIDGE.read_bytes() + b"|R4.6.1|anthro1.1.0|jsonlite2.0.0|normalization-v1"
    ).hexdigest()


def startup_check():
    if HEALTH["status"] != "not_checked":
        return
    try:
        row = calculate(
            [{"row_id": "health", "sex": "f", "age_days": 365, "weight_kg": 9.5}]
        )[0]
        HEALTH["status"] = "ready" if row["zwei"] == 0.49 else "degraded"
    except EngineUnavailable:
        HEALTH["status"] = "degraded"


def calculate(rows, timeout=15):
    if not rows or len(rows) > 128:
        raise ValueError("Expected 1..128 rows")
    payload = json.dumps(
        {"schema_version": "1", "rows": rows}, allow_nan=False
    ).encode()
    if len(payload) > LIMIT:
        raise ValueError("Batch too large")
    executable = os.environ.get("GROWTH_RSCRIPT") or shutil.which("Rscript")
    if not executable:
        raise EngineUnavailable("R_EXECUTION_FAILED")
    if not SLOTS.acquire(timeout=2):
        raise EngineUnavailable("R_BUSY")
    proc = None
    try:
        env = os.environ.copy()
        local = BACKEND / ".r-library"
        if local.exists():
            env["R_LIBS_USER"] = str(local)
        proc = subprocess.Popen(
            [executable, "--vanilla", str(BRIDGE)],
            cwd=BACKEND,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
        )
        output = {}

        def drain(key, stream):
            output[key] = stream.read(LIMIT + 1)
            if len(output[key]) > LIMIT:
                proc.kill()

        threads = [
            threading.Thread(target=drain, args=(key, stream), daemon=True)
            for key, stream in [("stdout", proc.stdout), ("stderr", proc.stderr)]
        ]
        for thread in threads:
            thread.start()
        proc.stdin.write(payload)
        proc.stdin.close()
        try:
            proc.wait(timeout=max(0.1, timeout))
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            raise EngineUnavailable("R_TIMEOUT")
        finally:
            for thread in threads:
                thread.join(timeout=2)
        if any(len(data) > LIMIT for data in output.values()):
            raise EngineUnavailable("INVALID_R_RESPONSE")
        if proc.returncode:
            raise EngineUnavailable("R_EXECUTION_FAILED")
        result = json.loads(
            output.get("stdout", b""),
            parse_constant=lambda _: (_ for _ in ()).throw(ValueError()),
        )
        versions = result["engine"]
        if (
            result["schema_version"] != "1"
            or versions["anthro_version"] != "1.1.0"
            or versions["jsonlite_version"] != "2.0.0"
            or versions["R_version"] != os.environ.get("GROWTH_R_VERSION", "4.6.1")
        ):
            raise ValueError("Engine contract mismatch")
        values = result["rows"]
        expected = [r["row_id"] for r in rows]
        if not isinstance(values, list) or [v["row_id"] for v in values] != expected:
            raise ValueError("Row mismatch")
        required = [
            "clenhei",
            "cbmi",
            "cmeasure",
            "c9mo_flag",
            "csex",
            "zwei",
            "fwei",
            "zlen",
            "flen",
            "zhc",
            "fhc",
            "zbmi",
            "fbmi",
            "zwfl",
            "fwfl",
        ]
        if any(not set(required) <= v.keys() for v in values):
            raise ValueError("Missing columns")
        for request, value in zip(rows, values):
            if value["csex"] != (1 if request["sex"] == "m" else 2) or value[
                "c9mo_flag"
            ] not in (0, 1):
                raise ValueError("Cleaned input mismatch")
            for score, flag in [
                ("zwei", "fwei"),
                ("zlen", "flen"),
                ("zhc", "fhc"),
                ("zbmi", "fbmi"),
                ("zwfl", "fwfl"),
            ]:
                z, f = value[score], value[flag]
                if (z is None) != (f is None) or (
                    z is not None
                    and (
                        isinstance(z, bool)
                        or not isinstance(z, (int, float))
                        or not math.isfinite(z)
                        or isinstance(f, bool)
                        or f not in (0, 1)
                    )
                ):
                    raise ValueError("Score/flag contract mismatch")
        return values
    except EngineUnavailable:
        raise
    except OSError:
        raise EngineUnavailable("R_EXECUTION_FAILED") from None
    except (ValueError, KeyError, TypeError):
        raise EngineUnavailable("INVALID_R_RESPONSE") from None
    finally:
        if proc:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            for stream in (proc.stdout, proc.stderr, proc.stdin):
                if stream:
                    stream.close()
        SLOTS.release()
