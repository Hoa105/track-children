import datetime as dt
import json
import uuid

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.llm.client import Analysis, TransientLLMError
from app.main import app
from app.reviews import prompts
from app.schemas.review import ReviewResult
from tests.conftest import new_insight

TOKEN = "test-internal-token"
HEADERS = {"X-Internal-Token": TOKEN}
CHILD = uuid.uuid4()
RESULT = ReviewResult(
    summary="Qua ba lần quay, bé nhảy tự tin hơn.",
    progress=["Lần đầu bé cần vịn tay, những lần sau bé tự nhảy."],
    keep_practicing=["Tiếp đất nhẹ bằng hai chân."],
    next_steps=["Đặt sợi dây trên sàn để bé nhảy qua.", "Khen bé sau mỗi lần nhảy."],
)


class FakeWriter:
    def __init__(self, error=None):
        self.error = error
        self.calls = []

    def generate_text(self, system, text, schema, result_type, prompt_version):
        self.calls.append(text)
        if self.error:
            raise self.error
        return Analysis(result=RESULT, model="fake-model", prompt_version=prompt_version, usage={})


@pytest.fixture
def writer():
    return FakeWriter()


@pytest.fixture
def client(store, review_store, writer, monkeypatch):
    monkeypatch.setattr(settings, "internal_token", TOKEN)
    monkeypatch.setattr(settings, "worker_enabled", False)
    app.state.insight_store = store
    app.state.review_store = review_store
    app.state.review_writer = writer
    with TestClient(app) as c:
        yield c
    del app.state.insight_store, app.state.review_store, app.state.review_writer


def done(store, days_ago, jumps=None, child=CHILD, group="gross_motor", can_assess=True,
         status="done", activity="g0-9"):
    new = new_insight(group=group)
    new.child_id = child
    new.context.activity.id = activity
    row = store.create(new, "/tmp/clip.mp4")
    evidence = None
    if jumps is not None:
        evidence = {"available": True, "detectionRatio": 0.9,
                    "metrics": [{"key": "jump_count", "label": "Số lần bật nhảy",
                                 "value": jumps, "unit": "lần"}]}
    store.rows[row["id"]].update(
        status=status,
        created_at=dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days_ago),
        evidence=evidence,
        result={"canAssess": can_assess, "observations": [f"Quan sát {days_ago} ngày trước"],
                "comment": "Bé thích thú.", "positives": [], "nextSteps": [],
                "seeSpecialist": False, "specialistNote": ""},
    )
    return row["id"]


def post(client, ids, child=CHILD):
    return client.post("/internal/progress-reviews", headers=HEADERS, json={
        "childId": str(child), "requestedBy": str(uuid.uuid4()), "insightIds": [str(i) for i in ids],
    })


def test_review_summarizes_in_time_order_with_metric_trend(client, store, writer):
    ids = [done(store, 3, jumps=5), done(store, 30, jumps=2), done(store, 14, jumps=3)]
    response = post(client, ids)
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["activityRef"] == "g0-9" and body["activityTitle"] == "Nhảy tại chỗ hai chân"
    assert body["result"]["keepPracticing"] == RESULT.keep_practicing
    assert body["periodFrom"] < body["periodTo"]

    [trend] = body["metrics"]
    assert [p["value"] for p in trend["points"]] == [2, 3, 5]  # cũ → mới
    assert trend["change"] == 3

    data = json.loads(writer.calls[0].split("\n", 1)[1].rsplit("\n", 1)[0])
    sessions = data["cac_lan_quay"]
    assert [s["quan_sat"][0] for s in sessions] == [
        "Quan sát 30 ngày trước", "Quan sát 14 ngày trước", "Quan sát 3 ngày trước"]
    assert sessions[0]["so_do_tu_dong"][0]["gia_tri"] == 2


def test_same_videos_reuse_previous_review(client, store, writer):
    ids = [done(store, 10), done(store, 2)]
    first = post(client, ids).json()
    again = post(client, list(reversed(ids))).json()
    assert again["id"] == first["id"]
    assert len(writer.calls) == 1


