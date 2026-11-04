import json
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from psycopg2.extensions import connection as Connection

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from .schema import InvitationCreate, PermissionUpdate

router = APIRouter(prefix="/api/v1", tags=["mobile: sharing"])
SCOPES = ("growth", "assessment", "vaccination", "teething", "diary", "activities")


def _require_owner(conn: Connection, child_id: UUID, user_id: UUID) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM child.children WHERE id=%s AND owner_user_id=%s AND deleted_at IS NULL",
            (str(child_id), str(user_id)),
        )
        if cur.fetchone() is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy hồ sơ trẻ")


@router.get("/children/{child_id}/sharing")
def get_sharing(
    child_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    _require_owner(conn, child_id, user_id)
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT m.id, m.user_id, u.display_name, u.email, u.phone, m.relationship,
                   coalesce(jsonb_object_agg(p.data_scope, p.access_level)
                     FILTER (WHERE p.data_scope IS NOT NULL), '{}'::jsonb) permissions
            FROM child.child_members m
            JOIN account.users u ON u.id=m.user_id
            LEFT JOIN child.child_member_permissions p ON p.member_id=m.id
            WHERE m.child_id=%s AND m.status='active'
            GROUP BY m.id,u.id ORDER BY m.joined_at
            """,
            (str(child_id),),
        )
        members = cur.fetchall()
        cur.execute(
            """SELECT id,invitee_email,invitee_phone,relationship,proposed_permissions,
                      status,expires_at,created_at
               FROM child.child_invitations
               WHERE child_id=%s AND status='pending' ORDER BY created_at DESC""",
            (str(child_id),),
        )
        invitations = cur.fetchall()
    return {"members": members, "invitations": invitations}


@router.put("/children/{child_id}/sharing/members/{member_id}")
def update_member_permissions(
    child_id: UUID,
    member_id: UUID,
    body: PermissionUpdate,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    _require_owner(conn, child_id, user_id)
    with conn, conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM child.child_members WHERE id=%s AND child_id=%s AND status='active' FOR UPDATE",
            (str(member_id), str(child_id)),
        )
        if cur.fetchone() is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy thành viên")
        for scope, level in body.permissions.items():
            cur.execute(
                """INSERT INTO child.child_member_permissions(member_id,data_scope,access_level)
                   VALUES (%s,%s,%s) ON CONFLICT(member_id,data_scope)
                   DO UPDATE SET access_level=EXCLUDED.access_level""",
                (str(member_id), scope, level),
            )
            cur.execute(
                """INSERT INTO child.child_data_change_logs
                   (child_id,user_id,data_scope,entity_type,entity_id,action,changes)
                   VALUES (%s,%s,%s,'caregiver_permission',%s,'update',%s)""",
                (
                    str(child_id), str(user_id), scope, str(member_id),
                    json.dumps({"accessLevel": level}),
                ),
            )
    return {"memberId": str(member_id), "permissions": body.permissions}


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
    _require_owner(conn, child_id, user_id)
    with conn, conn.cursor() as cur:
        cur.execute(
            """UPDATE child.child_members SET status='revoked',ended_at=now()
               WHERE id=%s AND child_id=%s AND status='active'""",
            (str(member_id), str(child_id)),
        )
        if cur.rowcount:
            cur.execute(
                """INSERT INTO child.child_data_change_logs
                   (child_id,user_id,data_scope,entity_type,entity_id,action,changes)
                   VALUES (%s,%s,'profile','caregiver',%s,'delete',%s)""",
                (str(child_id), str(user_id), str(member_id), json.dumps({"revoked": True})),
            )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/children/{child_id}/sharing/invitations", status_code=201)
def create_invitation(
    child_id: UUID,
    body: InvitationCreate,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    _require_owner(conn, child_id, user_id)
    with conn, conn.cursor() as cur:
        cur.execute("SELECT 1 FROM child.children WHERE id=%s FOR UPDATE", (str(child_id),))
        cur.execute(
            """SELECT
                 (SELECT count(*) FROM child.child_members WHERE child_id=%s AND status='active') +
                 (SELECT count(*) FROM child.child_invitations WHERE child_id=%s AND status='pending' AND expires_at>now()) AS used""",
            (str(child_id), str(child_id)),
        )
        if cur.fetchone()["used"] >= 3:
            raise HTTPException(status.HTTP_409_CONFLICT, "Hồ sơ đã đủ 3 vị trí chia sẻ")
        if body.email is not None:
            cur.execute(
                "SELECT id FROM account.users WHERE lower(email::text)=lower(%s)",
                (body.email,),
            )
        else:
            cur.execute("SELECT id FROM account.users WHERE phone=%s", (body.phone,))
        invitee = cur.fetchone()
        cur.execute(
            """INSERT INTO child.child_invitations
                 (child_id,inviter_id,invitee_email,invitee_phone,invitee_user_id,
                  invite_code,relationship,proposed_permissions,expires_at)
               VALUES (%s,%s,%s,%s,%s,upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),%s,%s,now()+interval '7 days')
               RETURNING id,status,expires_at,invite_code""",
            (
                str(child_id), str(user_id), body.email, body.phone,
                str(invitee["id"]) if invitee else None, body.relationship,
                json.dumps(body.permissions),
            ),
        )
        return cur.fetchone()


@router.post("/sharing/invitations/{invitation_id}/accept")
def accept_invitation(
    invitation_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    with conn, conn.cursor() as cur:
        cur.execute(
            """SELECT * FROM child.child_invitations
               WHERE id=%s AND invitee_user_id=%s AND status='pending'
                 AND expires_at>now() FOR UPDATE""",
            (str(invitation_id), str(user_id)),
        )
        invitation = cur.fetchone()
        if invitation is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Lời mời không còn hiệu lực")
        cur.execute(
            """INSERT INTO child.child_members(child_id,user_id,relationship,status)
               VALUES (%s,%s,%s,'active')
               ON CONFLICT(child_id,user_id) DO UPDATE SET
                 relationship=EXCLUDED.relationship,status='active',joined_at=now(),ended_at=NULL
               RETURNING id""",
            (str(invitation["child_id"]), str(user_id), invitation["relationship"]),
        )
        member_id = cur.fetchone()["id"]
        permissions = invitation["proposed_permissions"] or {}
        for scope, level in permissions.items():
            cur.execute(
                """INSERT INTO child.child_member_permissions(member_id,data_scope,access_level)
                   VALUES (%s,%s,%s) ON CONFLICT(member_id,data_scope)
                   DO UPDATE SET access_level=EXCLUDED.access_level""",
                (str(member_id), scope, level),
            )
        cur.execute(
            "UPDATE child.child_invitations SET status='accepted',responded_at=now() WHERE id=%s",
            (str(invitation_id),),
        )
    return {"childId": str(invitation["child_id"]), "memberId": str(member_id)}


@router.post("/sharing/invitations/{invitation_id}/decline", status_code=204)
def decline_invitation(
    invitation_id: UUID,
    user_id: UUID = Depends(current_user_id),
    conn: Connection = Depends(get_db),
):
    with conn, conn.cursor() as cur:
        cur.execute(
            """UPDATE child.child_invitations SET status='declined',responded_at=now()
               WHERE id=%s AND invitee_user_id=%s AND status='pending'""",
            (str(invitation_id), str(user_id)),
        )
        if cur.rowcount == 0:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Lời mời không còn hiệu lực")
    return Response(status_code=204)

