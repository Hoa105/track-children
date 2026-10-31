"""Chạy với PostgreSQL local đã migrate (scripts/migrate.ps1); không có DB thì bỏ qua.

MinIO được thay bằng bộ nhớ trong (FakeStorage); xem test_storage_minio.py cho MinIO thật.
"""

import datetime as dt
import uuid

import psycopg2
import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app
from app.seed import demo
from app.shared import storage

MOTHER, FATHER = demo.PARENTS[0][0], demo.PARENTS[1][0]
CHILD = demo.CHILDREN[0][0]  # Bảo An, của mẹ
URL = f"/children/{CHILD}/diary/entries"


class FakeStorage:
    def __init__(self):
        self.objects: dict[str, bytes] = {}
        self.signed_with: list[str] = []

    def put(self, key, data, length, content_type):
        self.objects[key] = data.read()
        assert len(self.objects[key]) == length

    def remove(self, key):
        self.objects.pop(key, None)

    def presign(self, key, base_url):
        self.signed_with.append(base_url)
        return f"{base_url}/diary-media/{key}?sig=1", dt.datetime.now(dt.timezone.utc)


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
        cur.execute("DELETE FROM diary.diary_entries WHERE child_id = %s", (CHILD,))


@pytest.fixture
def files(monkeypatch):
    fake = FakeStorage()
    for name in ("put", "remove", "presign"):
        monkeypatch.setattr(storage, name, getattr(fake, name))
    monkeypatch.setattr(settings, "minio_public_url", "")
    return fake


@pytest.fixture
def client(db, files, monkeypatch):
    monkeypatch.setattr(settings, "dev_auth", True)
    _clear(db)
    yield TestClient(app)
    _clear(db)


def as_user(user: str) -> dict:
    return {"X-User-Id": user}


ENTRY = {
    "date": "2026-10-28T09:15:00.000",
    "note": "Bé tự lật người",
    "mood": "Vui vẻ",
    "domains": ["gross_motor", "social_emotional"],
    "activityId": "g0-lat-nguoi",
    "activityName": "Tập lật",
    "insight": {"id": "00000000-0000-4000-8000-00000000abcd", "status": "pending"},
}


def test_save_list_update_and_delete(client):
    me = as_user(MOTHER)
    saved = client.put(f"{URL}/journal_1", json=ENTRY, headers=me)
    assert saved.status_code == 200, saved.text
    body = saved.json()
    assert body["id"] == "journal_1"
    assert body["date"] == "2026-10-28T09:15:00"
    assert body["domains"] == ["gross_motor", "social_emotional"]
    assert body["media"] == []
    assert body["insight"]["status"] == "pending"

    client.put(f"{URL}/journal_2", json={**ENTRY, "date": "2026-10-29T08:00:00"}, headers=me)
    updated = {**ENTRY, "note": "Bé lật 2 lần", "domains": [], "insight": None}
    assert client.put(f"{URL}/journal_1", json=updated, headers=me).status_code == 200

    entries = client.get(URL, headers=me).json()
    assert [e["id"] for e in entries] == ["journal_2", "journal_1"]
    first = entries[1]
    assert (first["note"], first["domains"], first["insight"]) == ("Bé lật 2 lần", [], None)

    assert client.delete(f"{URL}/journal_1", headers=me).status_code == 204
    assert client.delete(f"{URL}/journal_1", headers=me).status_code == 204  # gọi lại vẫn được
    assert [e["id"] for e in client.get(URL, headers=me).json()] == ["journal_2"]
    # Máy khác còn bản cũ cũng không tạo lại được nhật ký đã xóa
    assert client.put(f"{URL}/journal_1", json=ENTRY, headers=me).status_code == 410


