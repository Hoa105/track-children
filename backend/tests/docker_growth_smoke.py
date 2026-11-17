"""HTTP acceptance against the unmodified production image and real sessions."""

from datetime import datetime, timedelta, timezone
import json
import os
import time
from uuid import uuid4

import httpx
import jwt
import psycopg


def main():
    url = os.environ["GROWTH_TEST_DATABASE_URL"]
    assert psycopg.conninfo.conninfo_to_dict(url)["dbname"].endswith("_growth_test")
    base = os.environ["GROWTH_HTTP_BASE_URL"]
    owner, child, session = uuid4(), uuid4(), uuid4()
    now = datetime.now(timezone.utc)
    with psycopg.connect(url) as db:
        db.execute(
            "INSERT INTO account.users(id,display_name,email,password_hash,status) "
            "VALUES (%s,'Docker Growth Test',%s,'fixture-only','active')",
            (owner, f"{owner}@example.test"),
        )
        db.execute(
            "INSERT INTO account.user_sessions(id,user_id,refresh_token_hash,platform,expires_at) "
            "VALUES (%s,%s,%s,'web',%s)",
            (session, owner, str(uuid4()), now + timedelta(hours=1)),
        )
        db.execute(
            "INSERT INTO child.children(id,owner_user_id,full_name,date_of_birth,gender) "
            "VALUES (%s,%s,'Docker Growth Test','2025-01-01','female')",
            (child, owner),
        )
    token = jwt.encode(
        {
            "sub": str(owner),
            "sid": str(session),
            "iat": now,
            "exp": now + timedelta(hours=1),
            "iss": "track-children",
            "aud": "track-children-mobile",
        },
        os.environ["AUTH_SECRET"],
        algorithm="HS256",
    )
    with httpx.Client(base_url=base, timeout=40) as client:
        for attempt in range(30):
            try:
                health = client.get("/health")
                if health.status_code == 200:
                    break
            except httpx.ConnectError:
                pass
            time.sleep(1)
        else:
            raise AssertionError("Server did not become ready")
        assert health.json()["growth_engine"] == "ready", health.text
        path = f"/api/v1/children/{child}/growth"
        assert client.get(path).status_code == 401
        client.headers["Authorization"] = "Bearer " + token

        def get(suffix=""):
            response = client.get(path + suffix)
            assert response.status_code == 200, response.text
            assert response.headers["cache-control"] == "no-store"
            return response.json()

        get()
        response = client.put(
            path + "/days/2026-01-01",
            json={
                "weightKg": 9.5,
                "height": {"value": 75, "measurePosition": "lying"},
                "headCircumferenceCm": 46,
            },
        )
        assert response.status_code == 200, response.text
        assert response.json()["measurementSaved"] is True
        saved = response.json()["day"]
        wfa = next(a for a in saved["assessments"] if a["indicator"] == "wfa")
        assert wfa["zScore"] == 0.49, wfa
        for metric in ("weight", "height", "head_circumference", "bmi"):
            detail = get("/metrics/" + metric)
            assert detail["samples"], detail
            if metric == "bmi":
                assert abs(detail["samples"][0]["value"] - 16.8888888889) < 0.00001
        get("/days/2026-01-01")
        second = client.put(path + "/days/2026-02-01", json={"weightKg": 9.8})
        assert second.status_code == 200, second.text
        assert get("/metrics/weight/velocity")["actualIntervals"]
        get("/metrics/weight/velocity?mode=who&intervalMonths=1")
        height = next(m for m in saved["measurements"] if m["metric"] == "height")
        deleted = client.delete(path + "/measurements/" + height["id"])
        assert deleted.status_code == 204, deleted.text
        assert get("/days/2026-01-01")["bmi"] is None
        with psycopg.connect(url) as db:
            db.execute(
                "UPDATE account.user_sessions SET revoked_at=now() WHERE id=%s",
                (session,),
            )
        assert client.get(path).status_code == 401
    print(
        json.dumps(
            {
                "result": "PASS",
                "health": health.json(),
                "operations": 6,
                "auth": "real JWT/session and revocation",
                "wfaZScore": 0.49,
                "bmi": 16.8888888889,
            }
        )
    )


if __name__ == "__main__":
    main()
