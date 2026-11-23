"""Authenticated child profile selection shared across mobile features."""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Response, status

from app.core.database import transaction
from app.features.auth.dependencies import current_user_id


router = APIRouter(prefix="/api/v1", tags=["Children"])


# Các mục dữ liệu theo từng bé mà chủ hồ sơ cấp quyền khi chia sẻ (F23).
SCOPES = ("growth", "assessment", "vaccination", "teething", "diary", "activities")


@router.get("/children")
def list_children(response: Response, user=Depends(current_user_id)):
    response.headers["Cache-Control"] = "no-store"
    with transaction() as db:
        rows = db.execute(
            """
            SELECT c.*, c.owner_user_id=%s AS is_owner, m.relationship AS member_relationship,
                   coalesce(jsonb_object_agg(p.data_scope, p.access_level)
                     FILTER (WHERE p.data_scope IS NOT NULL), '{}'::jsonb) AS permissions
            FROM child.children c
            LEFT JOIN child.child_members m ON m.child_id=c.id AND m.user_id=%s AND m.status='active'
            LEFT JOIN child.child_member_permissions p ON p.member_id=m.id
            WHERE c.deleted_at IS NULL AND (c.owner_user_id=%s OR m.id IS NOT NULL)
            GROUP BY c.id, m.id
            ORDER BY c.date_of_birth DESC,c.id
        """,
            (user, user, user),
        ).fetchall()
    return {"children": [_child(row) for row in rows]}


@router.delete("/children/{child_id}", status_code=status.HTTP_200_OK)
def delete_child(child_id: UUID, user=Depends(current_user_id)):
    """Soft-delete a child profile owned by the authenticated user."""
    with transaction() as db:
        child = db.execute(
            "SELECT id, owner_user_id FROM child.children WHERE id=%s AND deleted_at IS NULL FOR UPDATE",
            (str(child_id),),
        ).fetchone()
        if not child:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="CHILD_NOT_FOUND")
        if str(child["owner_user_id"]) != str(user):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="CHILD_NOT_OWNED")

        # Soft delete child
        db.execute(
            "UPDATE child.children SET deleted_at=now(), updated_at=now() WHERE id=%s",
            (str(child_id),),
        )
        # Cancel pending invitations and ownership transfers
        db.execute(
            "UPDATE child.child_invitations SET status='cancelled', responded_at=now() WHERE child_id=%s AND status='pending'",
            (str(child_id),),
        )
        db.execute(
            "UPDATE child.ownership_transfers SET status='cancelled', responded_at=now() WHERE child_id=%s AND status='pending'",
            (str(child_id),),
        )
        # Remove active members
        db.execute(
            "DELETE FROM child.child_members WHERE child_id=%s",
            (str(child_id),),
        )
        # Clean reminders & notifications
        db.execute(
            "DELETE FROM notification.reminders WHERE child_id=%s",
            (str(child_id),),
        )
        db.execute(
            "DELETE FROM notification.notifications WHERE child_id=%s",
            (str(child_id),),
        )
    return {"deleted": True, "childId": str(child_id)}


def _child(row) -> dict:
    owner = bool(row["is_owner"])
    granted = row["permissions"] or {}
    access = {scope: "edit" if owner else granted.get(scope, "none") for scope in SCOPES}
    return {
        "id": str(row["id"]),
        "fullName": row["full_name"],
        "nickname": row["nickname"],
        "dateOfBirth": row["date_of_birth"],
        "gender": row["gender"],
        # owner: toàn quyền, sửa thông tin bé, chia sẻ; member: theo access
        "role": "owner" if owner else "member",
        "relationship": None if owner else row["member_relationship"],
        "access": access,
        "growthAccess": access["growth"],
        "teethingAccess": access["teething"],
    }
