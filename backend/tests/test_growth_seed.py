import datetime as dt
from uuid import UUID

from app.seed.growth import sample_rows


CHILD = UUID("00000000-0000-4000-8000-000000000101")


def test_calendar_month_end_and_no_future_measurements():
    rows = list(sample_rows(CHILD, dt.date(2024, 1, 31), dt.date(2024, 2, 29)))
    assert len(rows) == 6
    assert {r[6] for r in rows} == {dt.date(2024, 1, 31), dt.date(2024, 2, 29)}
    assert all(r[5].utcoffset() == dt.timedelta(hours=7) for r in rows)
    assert all(r[5].date() == r[6] for r in rows)


def test_positions_daily_uniqueness_and_stable_ids():
    rows = list(sample_rows(CHILD, dt.date(2020, 1, 1), dt.date(2026, 10, 29)))
    assert len(rows) == 39
    assert len({(r[1], r[2], r[6]) for r in rows}) == len(rows)
    assert rows == list(sample_rows(CHILD, dt.date(2020, 1, 1), dt.date(2026, 10, 29)))
    assert max(r[6] for r in rows) < dt.date(2025, 1, 1)
    for row in rows:
        assert row[3] > 0
        expected = ("lying" if row[6] < dt.date(2022, 1, 1) else "standing")
        assert row[4] == (expected if row[2] == "height" else None)
