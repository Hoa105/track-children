"""Persistence and validation for a child's primary-teeth records."""

import datetime as dt
import json
from uuid import UUID

from fastapi import HTTPException, status
from psycopg2.extensions import connection as Connection

SCOPE = "vaccination"  # migration 002 merged teething sharing into this scope


def user_today(
    timezone_offset_minutes: int, now: dt.datetime | None = None
) -> dt.date:
    """Calendar date from the mobile device's current UTC offset."""
    return (
        (now or dt.datetime.now(dt.timezone.utc))
        + dt.timedelta(minutes=timezone_offset_minutes)
    ).date()


def list_records(conn: Connection, child_id: UUID) -> list[dict]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT tooth_code, erupted_at AS erupted_on
            FROM health.child_teeth
            WHERE child_id = %s
            ORDER BY erupted_at, tooth_code
            """,
            (str(child_id),),
        )
        return cur.fetchall()


def upsert_record(
    conn: Connection,
    child: dict,
    user_id: UUID,
    tooth_code: str,
    erupted_on: dt.date,
    timezone_offset_minutes: int = 0,
    today: dt.date | None = None,
) -> dict:
    if erupted_on < child["date_of_birth"] or erupted_on > (
        today or user_today(timezone_offset_minutes)
    ):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Ngày mọc không hợp lệ")
    with conn, conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM health.tooth_references WHERE code = %s",
            (tooth_code,),
        )
        if cur.fetchone() is None:
            raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "Mã răng sữa không hợp lệ")
        cur.execute(
            """
            INSERT INTO health.child_teeth
                (child_id, tooth_code, erupted_at, created_by, updated_by)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (child_id, tooth_code) DO UPDATE SET
                erupted_at = EXCLUDED.erupted_at,
                updated_by = EXCLUDED.updated_by,
                updated_at = now()
            RETURNING tooth_code, erupted_at AS erupted_on, id, (xmax = 0) AS inserted
            """,
            (str(child["id"]), tooth_code, erupted_on, str(user_id), str(user_id)),
        )
        row = cur.fetchone()
        _audit(cur, child["id"], user_id, row["id"], "create" if row["inserted"] else "update", {
            "toothCode": tooth_code,
            "eruptedOn": erupted_on.isoformat(),
        })
        return row


def delete_record(
    conn: Connection, child_id: UUID, user_id: UUID, tooth_code: str
) -> None:
    with conn, conn.cursor() as cur:
        cur.execute(
            """
            DELETE FROM health.child_teeth
            WHERE child_id = %s AND tooth_code = %s
            RETURNING id
            """,
            (str(child_id), tooth_code),
        )
        row = cur.fetchone()
        if row is not None:
            _audit(cur, child_id, user_id, row["id"], "delete", {"toothCode": tooth_code})


def _audit(cur, child_id, user_id: UUID, entity_id, action: str, changes: dict) -> None:
    cur.execute(
        """
        INSERT INTO child.child_data_change_logs
            (child_id, user_id, data_scope, entity_type, entity_id, action, changes)
        VALUES (%s, %s, %s, 'child_tooth', %s, %s, %s)
        """,
        (
            str(child_id),
            str(user_id),
            SCOPE,
            str(entity_id),
            action,
            json.dumps(changes),
        ),
    )
