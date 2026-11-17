import dataclasses
from pathlib import Path

import numpy as np
import pytest

from app.insights import service
from app.kdst import scorer, templates
from app.kdst.items import ITEMS
from app.pose.metrics import PoseSeries
from tests.conftest import new_insight, write_video
from tests.test_service import OPTIONS, RESULT, FakeAnalyzer

MODEL = Path(__file__).resolve().parents[1] / "models" / "kdst" / "kdst_v1.onnx"


def standing_child(frames=40) -> np.ndarray:
    """(T, 33, 3) MediaPipe: bé đứng yên giữa khung, lắc nhẹ."""
    kp = np.zeros((33, 3))
    kp[:, 2] = 0.9
    points = {
        0: (0.50, 0.20), 2: (0.49, 0.18), 5: (0.51, 0.18), 7: (0.47, 0.19), 8: (0.53, 0.19),
        11: (0.45, 0.30), 12: (0.55, 0.30), 13: (0.43, 0.40), 14: (0.57, 0.40),
        15: (0.42, 0.50), 16: (0.58, 0.50), 23: (0.47, 0.52), 24: (0.53, 0.52),
        25: (0.47, 0.68), 26: (0.53, 0.68), 27: (0.47, 0.84), 28: (0.53, 0.84),
        29: (0.46, 0.86), 30: (0.54, 0.86), 31: (0.49, 0.87), 32: (0.51, 0.87),
    }
    for i, xy in points.items():
        kp[i, :2] = xy
    seq = np.repeat(kp[None], frames, axis=0)
    seq[:, :, 0] += 0.01 * np.sin(np.linspace(0, 6, frames))[:, None]
    return seq


# ---------------------------------------------------------------------
# Model ONNX
# ---------------------------------------------------------------------
@pytest.fixture(scope="module")
def kdst():
    if not MODEL.is_file():
        pytest.skip("chưa có models/kdst/kdst_v1.onnx")
    pytest.importorskip("onnxruntime")
    return scorer.KdstScorer(MODEL)


def test_scorer_returns_level_and_item(kdst):
    a = kdst.assess(standing_child(), "B01")
    assert a.model_version == "kdst_v1" and a.item == "B01"
    assert a.level in ("not_yet", "unsteady", "steady")
    assert 0 <= a.confidence <= 1 and 0 <= a.item_confidence <= 1
    assert a.predicted_item in {i.code for i in ITEMS}
    assert a.confident == (a.reason == "")


def test_scorer_no_body(kdst):
    empty = np.full((20, 33, 3), np.nan)
    a = kdst.assess(empty, "A01")
    assert a.reason == scorer.NO_BODY and not a.confident and a.level is None


def test_load_missing_model_returns_none(tmp_path):
    assert scorer.load(str(tmp_path / "none.onnx")) is None


# ---------------------------------------------------------------------
# Nhận xét mẫu
# ---------------------------------------------------------------------
def assessment(level="steady", item="B01", reason=""):
    return scorer.KdstAssessment(model_version="kdst_test", item=item, level=level,
                                 confidence=0.9, predicted_item=item, item_confidence=0.9, reason=reason)


@pytest.mark.parametrize("item", [i.code for i in ITEMS])
@pytest.mark.parametrize("level", ["not_yet", "unsteady", "steady"])
def test_every_item_and_level_has_text(item, level):
    r = templates.render(assessment(level, item), child_age_months=48)
    assert r.can_assess and r.observations[0] and r.next_steps and r.positives
    assert templates.DISCLAIMER in r.comment


def test_specialist_only_when_older_than_item_age():
    # B01: 36–53 tháng
    assert templates.render(assessment("not_yet"), 60).see_specialist
    assert templates.render(assessment("not_yet"), 60).specialist_note
    assert not templates.render(assessment("not_yet"), 45).see_specialist
    assert not templates.render(assessment("unsteady"), 60).see_specialist


def test_younger_child_is_reassured():
    r = templates.render(assessment("not_yet"), 30)
    assert "từ 36 tháng" in r.comment and not r.see_specialist


def test_watch_signs_follow_item_age():
    # B01: 36–53 tháng
    assert "60 tháng" in templates.render(assessment("not_yet"), 60).watch_signs[0]
    assert "2–4 tuần" in templates.render(assessment("not_yet"), 45).watch_signs[0]
    assert templates.render(assessment("not_yet"), 30).watch_signs == []  # chưa tới tuổi
    assert templates.render(assessment("unsteady"), 60).watch_signs
    assert templates.render(assessment("unsteady"), 45).watch_signs == []
    assert templates.render(assessment("steady"), 60).watch_signs == []


def unsure(item="A01", reason=scorer.OTHER_ITEM, predicted="B02"):
    return scorer.KdstAssessment(model_version="kdst_test", item=item, level="unsteady", confidence=0.7,
                                 predicted_item=predicted, item_confidence=0.4, reason=reason)


def test_uncertain_gives_reason_and_filming_guide():
    r = templates.uncertain(unsure(), seconds=10)
    assert not r.can_assess
    assert "Chưa chấm được bài “Đi lên cầu thang”" in r.video_issue
    assert "Nhảy lò cò" in r.video_issue  # bài model nhầm sang
    assert "chân cầu thang" in r.next_steps[0]  # vị trí đặt máy riêng cho bài
    assert any("cố định" in s for s in r.next_steps)


