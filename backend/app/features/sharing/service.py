"""Business rules and transactions for child sharing."""

from uuid import UUID

from fastapi import HTTPException, status
from psycopg2.extensions import connection as Connection

from app.features.sharing import repository
from app.features.sharing.schemas import InvitationCreate, PermissionUpdate


def _require_owner(conn: Connection, child_id: UUID, user_id: UUID) -> None:
    with conn.cursor() as cur:
        owned = repository.is_owner(cur, child_id, user_id)
    if not owned:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy hồ sơ trẻ")


def get_sharing(conn: Connection, child_id: UUID, user_id: UUID) -> dict:
    _require_owner(conn, child_id, user_id)
    with conn.cursor() as cur:
        members = repository.list_members(cur, child_id)
        invitations = repository.list_pending_invitations(cur, child_id)
    return {"members": members, "invitations": invitations}


def update_member_permissions(
    conn: Connection, child_id: UUID, member_id: UUID, user_id: UUID,
    body: PermissionUpdate,
) -> dict:
    _require_owner(conn, child_id, user_id)
    with conn, conn.cursor() as cur:
        if not repository.lock_active_member(cur, child_id, member_id):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy thành viên")
        for scope, level in body.permissions.items():
            repository.upsert_permission(cur, member_id, scope, level)
            repository.log_change(
                cur, child_id, user_id, scope, "caregiver_permission", member_id,
                "update", {"accessLevel": level},
            )
    return {"memberId": str(member_id), "permissions": body.permissions}


def revoke_member(conn: Connection, child_id: UUID, member_id: UUID, user_id: UUID) -> None:
    _require_owner(conn, child_id, user_id)
    with conn, conn.cursor() as cur:
        if repository.revoke_member(cur, child_id, member_id):
            repository.log_change(
                cur, child_id, user_id, "profile", "caregiver", member_id,
                "delete", {"revoked": True},
            )


def create_invitation(
    conn: Connection, child_id: UUID, user_id: UUID, body: InvitationCreate,
) -> dict:
    _require_owner(conn, child_id, user_id)
    with conn, conn.cursor() as cur:
        repository.lock_child(cur, child_id)
        if repository.count_used_slots(cur, child_id) >= 3:
            raise HTTPException(status.HTTP_409_CONFLICT, "Hồ sơ đã đủ 3 vị trí chia sẻ")
        invitee = repository.find_invitee(cur, body.email, body.phone)
        return repository.create_invitation(cur, child_id, user_id, body, invitee)


def accept_invitation(conn: Connection, invitation_id: UUID, user_id: UUID) -> dict:
    with conn, conn.cursor() as cur:
        invitation = repository.lock_pending_invitation(cur, invitation_id, user_id)
        if invitation is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Lời mời không còn hiệu lực")
        member_id = repository.upsert_member(cur, invitation, user_id)
        for scope, level in (invitation["proposed_permissions"] or {}).items():
            repository.upsert_permission(cur, member_id, scope, level)
        repository.mark_invitation_accepted(cur, invitation_id)
    return {"childId": str(invitation["child_id"]), "memberId": str(member_id)}


def decline_invitation(conn: Connection, invitation_id: UUID, user_id: UUID) -> None:
    with conn, conn.cursor() as cur:
        if not repository.decline_invitation(cur, invitation_id, user_id):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Lời mời không còn hiệu lực")
