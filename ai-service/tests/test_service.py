from pathlib import Path

import pytest

from app.insights import service
from app.llm.client import Analysis, LLMError, TransientLLMError
from app.pose.evidence import PoseModels
from app.schemas.insight import Evidence, EvidenceMetric, InsightResult
from tests.conftest import new_insight, write_video

OPTIONS = service.ProcessOptions(
    max_frames=6,
    frame_max_side=160,
    min_seconds=2,
    max_seconds=90,
    max_attempts=3,
    pose_enabled=True,
    pose_models=PoseModels("missing.task", "missing.task", 10),
)

RESULT = InsightResult(
    can_assess=True,
    observations=["Bé đứng vững, hai tay dang ngang."],
    comment="Bé rất hào hứng.",
    positives=["Bé thử nhiều lần"],
    next_steps=["Ba mẹ đếm 1-2-3 rồi cùng nhảy với bé."],
)


class FakeAnalyzer:
    def __init__(self, error=None):
        self.error = error
        self.calls = []

    def analyze(self, context, frames, duration_seconds, quality_notes, evidence):
        self.calls.append({"frames": frames, "evidence": evidence, "notes": quality_notes})
        if self.error:
            raise self.error
        return Analysis(result=RESULT, model="claude-test", prompt_version="v-test",
                        usage={"input_tokens": 1, "output_tokens": 1})


@pytest.fixture
def fake_evidence(monkeypatch):
    calls = []

    def measure(path, info, keys, models):
        calls.append(keys)
        return Evidence(available=True, detection_ratio=0.9,
                        metrics=[EvidenceMetric(key="jump_count", label="Số lần bật nhảy", value=3, unit="lần")])

    monkeypatch.setattr(service.pose_evidence, "measure", measure)
    return calls


def queue(store, tmp_path, seconds=4, **kwargs):
    path = write_video(tmp_path / "v.mp4", seconds=seconds)
    store.create(new_insight(**kwargs), str(path))
    return store.claim_next(), path


def test_done_saves_result_evidence_and_deletes_video(store, tmp_path, fake_evidence):
    job, path = queue(store, tmp_path)
    analyzer = FakeAnalyzer()
    service.process(job, store, analyzer, OPTIONS)

    row = store.get(job["id"])
    assert row["status"] == "done"
    assert row["result"]["nextSteps"] == RESULT.next_steps
    assert row["evidence"]["metrics"][0]["value"] == 3
    assert row["video_path"] is None and not Path(path).exists()
    assert len(analyzer.calls[0]["frames"]) == 6
    assert fake_evidence == [["jump_count"]]
    assert analyzer.calls[0]["evidence"].available


def test_non_motor_group_skips_pose(store, tmp_path, fake_evidence):
    job, _ = queue(store, tmp_path, group="language", metrics=[])
    analyzer = FakeAnalyzer()
    service.process(job, store, analyzer, OPTIONS)
    assert store.get(job["id"])["status"] == "done"
    assert fake_evidence == []
    assert analyzer.calls[0]["evidence"] is None


def test_short_video_rejected_without_calling_ai(store, tmp_path, fake_evidence):
    job, path = queue(store, tmp_path, seconds=1)
    analyzer = FakeAnalyzer()
    service.process(job, store, analyzer, OPTIONS)
    row = store.get(job["id"])
    assert row["status"] == "rejected" and "quá ngắn" in row["message"]
    assert analyzer.calls == [] and not Path(path).exists()


def test_transient_error_retries_then_fails(store, tmp_path, fake_evidence):
    job, path = queue(store, tmp_path)
    analyzer = FakeAnalyzer(TransientLLMError("529 overloaded"))

    service.process(job, store, analyzer, OPTIONS)
    row = store.get(job["id"])
    assert row["status"] == "pending" and row["run_after"] > job["created_at"]
    assert Path(path).exists()  # giữ video để thử lại

    for attempt in (2, 3):
        store.rows[job["id"]]["run_after"] = job["created_at"]
        job = store.claim_next()
        assert job["attempts"] == attempt
        service.process(job, store, analyzer, OPTIONS)
    row = store.get(job["id"])
    assert row["status"] == "failed" and row["message"] == service.FAILED_MESSAGE
    assert not Path(path).exists()


def test_permanent_llm_error_fails_immediately(store, tmp_path, fake_evidence):
    job, path = queue(store, tmp_path)
    service.process(job, store, FakeAnalyzer(LLMError("refusal")), OPTIONS)
    row = store.get(job["id"])
    assert row["status"] == "failed" and row["error"] == "refusal"
    assert not Path(path).exists()


def test_missing_file_fails(store, tmp_path):
    store.create(new_insight(), str(tmp_path / "gone.mp4"))
    job = store.claim_next()
    service.process(job, store, FakeAnalyzer(), OPTIONS)
    assert store.get(job["id"])["status"] == "failed"


def test_retry_delay_backs_off():
    assert [service.retry_delay(a).seconds for a in (1, 2, 3)] == [30, 60, 120]


def _sample_only(real, readable_path):
    """sample() chỉ đọc được file đã chuyển mã."""
    return lambda path, *a: real(path, *a) if path == readable_path else []


def test_unreadable_codec_is_transcoded_then_analyzed(store, tmp_path, fake_evidence, monkeypatch):
    """OpenCV không giải mã được (vd. AV1): chuyển sang H.264 rồi phân tích, xóa bản chuyển."""
    job, path = queue(store, tmp_path)
    converted = write_video(tmp_path / "converted.mp4", seconds=4)
    monkeypatch.setattr(service.video_frames, "sample",
                        _sample_only(service.video_frames.sample, str(converted)))
    monkeypatch.setattr(service.video_frames, "transcode", lambda p: str(converted))
    analyzer = FakeAnalyzer()
    service.process(job, store, analyzer, OPTIONS)
    assert store.get(job["id"])["status"] == "done"
    assert len(analyzer.calls[0]["frames"]) == 6
    assert not Path(path).exists() and not converted.exists()


def test_unreadable_without_ffmpeg_is_rejected(store, tmp_path, monkeypatch):
    job, _ = queue(store, tmp_path)
    monkeypatch.setattr(service.video_frames, "sample", lambda *a: [])
    monkeypatch.setattr(service.video_frames, "transcode", lambda p: None)
    service.process(job, store, FakeAnalyzer(), OPTIONS)
    row = store.get(job["id"])
    assert row["status"] == "rejected" and "định dạng" in row["message"]
