"""Authentication helpers.

Chưa có đăng nhập thật cho phụ huynh lẫn admin (docs/api/README.md). Khi
DEV_AUTH=true backend tạm tin header do client gửi:
  - X-User-Id: uuid trong account.users (mobile)
  - X-Admin-Role: mã vai trò trong admin.roles (web admin)
Khi làm xong JWT chỉ cần thay thân hai dependency bên dưới.
"""

from typing import Annotated
from uuid import UUID

from fastapi import Depends, Header, HTTPException, status
from psycopg2.extensions import connection as Connection

from app.core.config import settings
from app.core.database import get_db


def _require_dev_auth() -> None:
    if not settings.dev_auth:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Chưa hỗ trợ đăng nhập")


def current_user_id(
    x_user_id: Annotated[str | None, Header()] = None,
) -> UUID:
    _require_dev_auth()
    try:
        return UUID(x_user_id or "")
    except ValueError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Thiếu hoặc sai X-User-Id") from None


def require_admin(permission: str):
    """Dependency: admin có `permission` (theo admin.role_permissions)."""

    def dependency(
        x_admin_role: Annotated[str | None, Header()] = None,
        conn: Connection = Depends(get_db),
    ) -> str:
        _require_dev_auth()
        if not x_admin_role:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Thiếu X-Admin-Role")
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1 FROM admin.roles r
                JOIN admin.role_permissions rp ON rp.role_id = r.id
                JOIN admin.permissions p ON p.id = rp.permission_id
                WHERE r.code = %s AND p.code = %s
                """,
                (x_admin_role, permission),
            )
            if cur.fetchone() is None:
                raise HTTPException(status.HTTP_403_FORBIDDEN, f"Cần quyền {permission}")
        return x_admin_role

    return dependency
