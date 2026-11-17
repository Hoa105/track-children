"""Business rules and transactions for child sharing."""

from uuid import UUID

from fastapi import HTTPException, status
from psycopg2.extensions import connection as Connection

from app.features.sharing import repository
from app.features.sharing.schemas import InvitationCreate, PermissionUpdate

MAX_SHARED_SLOTS = 3  # thành viên đang hoạt động + lời mời đang chờ


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
        invitee = repository.find_invitee(cur, body.email, body.phone)
        if invitee is not None and str(invitee["id"]) == str(user_id):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Bạn không thể tự mời chính mình")
        if invitee is not None and repository.is_active_member(cur, child_id, invitee["id"]):
            raise HTTPException(status.HTTP_409_CONFLICT, "Người này đã được chia sẻ hồ sơ bé")
        if repository.has_pending_invitation(cur, child_id, body.email, body.phone):
            raise HTTPException(status.HTTP_409_CONFLICT, "Đã có lời mời đang chờ cho người này")
        if repository.count_used_slots(cur, child_id) >= MAX_SHARED_SLOTS:
            raise HTTPException(
                status.HTTP_409_CONFLICT, f"Hồ sơ đã đủ {MAX_SHARED_SLOTS} vị trí chia sẻ"
            )
        return repository.create_invitation(cur, child_id, user_id, body, invitee)


def cancel_invitation(
    conn: Connection, child_id: UUID, invitation_id: UUID, user_id: UUID,
) -> None:
    _require_owner(conn, child_id, user_id)
    with conn, conn.cursor() as cur:
        if not repository.cancel_invitation(cur, child_id, invitation_id):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Lời mời không còn hiệu lực")


def list_incoming_invitations(conn: Connection, user_id: UUID) -> dict:
    with conn.cursor() as cur:
        invitations = repository.list_incoming_invitations(cur, user_id)
    return {"invitations": invitations}


def leave_child(conn: Connection, child_id: UUID, user_id: UUID) -> None:
    """Người được chia sẻ tự rời hồ sơ; chủ hồ sơ không rời được (phải bàn giao)."""
    with conn, conn.cursor() as cur:
        if str(repository.owner_id(cur, child_id)) == str(user_id):
            raise HTTPException(
                status.HTTP_409_CONFLICT, "Chủ hồ sơ không thể rời hồ sơ của bé"
            )
        member_id = repository.leave_child(cur, child_id, user_id)
        if member_id is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy hồ sơ trẻ")
        repository.log_change(
            cur, child_id, user_id, "profile", "caregiver", member_id, "delete", {"left": True},
        )


def accept_invitation(conn: Connection, invitation_id: UUID, user_id: UUID) -> dict:
    with conn, conn.cursor() as cur:
        invitation = repository.lock_pending_invitation(cur, invitation_id, user_id)
        if invitation is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Lời mời không còn hiệu lực")
        if str(repository.owner_id(cur, invitation["child_id"])) == str(user_id):
            raise HTTPException(status.HTTP_409_CONFLICT, "Bạn đã là chủ hồ sơ của bé")
        member_id = repository.upsert_member(cur, invitation, user_id)
        repository.clear_permissions(cur, member_id)
        for scope, level in (invitation["proposed_permissions"] or {}).items():
            repository.upsert_permission(cur, member_id, scope, level)
        repository.mark_invitation_accepted(cur, invitation_id, user_id)
    return {"childId": str(invitation["child_id"]), "memberId": str(member_id)}


def decline_invitation(conn: Connection, invitation_id: UUID, user_id: UUID) -> None:
    with conn, conn.cursor() as cur:
        if not repository.decline_invitation(cur, invitation_id, user_id):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Lời mời không còn hiệu lực")
