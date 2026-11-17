"""Explicit local-only synthetic fixtures; reruns preserve edited measurements."""

import calendar
import json
from datetime import date, datetime, timezone
from uuid import NAMESPACE_URL, uuid5

import httpx
from psycopg.rows import dict_row
import psycopg
from app.core.config import settings
from app.core.security import password_hasher

PASSWORD = "BeLonKhon2026!"


def ident(key):
    return uuid5(NAMESPACE_URL, "track-children/local-growth-demo/v1/" + key)


def add_months(day, months):
    total = day.year * 12 + day.month - 1 + months
    year, month = divmod(total, 12)
    return date(year, month + 1, min(day.day, calendar.monthrange(year, month + 1)[1]))


def main():
    if settings.app_env != "local":
        raise RuntimeError("Synthetic fixture seeding requires APP_ENV=local")
    owner, viewer = ident("owner"), ident("viewer")
    # Fictional identities, no SMS/real email delivery and no existing accounts overwritten.
    accounts = [
        (owner, "growth.parent@example.com", "Growth Test Parent", "mother"),
        (viewer, "growth.viewer@example.com", "Growth Test Viewer", "father"),
    ]
    today = datetime.now(timezone.utc).date()
    first_birth = add_months(today.replace(day=1), -21)
    second_birth = add_months(today.replace(day=1), -34)
    children = [
        (ident("child-linh"), "Linh (growth test)", first_birth, "female", 21),
        (ident("child-minh"), "Minh (growth test)", second_birth, "male", 34),
    ]
    inserted = 0
    with psycopg.connect(settings.database_url, row_factory=dict_row) as db:
        for uid, email, name, relationship in accounts:
            existing = db.execute(
                "SELECT id FROM account.users WHERE email=%s", (email,)
            ).fetchone()
            if existing and existing["id"] != uid:
                raise RuntimeError(
                    "Fixture email belongs to another account; refusing overwrite"
                )
            db.execute(
                """INSERT INTO account.users(id,email,password_hash,display_name,
                default_relationship,status,email_verified_at,consented_at)
                VALUES (%s,%s,%s,%s,%s,'active',now(),now()) ON CONFLICT(id) DO NOTHING""",
                (uid, email, password_hasher.hash(PASSWORD), name, relationship),
            )
        for cid, name, birth, gender, end in children:
            db.execute(
                """INSERT INTO child.children(id,owner_user_id,full_name,nickname,
                date_of_birth,gender,birth_weight_kg,birth_height_cm,note)
                VALUES (%s,%s,%s,%s,%s,%s,3.2,49,'Synthetic local growth fixture; not clinical data')
                ON CONFLICT(id) DO NOTHING""",
                (cid, owner, name, name.split()[0], birth, gender),
            )
            current = db.execute(
                "SELECT owner_user_id,date_of_birth FROM child.children WHERE id=%s",
                (cid,),
            ).fetchone()
            if current["owner_user_id"] != owner or current["date_of_birth"] != birth:
                raise RuntimeError(
                    "Fixture profile was edited; refusing to append incompatible data"
                )
            member = ident(str(cid) + "viewer")
            db.execute(
                """INSERT INTO child.child_members(id,child_id,user_id,relationship)
                VALUES (%s,%s,%s,'father') ON CONFLICT(child_id,user_id) DO NOTHING""",
                (member, cid, viewer),
            )
            for scope in ("growth",):
                db.execute(
                    """INSERT INTO child.child_member_permissions(member_id,data_scope,access_level)
                    VALUES (%s,%s,'view') ON CONFLICT DO NOTHING""",
                    (member, scope),
                )
            for month in sorted(
                set(
                    [0, 1, 2, 3, 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21]
                    + ([23, 24, 25, 27, 30, 33, 34] if end > 24 else [])
                )
            ):
                day = add_months(birth, month)
                weight = round(
                    3.2
                    + 0.72 * min(month, 6)
                    + 0.28 * max(min(month - 6, 6), 0)
                    + 0.17 * max(month - 12, 0),
                    2,
                )
                length = round(
                    49
                    + 2.5 * min(month, 6)
                    + 1.35 * max(min(month - 6, 6), 0)
                    + 0.8 * max(month - 12, 0),
                    2,
                )
                head = round(
                    34
                    + 1.3 * min(month, 6)
                    + 0.4 * max(min(month - 6, 6), 0)
                    + 0.12 * max(month - 12, 0),
                    2,
                )
                position = "lying" if (day - birth).days < 731 else "standing"
                for metric, value in [
                    ("weight", weight),
                    (
                        "height",
                        length if position == "lying" else round(length - 0.7, 2),
                    ),
                    ("head_circumference", head),
                ]:
                    mid = ident(str(cid) + str(day) + metric)
                    # Stable IDs make reruns idempotent, including soft-deleted fixture rows.
                    inserted += db.execute(
                        """INSERT INTO growth.measurements
                        (id,child_id,metric,value,measured_on,measured_at,measure_position,note)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,'Synthetic local fixture')
                        ON CONFLICT DO NOTHING""",
                        (
                            mid,
                            cid,
                            metric,
                            value,
                            day,
                            datetime(
                                day.year, day.month, day.day, 2, tzinfo=timezone.utc
                            ),
                            position if metric == "height" else None,
                        ),
                    ).rowcount
    # Exercise the real server/auth/R path and populate persistent derived caches.
    with httpx.Client(base_url="http://127.0.0.1:8000", timeout=60) as client:
        result = client.post(
            "/api/v1/auth/login",
            json={
                "email": accounts[0][1],
                "password": PASSWORD,
                "rememberMe": False,
                "device": {"platform": "web", "deviceId": "growth-seed-check"},
            },
        )
        result.raise_for_status()
        client.headers["Authorization"] = "Bearer " + result.json()["accessToken"]
        profiles = client.get("/api/v1/children")
        profiles.raise_for_status()
        for cid, *_ in children:
            response = client.get(f"/api/v1/children/{cid}/growth")
            response.raise_for_status()
            assert len(response.json()["cards"]) == 4
        result = client.post(
            "/api/v1/auth/login",
            json={
                "email": accounts[1][1],
                "password": PASSWORD,
                "rememberMe": False,
                "device": {"platform": "web", "deviceId": "growth-seed-viewer-check"},
            },
        )
        result.raise_for_status()
        client.headers["Authorization"] = "Bearer " + result.json()["accessToken"]
        listed = client.get("/api/v1/children")
        listed.raise_for_status()
        assert {c["id"] for c in listed.json()["children"]} == {
            str(c[0]) for c in children
        }
        assert all(c["growthAccess"] == "view" for c in listed.json()["children"])
        cid = children[0][0]
        assert client.get(f"/api/v1/children/{cid}/growth").status_code == 200
        assert (
            client.put(
                f"/api/v1/children/{cid}/growth/days/{today}", json={"weightKg": 10}
            ).status_code
            == 403
        )
    print(
        json.dumps(
            {
                "accounts": [a[1] for a in accounts],
                "password": PASSWORD,
                "children": [str(c[0]) for c in children],
                "insertedMeasurements": inserted,
                "verification": "real login, child list and growth overview passed",
            }
        )
    )


if __name__ == "__main__":
    main()
