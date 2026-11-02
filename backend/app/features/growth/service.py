from datetime import datetime, time as day_time, timedelta, timezone

from app.core.database import transaction
from . import repository as repo
from .errors import GrowthError

TZ = timezone(timedelta(hours=7))


def today():
    return datetime.now(TZ).date()


def validate_day(day, birth):
    if day < birth or day > today():
        raise GrowthError(
            422, "INVALID_DATE", {"measuredOn": "Must be between birth date and today"}
        )


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


def common(state):
    return {
        "meta": state["meta"],
        "child": public_child(state["profile"]),
        "scope": state["scope"],
    }


def save(child_id, user_id, day, body):
    changed = []
    overwritten = []
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
            if old:
                overwritten.append(metric)
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

        day_rows = db.execute(
            "SELECT * FROM growth.measurements WHERE child_id=%s AND measured_on=%s AND deleted_at IS NULL ORDER BY metric",
            (child_id, day),
        ).fetchall()

    return {
        "measurementSaved": True,
        "changedMetrics": changed,
        "overwrittenMetrics": overwritten,
        "day": {
            "meta": {"schemaVersion": "1"},
            "child": public_child(profile),
            "measuredOn": day,
            "measurements": [measurement(r, profile) for r in day_rows],
        },
    }


def delete(child_id, user_id, measurement_id):
    with transaction() as db:
        repo.child(db, child_id, user_id, edit=True, lock=True)
        row = db.execute(
            "SELECT id,metric,measured_on FROM growth.measurements WHERE id=%s AND child_id=%s",
            (measurement_id, child_id),
        ).fetchone()
        if not row:
            raise GrowthError(404, "RESOURCE_NOT_FOUND")
        db.execute(
            "UPDATE growth.measurements SET deleted_at=coalesce(deleted_at,now()),updated_at=now() WHERE id=%s",
            (measurement_id,),
        )
        repo.invalidate(db, [measurement_id])
        # A deleted neighbour may change the preferred pair of another weight.
        db.execute("DELETE FROM growth.evaluations WHERE child_id=%s", (child_id,))
