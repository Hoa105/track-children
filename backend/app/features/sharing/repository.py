"""Database operations for child sharing."""

import json
from uuid import UUID


def is_owner(cur, child_id: UUID, user_id: UUID) -> bool:
    cur.execute(
        "SELECT 1 FROM child.children WHERE id=%s AND owner_user_id=%s AND deleted_at IS NULL",
        (str(child_id), str(user_id)),
    )
    return cur.fetchone() is not None


def list_members(cur, child_id: UUID) -> list[dict]:
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
    return cur.fetchall()


def list_pending_invitations(cur, child_id: UUID) -> list[dict]:
    cur.execute(
        """SELECT id,invitee_email,invitee_phone,relationship,proposed_permissions,
                  status,expires_at,created_at
           FROM child.child_invitations
           WHERE child_id=%s AND status='pending' ORDER BY created_at DESC""",
        (str(child_id),),
    )
    return cur.fetchall()


def lock_active_member(cur, child_id: UUID, member_id: UUID) -> bool:
    cur.execute(
        "SELECT 1 FROM child.child_members WHERE id=%s AND child_id=%s AND status='active' FOR UPDATE",
        (str(member_id), str(child_id)),
    )
    return cur.fetchone() is not None


def upsert_permission(cur, member_id: UUID, scope: str, level: str) -> None:
    cur.execute(
        """INSERT INTO child.child_member_permissions(member_id,data_scope,access_level)
           VALUES (%s,%s,%s) ON CONFLICT(member_id,data_scope)
           DO UPDATE SET access_level=EXCLUDED.access_level""",
        (str(member_id), scope, level),
    )


def log_change(
    cur, child_id: UUID, user_id: UUID, scope: str, entity_type: str,
    entity_id: UUID, action: str, changes: dict,
) -> None:
    cur.execute(
        """INSERT INTO child.child_data_change_logs
           (child_id,user_id,data_scope,entity_type,entity_id,action,changes)
           VALUES (%s,%s,%s,%s,%s,%s,%s)""",
        (str(child_id), str(user_id), scope, entity_type, str(entity_id), action,
         json.dumps(changes)),
    )


def revoke_member(cur, child_id: UUID, member_id: UUID) -> bool:
    cur.execute(
        """UPDATE child.child_members SET status='revoked',ended_at=now()
           WHERE id=%s AND child_id=%s AND status='active'""",
        (str(member_id), str(child_id)),
    )
    return cur.rowcount > 0


def lock_child(cur, child_id: UUID) -> None:
    cur.execute("SELECT 1 FROM child.children WHERE id=%s FOR UPDATE", (str(child_id),))


def count_used_slots(cur, child_id: UUID) -> int:
    cur.execute(
        """SELECT
             (SELECT count(*) FROM child.child_members WHERE child_id=%s AND status='active') +
             (SELECT count(*) FROM child.child_invitations
                WHERE child_id=%s AND status='pending' AND expires_at>now()) AS used""",
        (str(child_id), str(child_id)),
    )
    return cur.fetchone()["used"]


def find_invitee(cur, email: str | None, phone: str | None) -> dict | None:
    if email is not None:
        cur.execute("SELECT id FROM account.users WHERE lower(email::text)=lower(%s)", (email,))
    else:
        cur.execute("SELECT id FROM account.users WHERE phone=%s", (phone,))
    return cur.fetchone()


def create_invitation(cur, child_id: UUID, user_id: UUID, body, invitee: dict | None) -> dict:
    cur.execute(
        """INSERT INTO child.child_invitations
             (child_id,inviter_id,invitee_email,invitee_phone,invitee_user_id,
              invite_code,relationship,proposed_permissions,expires_at)
           VALUES (%s,%s,%s,%s,%s,upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),%s,%s,now()+interval '7 days')
           RETURNING id,status,expires_at,invite_code""",
        (str(child_id), str(user_id), body.email, body.phone,
         str(invitee["id"]) if invitee else None, body.relationship,
         json.dumps(body.permissions)),
    )
    return cur.fetchone()


# Lời mời gửi tới user: theo invitee_user_id, hoặc theo email/SĐT khi lúc mời
# người nhận chưa có tài khoản (invitee_user_id còn NULL).
_INVITED_USER = """
    (i.invitee_user_id = %(user)s OR (i.invitee_user_id IS NULL AND (
        (i.invitee_email IS NOT NULL AND i.invitee_email = u.email)
        OR (i.invitee_phone IS NOT NULL AND i.invitee_phone = u.phone))))
"""