def test_other_childs_video_is_not_found(client, store, writer):
    ids = [done(store, 10), done(store, 2, child=uuid.uuid4())]
    assert post(client, ids).status_code == 404
    assert post(client, [done(store, 1), uuid.uuid4()]).status_code == 404
    assert writer.calls == []


@pytest.mark.parametrize("bad", [{"can_assess": False}, {"status": "rejected"}])
def test_rejects_unusable_videos(client, store, writer, bad):
    ids = [done(store, 10), done(store, 2, **bad)]
    assert post(client, ids).status_code == 422
    assert writer.calls == []


def test_needs_two_distinct_videos(client, store):
    one = done(store, 1)
    assert post(client, [one]).status_code == 422
    assert post(client, [one, one]).status_code == 422


def test_mixed_activities_same_group_use_group_title(client, store):
    ids = [done(store, 10, activity="g0-1"), done(store, 2, activity="g0-9")]
    body = post(client, ids).json()
    assert body["activityRef"] is None and body["activityTitle"] == "Nhóm Vận động thô"


def test_all_activities_in_one_review_keep_metrics_apart(client, store, writer):
    ids = [done(store, 20, jumps=2), done(store, 10, jumps=4, activity="g0-1"),
           done(store, 5, group="language", activity="g2-3"), done(store, 1, jumps=5)]
    response = post(client, ids)
    assert response.status_code == 201, response.text
    body = response.json()
    assert body["activityRef"] is None and body["activityGroup"] is None
    assert body["activityTitle"] == "Tất cả hoạt động"
    assert len(body["insightIds"]) == 4
    trends = {t["key"]: [p["value"] for p in t["points"]] for t in body["metrics"]}
    assert trends == {"g0-9:jump_count": [2, 5], "g0-1:jump_count": [4]}

    data = json.loads(writer.calls[0].split("\n", 1)[1].rsplit("\n", 1)[0])
    assert data["pham_vi"] == "Tất cả hoạt động"
    assert len(data["nhom_hoat_dong"]) == 2  # vận động thô + ngôn ngữ


def test_ai_busy_returns_503_and_saves_nothing(client, store, review_store, writer):
    writer.error = TransientLLMError("overloaded")
    assert post(client, [done(store, 10), done(store, 2)]).status_code == 503
    assert review_store.rows == {}


def test_list_get_and_delete_with_child(client, store, review_store):
    review = post(client, [done(store, 10), done(store, 2)]).json()
    listed = client.get(f"/internal/children/{CHILD}/progress-reviews", headers=HEADERS,
                        params={"activity_ref": "g0-9"}).json()
    assert [r["id"] for r in listed] == [review["id"]]
    assert client.get(f"/internal/children/{CHILD}/progress-reviews",
                      headers=HEADERS, params={"activity_ref": "other"}).json() == []
    path = f"/progress-reviews/{review['id']}"
    assert client.get(f"/internal/children/{CHILD}{path}", headers=HEADERS).status_code == 200
    assert client.get(f"/internal/children/{uuid.uuid4()}{path}", headers=HEADERS).status_code == 404

    assert client.delete(f"/internal/children/{CHILD}/video-insights", headers=HEADERS).status_code == 204
    assert review_store.rows == {} and store.rows == {}


def test_requires_internal_token(client):
    assert client.get(f"/internal/children/{CHILD}/progress-reviews").status_code == 401


def test_prompt_marks_specialist_and_parent_note(store):
    row = store.get(done(store, 1))
    row["result"]["seeSpecialist"] = True
    row["result"]["specialistNote"] = "Nên hỏi bác sĩ"
    row["context"]["parentNote"] = " Bé hay ngã "
    text = prompts.review_text([row], "Nhảy")
    assert '"luu_y_chuyen_gia": "Nên hỏi bác sĩ"' in text
    assert '"ghi_chu_ba_me": "Bé hay ngã"' in text
