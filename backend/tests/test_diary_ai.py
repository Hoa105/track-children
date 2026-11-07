"""Diary video insights: backend checks + forwarding to ai-service (no database needed)."""

import datetime as dt
import io
import json
import uuid

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.core.database import get_db
from app.features.auth.dependencies import current_user_id
from app.features.diary_ai import criteria, router as diary_router, service
from app.main import app
from app.shared.clients import ai_service

USER = uuid.uuid4()
CHILD = uuid.uuid4()
ACTIVITY = {
    "id": "g0-9",
    "title": "Nhảy tại chỗ hai chân",
    "group": "gross_motor",
    "ageFromMonths": 20,
    "ageToMonths": 30,
    "guide": [{"title": "Cùng bé thực hiện", "text": "Ba mẹ làm mẫu."}],
}


class FakeConn:
    """Chỉ trả activity.activities.kdst_item cho hoạt động lấy từ DB."""

    kdst_items: dict[str, str] = {}

    def rollback(self):
        pass

    def cursor(self):
        conn = self

        class Cursor:
            def __enter__(self):
                return self

            def __exit__(self, *exc):
                return False

            def execute(self, sql, params):
                self.activity_id = params[0]

            def fetchone(self):
                item = conn.kdst_items.get(self.activity_id)
                return {"kdst_item": item} if self.activity_id in conn.kdst_items else None

        return Cursor()


@pytest.fixture
def calls(monkeypatch):
    calls = {"access": [], "create": [], "get": []}

    def access(conn, child_id, user_id, scope, level):
        calls["access"].append((child_id, user_id, scope, level))
        return {"id": child_id, "date_of_birth": dt.date.today() - dt.timedelta(days=730)}

    def create(video, filename, content_type, meta):
        calls["create"].append({"bytes": video.read(), "filename": filename,
                                "content_type": content_type, "meta": json.loads(meta)})
        return insight()

    def get(insight_id):
        calls["get"].append(insight_id)
        return insight(id=insight_id)

    monkeypatch.setattr(diary_router, "require_child_access", access)
    monkeypatch.setattr(ai_service, "create_video_insight", create)
    monkeypatch.setattr(ai_service, "get_video_insight", get)
    app.dependency_overrides[get_db] = lambda: FakeConn()
    app.dependency_overrides[current_user_id] = lambda: USER
    yield calls
    app.dependency_overrides.clear()


def insight(id=None, child=CHILD, **extra):
    return {"id": str(id or uuid.uuid4()), "childId": str(child), "activityRef": "g0-9",
            "status": "pending", "createdAt": dt.datetime.now(dt.timezone.utc).isoformat(), **extra}


def post(activity=ACTIVITY, consent="true", filename="clip.mp4", content_type="video/mp4"):
    return TestClient(app).post(
        f"/children/{CHILD}/diary/video-insights",
        data={"activity": json.dumps(activity), "consent": consent, "note": " Bé hơi ngại "},
        files={"video": (filename, io.BytesIO(b"fake-video"), content_type)},
    )


def test_create_forwards_video_with_criteria_and_metrics(calls):
    response = post()
    assert response.status_code == 202, response.text
    assert response.json()["status"] == "pending"
    assert calls["access"] == [(CHILD, USER, "diary", "edit")]
    sent = calls["create"][0]
    assert sent["bytes"] == b"fake-video"
    meta = sent["meta"]
    assert meta["childId"] == str(CHILD) and meta["requestedBy"] == str(USER)
    context = meta["context"]
    assert context["criteria"]["name"] == "Vận động thô"
    assert context["metrics"] == ["jump_count"]
    assert context["childAgeMonths"] in (23, 24)
    assert context["parentNote"] == "Bé hơi ngại"
    assert context["activity"]["guide"][0]["title"] == "Cùng bé thực hiện"


def test_kdst_item_from_db_is_forwarded(calls, monkeypatch):
    activity_id = str(uuid.uuid4())
    monkeypatch.setattr(FakeConn, "kdst_items", {activity_id: "B01"})
    assert post(activity={**ACTIVITY, "id": activity_id}).status_code == 202
    assert calls["create"][0]["meta"]["context"]["activity"]["kdstItem"] == "B01"


def test_kdst_item_none_for_bundled_or_non_motor_activities(calls, monkeypatch):
    activity_id = str(uuid.uuid4())
    monkeypatch.setattr(FakeConn, "kdst_items", {activity_id: "B01"})
    post()  # id dạng g0-9: không tra DB
    post(activity={**ACTIVITY, "id": activity_id, "group": "language"})
    assert [c["meta"]["context"]["activity"]["kdstItem"] for c in calls["create"]] == [None, None]


def test_requires_consent(calls):
    response = post(consent="false")
    assert response.status_code == 422
    assert calls["create"] == []


def test_rejects_unknown_group_and_non_video(calls):
    assert post(activity={**ACTIVITY, "group": "cooking"}).status_code == 422
    assert post(filename="photo.jpg", content_type="image/jpeg").status_code == 415
    # Android có thể gửi octet-stream: chấp nhận khi đuôi là video
    assert post(filename="clip.mov", content_type="application/octet-stream").status_code == 202


