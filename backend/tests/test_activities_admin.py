"""Chạy với PostgreSQL local đã migrate (scripts/migrate.ps1); không có DB thì bỏ qua."""

import io

import psycopg2
import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.features.activities.admin_service import STATIC_DIR
from app.main import app

ADMIN = {"X-Admin-Role": "content_manager"}
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


@pytest.fixture(scope="module")
def db():
    try:
        conn = psycopg2.connect(settings.database_url, connect_timeout=2)
    except psycopg2.OperationalError:
        pytest.skip("PostgreSQL không chạy")
    yield conn
    conn.close()


def _cleanup(db):
    with db, db.cursor() as cur:
        cur.execute("DELETE FROM activity.activities WHERE title LIKE 'test-%'")
        cur.execute("DELETE FROM activity.activity_groups WHERE code LIKE 'test_%'")


@pytest.fixture
def client(db, monkeypatch):
    monkeypatch.setattr(settings, "dev_auth", True)
    _cleanup(db)
    yield TestClient(app)
    _cleanup(db)


def gross_motor(client) -> int:
    groups = client.get("/admin/activity-groups", headers=ADMIN).json()
    return next(g["id"] for g in groups if g["code"] == "gross_motor")


def new_activity(client, title: str, ages=(0, 3)) -> dict:
    return client.post("/admin/activities", headers=ADMIN, json={
        "title": title, "groupId": gross_motor(client), "ageFromMonths": ages[0], "ageToMonths": ages[1],
    }).json()


def test_requires_activity_permission(client):
    assert client.get("/admin/activities").status_code == 401
    assert client.get("/admin/activities", headers={"X-Admin-Role": "support"}).status_code == 403


def test_list_includes_drafts_with_counts(client):
    rows = client.get("/admin/activities", headers=ADMIN).json()
    assert len(rows) >= 136
    draft = next(r for r in rows if r["title"] == "Phân loại đồ chơi")
    assert draft["status"] == "draft" and draft["stepCount"] == 3 and draft["mediaCount"] == 1
    groups = {g["code"]: g for g in client.get("/admin/activity-groups", headers=ADMIN).json()}
    assert groups["gross_motor"]["activityCount"] == 31
    assert groups["gross_motor"]["publishedCount"] == 30


def test_create_edit_publish_and_hide(client):
    activity = new_activity(client, "test-Bò qua gối", (7, 10))
    assert activity["status"] == "draft" and activity["steps"] == []
    url = f"/admin/activities/{activity['id']}"

    # Chưa có bước / nội dung thì không xuất bản được; tuổi phải hợp lệ
    assert client.patch(url, headers=ADMIN, json={"status": "published"}).status_code == 422
    assert client.patch(url, headers=ADMIN, json={"ageFromMonths": 12}).status_code == 422

    steps = client.put(f"{url}/steps", headers=ADMIN, json={"steps": [
        {"instruction": "Đặt gối"}, {"instruction": "Gọi bé bò qua"},
    ]}).json()["steps"]
    assert [s["number"] for s in steps] == [1, 2]

    published = client.patch(url, headers=ADMIN, json={
        "status": "published", "durationMinutes": 10, "materialItems": ["Gối"], "content": "## Chuẩn bị\n- Gối",
    }).json()
    assert published["status"] == "published" and published["publishedAt"]
    mobile = client.get(f"/activities/{activity['id']}").json()
    assert mobile["durationMinutes"] == 10
    assert mobile["sections"] == [{"title": "Chuẩn bị", "body": "- Gối"}]

    client.patch(url, headers=ADMIN, json={"status": "hidden"})
    assert client.get(f"/activities/{activity['id']}").status_code == 404


def test_steps_are_updated_in_place(client, db):
    activity = new_activity(client, "test-steps")
    url = f"/admin/activities/{activity['id']}/steps"

    def step_ids():
        with db.cursor() as cur:
            cur.execute(
                "SELECT id FROM activity.activity_steps WHERE activity_id = %s ORDER BY step_number",
                (activity["id"],),
            )
            ids = [r[0] for r in cur.fetchall()]
        db.rollback()
        return ids

    client.put(url, headers=ADMIN, json={"steps": [{"instruction": "a"}, {"instruction": "b"}]})
    first = step_ids()[0]
    after = client.put(url, headers=ADMIN, json={"steps": [{"instruction": "a2"}]}).json()["steps"]
    assert [s["instruction"] for s in after] == ["a2"]
    # Giữ id bước: không mất các bước phụ huynh đã đánh dấu trong nhật ký
    assert step_ids() == [first]


def test_upload_set_step_image_and_delete(client):
    activity = new_activity(client, "test-ảnh")
    base = f"/admin/activities/{activity['id']}"
    bad = client.post(f"{base}/media", headers=ADMIN,
                      files={"file": ("x.txt", io.BytesIO(b"hello"), "text/plain")})
    assert bad.status_code == 415

    uploaded = client.post(f"{base}/media", headers=ADMIN, data={"caption": "Bé bò"},
                           files={"file": ("a.png", io.BytesIO(PNG), "image/png")}).json()
    media = uploaded["media"][0]
    assert uploaded["thumbnailUrl"] == media["url"] and media["caption"] == "Bé bò"
    path = STATIC_DIR / media["url"].removeprefix("/static/")
    assert path.read_bytes() == PNG
    assert client.get(media["url"]).status_code == 200

    # Ảnh của bước phải thuộc hoạt động này
    other = client.put(f"{base}/steps", headers=ADMIN, json={"steps": [
        {"instruction": "x", "imageUrl": "/static/activities/g001/main.jpg"}]})
    assert other.status_code == 422
    client.put(f"{base}/steps", headers=ADMIN, json={"steps": [{"instruction": "x", "imageUrl": media["url"]}]})

    renamed = client.patch(f"/admin/activity-media/{media['id']}", headers=ADMIN, json={"caption": "Mới"})
    assert renamed.json()["media"][0]["caption"] == "Mới"

    after = client.delete(f"/admin/activity-media/{media['id']}", headers=ADMIN).json()
    assert after["media"] == [] and after["thumbnailUrl"] is None
    assert after["steps"][0]["imageUrl"] is None
    assert not path.exists()


def test_group_create_and_update(client):
    created = client.post("/admin/activity-groups", headers=ADMIN, json={
        "code": "test_outdoor", "name": "Ngoài trời", "emoji": "🌳", "tintHex": "#E4F3EA",
    })
    assert created.status_code == 201
    group = created.json()
    assert group["detailKind"] == "move" and group["activityCount"] == 0
    duplicate = client.post("/admin/activity-groups", headers=ADMIN, json={"code": "test_outdoor", "name": "x"})
    assert duplicate.status_code == 409
    hidden = client.patch(f"/admin/activity-groups/{group['id']}", headers=ADMIN, json={"isActive": False})
    assert hidden.json()["isActive"] is False
    assert "test_outdoor" not in {g["code"] for g in client.get("/activity-groups").json()}
