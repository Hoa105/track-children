"""Authenticated profile selection for the growth screens."""

from fastapi import APIRouter, Depends, Response
from app.core.database import transaction
from app.features.auth.dependencies import current_user_id

router = APIRouter(prefix="/api/v1", tags=["Children"])


@router.get("/children")
def list_children(response: Response, user=Depends(current_user_id)):
    response.headers["Cache-Control"] = "no-store"
    with transaction() as db:
        rows = db.execute(
            """
            SELECT c.*, CASE WHEN c.owner_user_id=%s THEN 'edit'
                ELSE coalesce(p.access_level,'none') END AS growth_access
            FROM child.children c
            LEFT JOIN child.child_members m ON m.child_id=c.id AND m.user_id=%s AND m.status='active'
            LEFT JOIN child.child_member_permissions p ON p.member_id=m.id AND p.data_scope='growth'
            WHERE c.deleted_at IS NULL AND (c.owner_user_id=%s OR m.id IS NOT NULL)
            ORDER BY c.date_of_birth DESC,c.id
        """,
            (user, user, user),
        ).fetchall()
    return {
        "children": [
            {
                "id": str(c["id"]),
                "fullName": c["full_name"],
                "nickname": c["nickname"],
                "dateOfBirth": c["date_of_birth"],
                "gender": c["gender"],
                "growthAccess": c["growth_access"],
            }
            for c in rows
        ]
    }
