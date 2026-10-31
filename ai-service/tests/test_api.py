import uuid

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app
from tests.conftest import new_insight, write_video

TOKEN = "test-internal-token"


@pytest.fixture
def client(store, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "internal_token", TOKEN)
    monkeypatch.setattr(settings, "worker_enabled", False)
    monkeypatch.setattr(settings, "video_dir", str(tmp_path / "videos"))
    app.state.insight_store = store
    with TestClient(app) as c:
        yield c
    del app.state.insight_store


def post(client, tmp_path, headers=None, meta=None):
    video = write_video(tmp_path / "clip.mp4", seconds=3)
    with video.open("rb") as f:
        return client.post(
            "/internal/video-insights",
            headers={"X-Internal-Token": TOKEN} if headers is None else headers,
            data={"meta": meta or new_insight().model_dump_json(by_alias=True)},
            files={"video": ("clip.mp4", f, "video/mp4")},
        )


def test_create_then_get(client, store, tmp_path):
    created = post(client, tmp_path)
    assert created.status_code == 202, created.text
    body = created.json()
    assert body["status"] == "pending" and body["activityRef"] == "g0-9"
    row = store.get(uuid.UUID(body["id"]))
    assert row["video_path"].endswith(".mp4")

    fetched = client.get(f"/internal/video-insights/{body['id']}", headers={"X-Internal-Token": TOKEN})
    assert fetched.status_code == 200 and fetched.json()["id"] == body["id"]


def test_requires_internal_token(client, tmp_path):
    assert post(client, tmp_path, headers={}).status_code == 401
    assert post(client, tmp_path, headers={"X-Internal-Token": "wrong"}).status_code == 401


def test_rejects_invalid_meta(client, tmp_path):
    assert post(client, tmp_path, meta='{"childId": "x"}').status_code == 422


def test_rejects_oversized_video(client, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "max_video_bytes", 100)
    assert post(client, tmp_path).status_code == 413
    assert list((tmp_path / "videos").iterdir()) == []


def test_unknown_insight_404(client):
    response = client.get(f"/internal/video-insights/{uuid.uuid4()}", headers={"X-Internal-Token": TOKEN})
    assert response.status_code == 404


def test_delete_child_removes_rows_and_files(client, store, tmp_path):
    body = post(client, tmp_path).json()
    row = store.get(uuid.UUID(body["id"]))
    response = client.delete(f"/internal/children/{row['child_id']}/video-insights",
                             headers={"X-Internal-Token": TOKEN})
    assert response.status_code == 204
    assert store.rows == {}
    assert list((tmp_path / "videos").iterdir()) == []
