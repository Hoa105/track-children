"""Resource access checks shared by API features."""

from typing import Literal
from uuid import UUID

from fastapi import HTTPException, status
from psycopg2.extensions import connection as Connection

AccessLevel = Literal["view", "edit"]


def require_child_access(
    conn: Connection, child_id: UUID, user_id: UUID, scope: str, level: AccessLevel
) -> dict:
    """Chủ hồ sơ có toàn quyền; người được chia sẻ theo child_member_permissions (F23.2).

    Trả về dòng child.children. Không có quyền xem -> 404 để không lộ hồ sơ tồn tại.
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT c.id, c.date_of_birth,
                   CASE WHEN c.owner_user_id = %(user)s THEN 'edit'
                        ELSE coalesce(p.access_level, 'none') END AS access
            FROM child.children c
            LEFT JOIN child.child_members m
              ON m.child_id = c.id AND m.user_id = %(user)s AND m.status = 'active'
            LEFT JOIN child.child_member_permissions p
              ON p.member_id = m.id AND p.data_scope = %(scope)s
            WHERE c.id = %(child)s AND c.deleted_at IS NULL
            """,
            {"user": str(user_id), "child": str(child_id), "scope": scope},
        )
        row = cur.fetchone()
    if row is None or row["access"] == "none":
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Không tìm thấy hồ sơ trẻ")
    if level == "edit" and row["access"] != "edit":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Bạn chỉ có quyền xem mục này")
    return row