def lock_pending_invitation(cur, invitation_id: UUID, user_id: UUID) -> dict | None:
    cur.execute(
        f"""SELECT i.* FROM child.child_invitations i
            JOIN account.users u ON u.id = %(user)s
            WHERE i.id = %(id)s AND i.status = 'pending' AND i.expires_at > now()
              AND {_INVITED_USER}
            FOR UPDATE OF i""",
        {"id": str(invitation_id), "user": str(user_id)},
    )
    return cur.fetchone()


def list_incoming_invitations(cur, user_id: UUID) -> list[dict]:
    cur.execute(
        f"""SELECT i.id, i.child_id, c.full_name AS child_name, c.nickname AS child_nickname,
                   c.date_of_birth AS child_date_of_birth,
                   inviter.display_name AS inviter_name, i.relationship,
                   i.proposed_permissions, i.expires_at, i.created_at
            FROM child.child_invitations i
            JOIN account.users u ON u.id = %(user)s
            JOIN child.children c ON c.id = i.child_id AND c.deleted_at IS NULL
            JOIN account.users inviter ON inviter.id = i.inviter_id
            WHERE i.status = 'pending' AND i.expires_at > now() AND {_INVITED_USER}
            ORDER BY i.created_at DESC""",
        {"user": str(user_id)},
    )
    return cur.fetchall()


def cancel_invitation(cur, child_id: UUID, invitation_id: UUID) -> bool:
    cur.execute(
        """UPDATE child.child_invitations SET status='cancelled', responded_at=now()
           WHERE id=%s AND child_id=%s AND status='pending'""",
        (str(invitation_id), str(child_id)),
    )
    return cur.rowcount > 0


def leave_child(cur, child_id: UUID, user_id: UUID) -> UUID | None:
    cur.execute(
        """UPDATE child.child_members SET status='left', ended_at=now()
           WHERE child_id=%s AND user_id=%s AND status='active'
           RETURNING id""",
        (str(child_id), str(user_id)),
    )
    row = cur.fetchone()
    return row["id"] if row else None


def owner_id(cur, child_id: UUID) -> UUID | None:
    cur.execute(
        "SELECT owner_user_id FROM child.children WHERE id=%s AND deleted_at IS NULL",
        (str(child_id),),
    )
    row = cur.fetchone()
    return row["owner_user_id"] if row else None


def is_active_member(cur, child_id: UUID, user_id: UUID) -> bool:
    cur.execute(
        "SELECT 1 FROM child.child_members WHERE child_id=%s AND user_id=%s AND status='active'",
        (str(child_id), str(user_id)),
    )
    return cur.fetchone() is not None


def has_pending_invitation(cur, child_id: UUID, email: str | None, phone: str | None) -> bool:
    cur.execute(
        """SELECT 1 FROM child.child_invitations
           WHERE child_id=%s AND status='pending' AND expires_at>now()
             AND (invitee_email=%s OR invitee_phone=%s)""",
        (str(child_id), email, phone),
    )
    return cur.fetchone() is not None


def upsert_member(cur, invitation: dict, user_id: UUID) -> UUID:
    cur.execute(
        """INSERT INTO child.child_members(child_id,user_id,relationship,status)
           VALUES (%s,%s,%s,'active')
           ON CONFLICT(child_id,user_id) DO UPDATE SET
             relationship=EXCLUDED.relationship,status='active',joined_at=now(),ended_at=NULL
           RETURNING id""",
        (str(invitation["child_id"]), str(user_id), invitation["relationship"]),
    )
    return cur.fetchone()["id"]


def mark_invitation_accepted(cur, invitation_id: UUID, user_id: UUID) -> None:
    cur.execute(
        """UPDATE child.child_invitations
           SET status='accepted', responded_at=now(), invitee_user_id=%s WHERE id=%s""",
        (str(user_id), str(invitation_id)),
    )


def clear_permissions(cur, member_id: UUID) -> None:
    """Khi tham gia lại: quyền cũ (trước lần bị thu hồi / rời) không được giữ."""
    cur.execute(
        "DELETE FROM child.child_member_permissions WHERE member_id=%s", (str(member_id),)
    )


def decline_invitation(cur, invitation_id: UUID, user_id: UUID) -> bool:
    cur.execute(
        f"""UPDATE child.child_invitations i
            SET status='declined', responded_at=now(), invitee_user_id=%(user)s
            FROM account.users u
            WHERE u.id = %(user)s AND i.id = %(id)s AND i.status = 'pending'
              AND {_INVITED_USER}""",
        {"id": str(invitation_id), "user": str(user_id)},
    )
    return cur.rowcount > 0
