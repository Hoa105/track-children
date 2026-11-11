"""Chia sẻ hồ sơ bé trên PostgreSQL thật. Dùng database riêng có tên kết thúc bằng _sharing_test."""

import os
import re
from pathlib import Path
from uuid import UUID, uuid4

import psycopg2
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from psycopg2.extras import RealDictCursor

from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.features.diary.router import router as diary_router
from app.features.sharing.router import router


@pytest.fixture(scope="module")
def database():
    url = os.environ.get("SHARING_TEST_DATABASE_URL")
    if not url:
        pytest.skip("SHARING_TEST_DATABASE_URL is required")
    params = psycopg2.extensions.parse_dsn(url)
    assert params.get("dbname", "").endswith("_sharing_test"), "Dedicated test database required"
    with psycopg2.connect(url) as conn, conn.cursor() as cur:
        cur.execute("CREATE TABLE IF NOT EXISTS public.schema_migrations (version text PRIMARY KEY)")
        for path in sorted((Path(__file__).parents[1] / "migrations").glob("*.sql")):
            cur.execute("SELECT 1 FROM public.schema_migrations WHERE version = %s", (path.stem,))
            if cur.fetchone() is None:
                sql = path.read_text(encoding="utf-8-sig")
                executable = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
                if any(
                    line.strip() and not line.lstrip().startswith("--")
                    for line in executable.splitlines()
                ):
                    cur.execute(sql)
                cur.execute("INSERT INTO public.schema_migrations VALUES (%s)", (path.stem,))
    return url


class Env:
    def __init__(self, url):
        self.conn = psycopg2.connect(url, cursor_factory=RealDictCursor)
        self.owner, self.invitee, self.later, self.outsider = (uuid4() for _ in range(4))
        self.child = uuid4()
        self.email = {}
        with self.conn, self.conn.cursor() as cur:
            for user in (self.owner, self.invitee, self.outsider):
                self._user(cur, user)
            cur.execute(
                """INSERT INTO child.children (id,owner_user_id,full_name,date_of_birth,gender)
                   VALUES (%s,%s,'Bé Sharing','2025-01-01','female')""",
                (str(self.child), str(self.owner)),
            )
        self.user = self.owner
        app = FastAPI()
        app.include_router(router)
        app.include_router(diary_router)
        app.dependency_overrides[get_db] = lambda: self.conn
        app.dependency_overrides[current_user_id] = lambda: self.user
        self.client = TestClient(app)

    def _user(self, cur, user):
        self.email[user] = f"{user}@example.test"
        cur.execute(
            """INSERT INTO account.users (id,email,password_hash,display_name,status)
               VALUES (%s,%s,'test',%s,'active')""",
            (str(user), self.email[user], f"User {str(user)[:4]}"),
        )

    def register_later(self):
        with self.conn, self.conn.cursor() as cur:
            self._user(cur, self.later)

    def as_(self, user):
        self.user = user
        return self.client

    def invite(self, email, **permissions):
        return self.as_(self.owner).post(
            f"/api/v1/children/{self.child}/sharing/invitations",
            json={"email": email, "relationship": "grandmother", "permissions": permissions},
        )

    def close(self):
        with self.conn, self.conn.cursor() as cur:
            cur.execute("DELETE FROM child.children WHERE id=%s", (str(self.child),))
            users = [str(u) for u in (self.owner, self.invitee, self.later, self.outsider)]
            cur.execute("DELETE FROM child.child_invitations WHERE inviter_id = ANY(%s::uuid[])", (users,))
            cur.execute("DELETE FROM account.users WHERE id = ANY(%s::uuid[])", (users,))
        self.conn.close()


@pytest.fixture
def env(database):
    e = Env(database)
    yield e
    e.close()


def _incoming(env, user):
    response = env.as_(user).get("/api/v1/sharing/invitations")
    assert response.status_code == 200
    return response.json()["invitations"]


def test_invite_accept_and_permissions_apply(env):
    assert env.invite(env.email[env.invitee], diary="view", growth="edit").status_code == 201

    incoming = _incoming(env, env.invitee)
    assert len(incoming) == 1
    assert incoming[0]["child_name"] == "Bé Sharing"
    assert incoming[0]["proposed_permissions"] == {"diary": "view", "growth": "edit"}
    assert _incoming(env, env.outsider) == []

    invitation = incoming[0]["id"]
    assert env.as_(env.outsider).post(f"/api/v1/sharing/invitations/{invitation}/accept").status_code == 404
    accepted = env.as_(env.invitee).post(f"/api/v1/sharing/invitations/{invitation}/accept")
    assert accepted.status_code == 200
    assert _incoming(env, env.invitee) == []

    # Quyền "view" nhật ký: đọc được, không ghi được; người ngoài không thấy hồ sơ
    entries = f"/children/{env.child}/diary/entries"
    assert env.as_(env.invitee).get(entries).status_code == 200
    write = env.as_(env.invitee).put(
        f"{entries}/e1", json={"date": "2026-01-01T10:00:00", "note": "Bé tập đi"}
    )
    assert write.status_code == 403
    assert env.as_(env.outsider).get(entries).status_code == 404

    sharing = env.as_(env.owner).get(f"/api/v1/children/{env.child}/sharing").json()
    assert [m["permissions"] for m in sharing["members"]] == [{"diary": "view", "growth": "edit"}]
    # Chỉ chủ hồ sơ xem / sửa được danh sách chia sẻ
    assert env.as_(env.invitee).get(f"/api/v1/children/{env.child}/sharing").status_code == 404


