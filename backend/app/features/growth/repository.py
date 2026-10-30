"""psycopg3 only; a parent row lock serializes all growth writers/publishers."""

from app.core.database import transaction
from .errors import GrowthError


def child(db, child_id, user_id, *, edit=False, lock=False):
    row = db.execute(
        """SELECT c.*, CASE WHEN c.owner_user_id=%s THEN 'edit'
        ELSE coalesce(p.access_level,'none') END AS growth_access
        FROM child.children c
        LEFT JOIN child.child_members m ON m.child_id=c.id AND m.user_id=%s AND m.status='active'
        LEFT JOIN child.child_member_permissions p ON p.member_id=m.id AND p.data_scope='growth'
        WHERE c.id=%s AND c.deleted_at IS NULL"""
        + (" FOR UPDATE OF c" if lock else ""),
        (user_id, user_id, child_id),
    ).fetchone()
    if not row or row["growth_access"] == "none":
        raise GrowthError(404, "RESOURCE_NOT_FOUND")
    if edit and row["growth_access"] != "edit":
        raise GrowthError(403, "UNAUTHORIZED_CAREGIVER")
    return row


def snapshot(child_id, user_id):
    with transaction() as db:
        db.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ")
        profile = child(db, child_id, user_id)
        measurements = db.execute(
            "SELECT * FROM growth.measurements WHERE child_id=%s AND deleted_at IS NULL ORDER BY measured_on,metric",
            (child_id,),
        ).fetchall()
        evaluations = db.execute(
            "SELECT * FROM growth.evaluations WHERE child_id=%s", (child_id,)
        ).fetchall()
        return profile, measurements, evaluations


def invalidate(db, ids):
    if ids:
        db.execute(
            "DELETE FROM growth.evaluations WHERE measurement_id=ANY(%s::uuid[]) OR paired_measurement_id=ANY(%s::uuid[])",
            (ids, ids),
        )
