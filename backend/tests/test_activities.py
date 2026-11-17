"""Chạy với PostgreSQL local đã migrate (scripts/migrate.ps1); không có DB thì bỏ qua."""

import psycopg2
import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.features.activities.service import parse_sections
from app.main import app
from app.seed import demo
from tests.jwt_auth import JwtAuth

MOTHER, FATHER = demo.PARENTS[0][0], demo.PARENTS[1][0]
AN, LINH = demo.CHILDREN[0][0], demo.CHILDREN[1][0]  # 2 bé của mẹ
_auth: JwtAuth


@pytest.fixture(scope="module")
def db():
    try:
        conn = psycopg2.connect(settings.database_url, connect_timeout=2)
    except psycopg2.OperationalError:
        pytest.skip("PostgreSQL không chạy")
    demo.seed()
    yield conn
    conn.close()


def _clear(db):
    with db, db.cursor() as cur:
        cur.execute("DELETE FROM activity.child_activity_progress WHERE child_id IN (%s, %s)", (AN, LINH))
        cur.execute("DELETE FROM activity.activity_favorites WHERE user_id IN (%s, %s)", (MOTHER, FATHER))


@pytest.fixture
def client(db, monkeypatch):
    global _auth
    _auth = JwtAuth(db, monkeypatch)
    _clear(db)
    yield TestClient(app)
    _clear(db)
    _auth.close()


def as_user(user: str) -> dict:
    return _auth.user(user)


def first_id(client, title: str) -> str:
    return next(a["id"] for a in client.get("/activities").json() if a["title"] == title)


def test_groups_count_published_activities(client):
    groups = {g["code"]: g for g in client.get("/activity-groups").json()}
    assert groups["gross_motor"]["activityCount"] == 30  # 31 trò, "Bạn lật đật nhỏ" còn draft
    assert groups["fine_motor"]["activityCount"] == 25
    assert groups["music"]["activityCount"] == 0


def test_list_hides_drafts_and_filters(client):
    items = client.get("/activities").json()
    titles = {a["title"] for a in items}
    assert len(items) == 130
    assert "Massage cho bé" in titles
    assert "Phân loại đồ chơi" not in titles  # draft: scan thiếu trang
    newborn = client.get("/activities", params={"ageMonths": 1, "group": "gross_motor"}).json()
    assert [a["title"] for a in newborn] == ["Dùng chân đá, đá, đá..."]


def test_detail_has_steps_images_and_sections(client):
    massage = next(a for a in client.get("/activities").json() if a["title"] == "Massage cho bé")
    detail = client.get(f"/activities/{massage['id']}").json()
    assert detail["thumbnailUrl"] == "/static/activities/g001/main.jpg"
    assert [s["number"] for s in detail["steps"]] == [1, 2, 3, 4]
    assert detail["steps"][0]["imageUrl"] == "/static/activities/g001/step-1.jpg"
    assert [s["title"] for s in detail["sections"]] == ["Chuẩn bị", "Hướng dẫn của chuyên gia"]
    assert len(detail["media"]) == 5
    assert client.get(detail["thumbnailUrl"]).status_code == 200


def test_unknown_activity_is_404(client):
    assert client.get("/activities/00000000-0000-0000-0000-000000000000").status_code == 404


def test_parse_sections_drops_steps_quote_and_source():
    content = (
        "**Kỹ năng phát triển:** A\n\n## Chuẩn bị\n- x\n\n## Các bước thực hiện\n1. y\n\n"
        "## Hướng dẫn của chuyên gia\n- z\n\n> chú thích\n\n_Nguồn: sách._"
    )
    assert parse_sections(content) == [
        {"title": "Chuẩn bị", "body": "- x"},
        {"title": "Hướng dẫn của chuyên gia", "body": "- z"},
    ]


def test_progress_is_per_child(client):
    massage = first_id(client, "Massage cho bé")
    url = f"/children/{AN}/activity-progress/{massage}"
    saved = client.put(url, json={"done": True}, headers=as_user(MOTHER)).json()
    assert [p["activityId"] for p in saved] == [massage] and saved[0]["status"] == "done"
    assert saved[0]["completedAt"]
    # Bé 2 không bị ảnh hưởng
    assert client.get(f"/children/{LINH}/activity-progress", headers=as_user(MOTHER)).json() == []
    # Đánh dấu lại không đổi thời điểm hoàn thành
    again = client.put(url, json={"done": True}, headers=as_user(MOTHER)).json()
    assert again[0]["completedAt"] == saved[0]["completedAt"]
    assert client.put(url, json={"done": False}, headers=as_user(MOTHER)).json() == []


def test_progress_requires_access_and_published_activity(client):
    massage = first_id(client, "Massage cho bé")
    stranger = client.put(
        f"/children/{AN}/activity-progress/{massage}", json={"done": True}, headers=as_user(FATHER)
    )
    assert stranger.status_code == 404
    draft = "00000000-0000-0000-0000-000000000000"
    missing = client.put(
        f"/children/{AN}/activity-progress/{draft}", json={"done": True}, headers=as_user(MOTHER)
    )
    assert missing.status_code == 404
    assert client.get(f"/children/{AN}/activity-progress").status_code == 401


def test_favorites_are_per_parent(client):
    massage = first_id(client, "Massage cho bé")
    assert client.put(f"/me/activity-favorites/{massage}", headers=as_user(MOTHER)).json() == [massage]
    assert client.put(f"/me/activity-favorites/{massage}", headers=as_user(MOTHER)).json() == [massage]
    assert client.get("/me/activity-favorites", headers=as_user(FATHER)).json() == []
    assert client.delete(f"/me/activity-favorites/{massage}", headers=as_user(MOTHER)).json() == []
