"""HTTP endpoints for child sharing."""

from uuid import UUID

from fastapi import APIRouter, Depends, Response, status
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.features.sharing import service
from app.features.sharing.schemas import InvitationCreate, PermissionUpdate


router = APIRouter(prefix="/api/v1", tags=["mobile: sharing"])


@router.get("/children/{child_id}/sharing")
def get_sharing(
    child_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    return service.get_sharing(conn, child_id, user_id)


@router.put("/children/{child_id}/sharing/members/{member_id}")
def update_member_permissions(
    child_id: UUID,
    member_id: UUID,
    body: PermissionUpdate,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    return service.update_member_permissions(conn, child_id, member_id, user_id, body)


@router.delete(
    "/children/{child_id}/sharing/members/{member_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def revoke_member(
    child_id: UUID,
    member_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    service.revoke_member(conn, child_id, member_id, user_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/children/{child_id}/sharing/invitations", status_code=201)
def create_invitation(
    child_id: UUID,
    body: InvitationCreate,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    return service.create_invitation(conn, child_id, user_id, body)


@router.post("/sharing/invitations/{invitation_id}/accept")
def accept_invitation(
    invitation_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    return service.accept_invitation(conn, invitation_id, user_id)


@router.post("/sharing/invitations/{invitation_id}/decline", status_code=204)
def decline_invitation(
    invitation_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    service.decline_invitation(conn, invitation_id, user_id)
    return Response(status_code=204)