def test_invitation_for_unregistered_email_is_claimed_after_signup(env):
    email = f"{env.later}@example.test"
    assert env.invite(email, diary="edit").status_code == 201
    env.register_later()

    incoming = _incoming(env, env.later)
    assert [i["proposed_permissions"] for i in incoming] == [{"diary": "edit"}]
    response = env.as_(env.later).post(f"/api/v1/sharing/invitations/{incoming[0]['id']}/accept")
    assert response.status_code == 200


def test_invite_rules(env):
    assert env.invite(env.email[env.owner], diary="view").status_code == 400  # tự mời
    assert env.invite(env.email[env.invitee], diary="view").status_code == 201
    assert env.invite(env.email[env.invitee], diary="edit").status_code == 409  # mời trùng
    assert env.invite("a@example.test", diary="view").status_code == 201
    assert env.invite("b@example.test", diary="view").status_code == 201
    full = env.invite("c@example.test", diary="view")
    assert full.status_code == 409 and "3 vị trí" in full.json()["detail"]
    # Người ngoài không mời được thay chủ hồ sơ
    response = env.as_(env.outsider).post(
        f"/api/v1/children/{env.child}/sharing/invitations",
        json={"email": "d@example.test", "permissions": {"diary": "view"}},
    )
    assert response.status_code == 404


def test_owner_cancels_and_invitee_declines(env):
    first = env.invite(env.email[env.invitee], diary="view").json()["id"]
    cancel = f"/api/v1/children/{env.child}/sharing/invitations/{first}"
    assert env.as_(env.invitee).delete(cancel).status_code == 404  # không phải chủ hồ sơ
    assert env.as_(env.owner).delete(cancel).status_code == 204
    assert _incoming(env, env.invitee) == []
    assert env.as_(env.invitee).post(f"/api/v1/sharing/invitations/{first}/accept").status_code == 404

    second = env.invite(env.email[env.invitee], diary="view").json()["id"]
    assert env.as_(env.invitee).post(f"/api/v1/sharing/invitations/{second}/decline").status_code == 204
    assert _incoming(env, env.invitee) == []
    # Huỷ / từ chối giải phóng vị trí: mời lại được
    assert env.invite(env.email[env.invitee], diary="view").status_code == 201


def test_member_leaves_and_rejoins_with_new_permissions_only(env):
    invitation = env.invite(env.email[env.invitee], diary="edit", growth="edit").json()["id"]
    env.as_(env.invitee).post(f"/api/v1/sharing/invitations/{invitation}/accept")

    leave = f"/api/v1/children/{env.child}/sharing/leave"
    assert env.as_(env.owner).post(leave).status_code == 409  # chủ hồ sơ không rời được
    assert env.as_(env.invitee).post(leave).status_code == 204
    entries = f"/children/{env.child}/diary/entries"
    assert env.as_(env.invitee).get(entries).status_code == 404
    assert env.as_(env.invitee).post(leave).status_code == 404

    again = env.invite(env.email[env.invitee], diary="view").json()["id"]
    env.as_(env.invitee).post(f"/api/v1/sharing/invitations/{again}/accept")
    members = env.as_(env.owner).get(f"/api/v1/children/{env.child}/sharing").json()["members"]
    assert [m["permissions"] for m in members] == [{"diary": "view"}]  # quyền growth cũ không còn


def test_revoked_member_loses_access(env):
    invitation = env.invite(env.email[env.invitee], diary="edit").json()["id"]
    env.as_(env.invitee).post(f"/api/v1/sharing/invitations/{invitation}/accept")
    member = env.as_(env.owner).get(f"/api/v1/children/{env.child}/sharing").json()["members"][0]["id"]

    update = env.as_(env.owner).put(
        f"/api/v1/children/{env.child}/sharing/members/{member}",
        json={"permissions": {"diary": "none"}},
    )
    assert update.status_code == 200
    entries = f"/children/{env.child}/diary/entries"
    assert env.as_(env.invitee).get(entries).status_code == 404

    env.as_(env.owner).put(
        f"/api/v1/children/{env.child}/sharing/members/{member}",
        json={"permissions": {"diary": "view"}},
    )
    assert env.as_(env.invitee).get(entries).status_code == 200
    assert env.as_(env.owner).delete(f"/api/v1/children/{env.child}/sharing/members/{member}").status_code == 204
    assert env.as_(env.invitee).get(entries).status_code == 404
    assert isinstance(UUID(member), UUID)
