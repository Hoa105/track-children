"""Authenticated child profile selection shared across mobile features."""

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
                ELSE coalesce(growth_permission.access_level,'none') END AS growth_access,
                CASE WHEN c.owner_user_id=%s THEN 'edit'
                ELSE coalesce(teething_permission.access_level,'none') END AS teething_access
            FROM child.children c
            LEFT JOIN child.child_members m ON m.child_id=c.id AND m.user_id=%s AND m.status='active'
            LEFT JOIN child.child_member_permissions growth_permission
                ON growth_permission.member_id=m.id AND growth_permission.data_scope='growth'
            LEFT JOIN child.child_member_permissions teething_permission
                ON teething_permission.member_id=m.id AND teething_permission.data_scope='teething'
            WHERE c.deleted_at IS NULL AND (c.owner_user_id=%s OR m.id IS NOT NULL)
            ORDER BY c.date_of_birth DESC,c.id
        """,
            (user, user, user, user),
        ).fetchall()
    return {
        "children": [
            {
                "id": str(child["id"]),
                "fullName": child["full_name"],
                "nickname": child["nickname"],
                "dateOfBirth": child["date_of_birth"],
                "gender": child["gender"],
                "growthAccess": child["growth_access"],
                "teethingAccess": child["teething_access"],
            }
            for child in rows
        ]
    }