def test_get_checks_child_matches(calls, monkeypatch):
    insight_id = uuid.uuid4()
    client = TestClient(app)
    url = f"/children/{CHILD}/diary/video-insights/{insight_id}"
    response = client.get(url)
    assert response.status_code == 200 and response.json()["id"] == str(insight_id)
    assert calls["access"][-1][3] == "view"

    monkeypatch.setattr(ai_service, "get_video_insight", lambda i: insight(id=i, child=uuid.uuid4()))
    assert client.get(url).status_code == 404


def test_ai_service_down_returns_503(calls, monkeypatch):
    def down(*args):
        raise ai_service.AiServiceError(503, "Dịch vụ AI tạm thời không khả dụng")

    monkeypatch.setattr(ai_service, "create_video_insight", down)
    assert post().status_code == 503


def test_metrics_only_for_motor_groups():
    assert criteria.metrics_for("g2-3", "language") == []
    assert criteria.metrics_for("g0-99", "gross_motor") == criteria.DEFAULT_METRICS["gross_motor"]
    assert criteria.metrics_for("g1-2", "fine_motor") == ["pinch_count", "hand_visible_seconds"]
    assert set(criteria.GROUPS) == set(service.ActivityInfo.model_fields["group"].annotation.__args__)


def test_age_in_months():
    assert service.age_in_months(dt.date(2024, 5, 20), dt.date(2026, 5, 19)) == 23
    assert service.age_in_months(dt.date(2024, 5, 20), dt.date(2026, 5, 20)) == 24
    assert service.age_in_months(dt.date(2026, 6, 1), dt.date(2026, 5, 1)) == 0


def review(**extra):
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    return {"id": str(uuid.uuid4()), "childId": str(CHILD), "activityRef": "g0-9",
            "activityGroup": "gross_motor", "activityTitle": "Nhảy tại chỗ hai chân",
            "insightIds": [str(uuid.uuid4()), str(uuid.uuid4())], "periodFrom": now, "periodTo": now,
            "result": {"summary": "Bé nhảy tự tin hơn.", "progress": ["Tự nhảy không cần vịn"]},
            "metrics": [], "createdAt": now, **extra}


def test_progress_review_forwards_child_user_and_videos(calls, monkeypatch):
    sent = []
    monkeypatch.setattr(ai_service, "create_progress_review", lambda body: sent.append(body) or review())
    ids = [str(uuid.uuid4()), str(uuid.uuid4())]
    response = TestClient(app).post(f"/children/{CHILD}/diary/progress-reviews", json={"insightIds": ids})
    assert response.status_code == 201, response.text
    assert response.json()["result"]["keepPracticing"] == []
    assert "childId" not in response.json()
    assert sent == [{"childId": str(CHILD), "requestedBy": str(USER), "insightIds": ids}]
    assert calls["access"][-1][3] == "edit"


def test_progress_review_needs_two_videos(calls):
    response = TestClient(app).post(f"/children/{CHILD}/diary/progress-reviews",
                                    json={"insightIds": [str(uuid.uuid4())]})
    assert response.status_code == 422


def test_progress_review_errors_pass_through(calls, monkeypatch):
    def busy(body):
        raise ai_service.AiServiceError(503, "AI đang bận, ba mẹ thử lại sau ít phút nhé")

    monkeypatch.setattr(ai_service, "create_progress_review", busy)
    response = TestClient(app).post(f"/children/{CHILD}/diary/progress-reviews",
                                    json={"insightIds": [str(uuid.uuid4()), str(uuid.uuid4())]})
    assert response.status_code == 503 and "AI đang bận" in response.json()["detail"]


def test_progress_review_list_and_get(calls, monkeypatch):
    asked = []
    monkeypatch.setattr(ai_service, "list_progress_reviews",
                        lambda child, ref: asked.append((child, ref)) or [review()])
    monkeypatch.setattr(ai_service, "get_progress_review", lambda child, rid: None)
    client = TestClient(app)
    listed = client.get(f"/children/{CHILD}/diary/progress-reviews", params={"activityRef": "g0-9"})
    assert listed.status_code == 200 and len(listed.json()) == 1
    assert asked == [(CHILD, "g0-9")] and calls["access"][-1][3] == "view"
    assert client.get(f"/children/{CHILD}/diary/progress-reviews/{uuid.uuid4()}").status_code == 404


def test_progress_review_across_all_activities(calls, monkeypatch):
    monkeypatch.setattr(ai_service, "create_progress_review",
                        lambda body: review(activityRef=None, activityGroup=None,
                                            activityTitle="Tất cả hoạt động"))
    ids = [str(uuid.uuid4()) for _ in range(30)]
    response = TestClient(app).post(f"/children/{CHILD}/diary/progress-reviews", json={"insightIds": ids})
    assert response.status_code == 201, response.text
    assert response.json()["activityGroup"] is None