def test_media_upload_signed_url_and_cleanup(client, files):
    me = as_user(MOTHER)
    photo, video = str(uuid.uuid4()), str(uuid.uuid4())
    media = [{"id": video, "type": "video"}, {"id": photo, "type": "image"}]
    client.put(f"{URL}/j_media", json={**ENTRY, "media": media}, headers=me)

    # File chưa tải lên thì chưa hiện
    assert client.get(URL, headers=me).json()[0]["media"] == []
    up = client.put(
        f"{URL}/j_media/media/{photo}",
        files={"file": ("a.jpg", b"jpeg-bytes", "image/jpeg")},
        headers=me,
    )
    assert up.status_code == 200, up.text
    assert up.json()["url"].startswith("http://testserver:9000/diary-media/diary/")
    # Android gửi octet-stream: nhận theo đuôi file; gửi lại cùng id thì ghi đè
    for content in (b"v1", b"video-bytes"):
        r = client.put(
            f"{URL}/j_media/media/{video}",
            files={"file": ("clip.mp4", content, "application/octet-stream")},
            headers=me,
        )
        assert r.status_code == 200, r.text
    assert sorted(files.objects.values()) == [b"jpeg-bytes", b"video-bytes"]

    listed = client.get(URL, headers=me).json()[0]["media"]
    assert [(m["id"], m["type"], m["sizeBytes"]) for m in listed] == [
        (video, "video", 11),
        (photo, "image", 10),
    ]
    fresh = client.get(f"{URL}/j_media/media/{video}/url", headers=me)
    assert fresh.status_code == 200 and fresh.json()["url"].endswith(".mp4?sig=1")
    # Máy thật gọi backend qua IP LAN → link tải cũng dùng IP đó
    client.get(URL, headers={**me, "Host": "192.168.1.5:8000"})
    assert files.signed_with[-1] == "http://192.168.1.5:9000"

    # Bỏ ảnh khỏi nhật ký → xóa file; xóa nhật ký → xóa nốt video
    client.put(f"{URL}/j_media", json={**ENTRY, "media": [media[0]]}, headers=me)
    assert list(files.objects.values()) == [b"video-bytes"]
    client.delete(f"{URL}/j_media", headers=me)
    assert files.objects == {}


def test_media_rejects_bad_uploads(client, monkeypatch):
    me = as_user(MOTHER)
    media_id = str(uuid.uuid4())
    upload = {"file": ("a.jpg", b"x", "image/jpeg")}
    # Chưa lưu nhật ký
    assert client.put(f"{URL}/none/media/{media_id}", files=upload, headers=me).status_code == 404
    client.put(f"{URL}/j_bad", json=ENTRY, headers=me)
    text = {"file": ("a.txt", b"x", "text/plain")}
    assert client.put(f"{URL}/j_bad/media/{media_id}", files=text, headers=me).status_code == 415
    monkeypatch.setattr(settings, "diary_image_max_mb", 0)
    assert client.put(f"{URL}/j_bad/media/{media_id}", files=upload, headers=me).status_code == 413
    # Bố không có quyền với bé của mẹ
    assert client.put(f"{URL}/j_bad/media/{media_id}", files=upload, headers=as_user(FATHER)).status_code == 404


def test_library_activity_is_linked(client, db):
    with db.cursor() as cur:
        cur.execute("SELECT id::text FROM activity.activities WHERE status = 'published' LIMIT 1")
        activity_id = cur.fetchone()[0]
    client.put(f"{URL}/journal_lib", json={**ENTRY, "activityId": activity_id}, headers=as_user(MOTHER))
    with db.cursor() as cur:
        cur.execute("SELECT activity_id::text, activity_ref FROM diary.diary_entries WHERE client_ref = 'journal_lib'")
        assert cur.fetchone() == (activity_id, activity_id)


def test_rejects_other_parent_and_bad_domain(client):
    assert client.get(URL, headers=as_user(FATHER)).status_code == 404
    assert client.put(f"{URL}/x", json=ENTRY, headers=as_user(FATHER)).status_code == 404
    bad = client.put(f"{URL}/x", json={**ENTRY, "domains": ["music"]}, headers=as_user(MOTHER))
    assert bad.status_code == 422