def test_diagnose_camera_following_child():
    reasons = templates.diagnose(unsure(), seconds=13, visible_ratio=0.99, hip_shift=0.3)
    assert len(reasons) == 1 and "máy quay đi theo bé" in reasons[0]


def test_diagnose_stairs_direction_flipped():
    reasons = templates.diagnose(unsure(predicted="A02"), seconds=10, visible_ratio=0.9, hip_shift=1.6)
    assert "đi xuống cầu thang" in reasons[0]


def test_diagnose_short_and_partly_hidden():
    reasons = templates.diagnose(unsure(reason=scorer.LOW_CONFIDENCE, predicted="A01"),
                                 seconds=3.3, visible_ratio=0.74, hip_shift=3.1)
    assert "3 giây" in reasons[0] and "không thấy bé" in reasons[1]


def test_diagnose_no_body_only_says_not_visible():
    reasons = templates.diagnose(scorer.KdstAssessment(model_version="kdst_test", item="A01",
                                                       reason=scorer.NO_BODY),
                                 seconds=10, visible_ratio=0.2, hip_shift=None)
    assert len(reasons) == 1 and "toàn thân" in reasons[0]


def test_diagnose_falls_back_to_generic_reason():
    reasons = templates.diagnose(unsure(item="B01", reason=scorer.LOW_CONFIDENCE, predicted="B01"),
                                 seconds=10, visible_ratio=1.0, hip_shift=0.1)
    assert len(reasons) == 1 and "chưa đủ rõ" in reasons[0]  # B01 đứng tại chỗ: không trách máy quay


@pytest.mark.parametrize("item", [i.code for i in ITEMS])
def test_every_item_has_filming_guide(item):
    assert len(templates.filming_guide(item)) == 4


# ---------------------------------------------------------------------
# Luồng xử lý job
# ---------------------------------------------------------------------
class FakeScorer:
    version = "kdst_test"

    def __init__(self, result):
        self.result = result
        self.calls = []

    def unusable(self, item, reason):
        return scorer.KdstAssessment(model_version=self.version, item=item, reason=reason)

    def assess(self, keypoints, item):
        self.calls.append(item)
        return dataclasses.replace(self.result, item=item)


@pytest.fixture
def kdst_options(tmp_path, monkeypatch):
    """Pose model 'có sẵn' + extract_pose trả bé đứng yên (không chạy MediaPipe thật)."""
    pose_model = tmp_path / "pose.task"
    pose_model.write_bytes(b"x")
    from app.pose import landmarks

    monkeypatch.setattr(
        landmarks, "extract_pose",
        lambda *a: PoseSeries(t=np.arange(40) / 10, kp=standing_child()),
    )

    def make(result, fallback=True):
        return dataclasses.replace(
            OPTIONS,
            pose_models=dataclasses.replace(OPTIONS.pose_models, pose_model_path=str(pose_model)),
            kdst=FakeScorer(result),
            kdst_llm_fallback=fallback,
        )

    return make


def queue(store, tmp_path, **kwargs):
    path = write_video(tmp_path / "v.mp4", seconds=4)
    store.create(new_insight(**kwargs), str(path))
    return store.claim_next(), path


def test_confident_model_skips_llm(store, tmp_path, kdst_options):
    job, path = queue(store, tmp_path, kdst_item="B01", metrics=["standing_seconds"])
    options = kdst_options(assessment("unsteady"))
    analyzer = FakeAnalyzer()
    service.process(job, store, analyzer, options)

    row = store.get(job["id"])
    assert row["status"] == "done" and analyzer.calls == []
    assert row["result"]["canAssess"] and "Đứng một chân" in row["result"]["positives"][0]
    assert row["model"] == "kdst_test" and row["prompt_version"] == templates.VERSION
    assert row["kdst_assessment"]["level"] == "unsteady"
    assert row["evidence"]["metrics"][0]["key"] == "standing_seconds"  # dùng lại khung xương
    assert not Path(path).exists()


def test_unsure_model_falls_back_to_llm(store, tmp_path, kdst_options):
    job, _ = queue(store, tmp_path, kdst_item="B01", metrics=[])
    options = kdst_options(assessment(reason=scorer.LOW_CONFIDENCE))
    analyzer = FakeAnalyzer()
    service.process(job, store, analyzer, options)

    row = store.get(job["id"])
    assert row["status"] == "done" and len(analyzer.calls) == 1
    assert row["result"]["nextSteps"] == RESULT.next_steps
    assert row["kdst_assessment"]["reason"] == scorer.LOW_CONFIDENCE


def test_unsure_model_without_fallback_asks_to_record_again(store, tmp_path, kdst_options):
    job, _ = queue(store, tmp_path, kdst_item="B01", metrics=[])
    options = kdst_options(assessment(reason=scorer.OTHER_ITEM), fallback=False)
    analyzer = FakeAnalyzer()
    service.process(job, store, analyzer, options)

    row = store.get(job["id"])
    assert row["status"] == "done" and analyzer.calls == []
    assert not row["result"]["canAssess"] and row["result"]["videoIssue"]


def test_activity_without_kdst_item_uses_llm(store, tmp_path, kdst_options):
    job, _ = queue(store, tmp_path, metrics=[])
    options = kdst_options(assessment())
    analyzer = FakeAnalyzer()
    service.process(job, store, analyzer, options)
    assert len(analyzer.calls) == 1 and options.kdst.calls == []
    assert store.get(job["id"])["kdst_assessment"] is None
