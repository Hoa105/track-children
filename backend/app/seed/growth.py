"""Optional local Growth v2 fixtures; requires migration 015 and an existing child.

Run: python -m app.seed.growth --child-id <UUID>
Values are fictional raw measurements, not WHO reference data or evaluations.
"""

import argparse
import calendar
import datetime as dt
from decimal import Decimal
from uuid import UUID, NAMESPACE_URL, uuid5


# month, kg, cm (length before 24 months, standing height thereafter), head cm
SAMPLES = (
    (0, "3.30", "50.00", "34.50"),
    (1, "4.50", "54.50", "37.00"),
    (2, "5.60", "58.00", "39.00"),
    (3, "6.30", "61.00", "40.50"),
    (6, "7.80", "67.00", "43.00"),
    (9, "8.80", "72.00", "45.00"),
    (12, "9.60", "76.00", "46.00"),
    (18, "10.90", "82.00", "47.50"),
    (24, "12.20", "87.00", "48.50"),
    (30, "13.30", "92.00", "49.00"),
    (36, "14.50", "96.00", "49.50"),
    (48, "16.50", "103.00", "50.50"),
    (59, "18.20", "110.00", "51.00"),
)
LOCAL_TIMEZONE = dt.timezone(dt.timedelta(hours=7))


def sample_rows(child_id: UUID, born: dt.date, today: dt.date):
    """Calendar-month milestones, excluding future dates and age >= 60 months."""
    for month, weight, height, head in SAMPLES:
        year, zero_month = divmod(born.year * 12 + born.month - 1 + month, 12)
        month_number = zero_month + 1
        day = min(born.day, calendar.monthrange(year, month_number)[1])
        measured_on = dt.date(year, month_number, day)
        if measured_on > today:
            continue
        measured_at = dt.datetime.combine(measured_on, dt.time(9), LOCAL_TIMEZONE)
        for metric, value in zip(
            ("weight", "height", "head_circumference"), (weight, height, head)
        ):
            position = ("lying" if month < 24 else "standing") if metric == "height" else None
            measurement_id = uuid5(
                NAMESPACE_URL, f"track-children/growth-seed/v2/{child_id}/{metric}/{measured_on}"
            )
            yield (
                str(measurement_id), str(child_id), metric, Decimal(value), position,
                measured_at, measured_on, "[growth-demo-v2] Fictional sample measurement",
            )


def seed(db, child_id: UUID, today: dt.date | None = None) -> int:
    from app.core.config import settings

    if settings.app_env != "local":
        raise RuntimeError("Growth samples require APP_ENV=local")
    today = today or dt.datetime.now(LOCAL_TIMEZONE).date()
    inserted = 0
    with db.transaction():
        child = db.execute(
            """SELECT date_of_birth FROM child.children
               WHERE id = %s AND deleted_at IS NULL FOR SHARE""", (child_id,)
        ).fetchone()
        if child is None:
            raise ValueError("Child does not exist or is deleted; pass an existing local demo child UUID")
        born = child["date_of_birth"]
        if born > today:
            raise ValueError("Child date of birth is in the future")
        for row in sample_rows(child_id, born, today):
            result = db.execute(
                """INSERT INTO growth.measurements
                   (id, child_id, metric, value, measure_position, measured_at, measured_on, note)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                   ON CONFLICT DO NOTHING""", row
            )
            inserted += result.rowcount
    return inserted


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--child-id", required=True, type=UUID)
    args = parser.parse_args()
    from app.core.database import transaction

    with transaction() as db:
        inserted = seed(db, args.child_id)
    print(f"Inserted {inserted} growth samples; existing rows preserved. Evaluations require anthro recalculation.")


if __name__ == "__main__":
    main()
