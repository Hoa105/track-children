"""Nhật ký thao tác của admin (admin.admin_audit_logs)."""

import json


def audit(cur, role: str, action: str, entity_type: str, entity_id, before, after) -> None:
    # Chưa có admin_user_id thật (DEV_AUTH) — ghi vai trò vào after_data để truy vết
    cur.execute(
        """
        INSERT INTO admin.admin_audit_logs (action, entity_type, entity_id, before_data, after_data)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            action, entity_type, str(entity_id),
            json.dumps(before, default=str) if before else None,
            json.dumps({**(after or {}), "_actor_role": role}, default=str),
        ),
    )
