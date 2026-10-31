"""Header JWT thật cho test cần đăng nhập (cách làm giống test_vaccination).

Tạo phiên trong DB cho phụ huynh / admin rồi ký access token; close() xóa phiên đã tạo.
"""

import datetime as dt
from uuid import uuid4

import jwt

from app.core import security
from app.core.config import settings

SECRET = "jwt-test-secret-at-least-32-characters-long"


class JwtAuth:
    def __init__(self, db, monkeypatch):
        monkeypatch.setattr(settings, "auth_secret", SECRET)
        self.db = db
        self.sessions: list[str] = []
        self.admins: list[str] = []
        self._users: dict[str, dict] = {}

    def user(self, user_id) -> dict:
        user_id = str(user_id)
        if user_id not in self._users:
            sid, expiry = str(uuid4()), security.now() + dt.timedelta(hours=1)
            with self.db, self.db.cursor() as cur:
                cur.execute(
                    "INSERT INTO account.user_sessions (id,user_id,refresh_token_hash,platform,expires_at) VALUES (%s,%s,%s,'android',%s)",
                    (sid, user_id, security.secret_hash(sid), expiry),
                )
            self.sessions.append(sid)
            self._users[user_id] = {
                "Authorization": "Bearer " + security.access_token(user_id, sid, expiry)
            }
        return self._users[user_id]

    def admin(self) -> dict:
        # Admin không còn chia vai trò: admin đang hoạt động có mọi quyền
        uid, sid = str(uuid4()), str(uuid4())
        expiry = security.now() + dt.timedelta(hours=1)
        with self.db, self.db.cursor() as cur:
            cur.execute(
                "INSERT INTO admin.admin_users (id,email,password_hash,full_name) VALUES (%s,%s,'!test','JWT test')",
                (uid, uid + "@example.test"),
            )
            cur.execute(
                "INSERT INTO admin.admin_sessions (id,admin_user_id,refresh_token_hash,expires_at) VALUES (%s,%s,%s,%s)",
                (sid, uid, security.secret_hash(sid), expiry),
            )
        self.admins.append(uid)
        token = jwt.encode(
            {
                "sub": uid,
                "sid": sid,
                "iat": security.now(),
                "exp": expiry,
                "iss": settings.auth_issuer,
                "aud": settings.auth_admin_audience,
            },
            settings.auth_secret,
            algorithm="HS256",
        )
        return {"Authorization": "Bearer " + token}

    def close(self):
        with self.db, self.db.cursor() as cur:
            cur.execute(
                "DELETE FROM account.user_sessions WHERE id = ANY(%s::uuid[])", (self.sessions,)
            )
            cur.execute(
                "DELETE FROM admin.admin_users WHERE id = ANY(%s::uuid[])", (self.admins,)
            )
