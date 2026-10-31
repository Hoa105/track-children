from app.video import frames, quality
from tests.conftest import write_video


def test_probe_and_sample(tmp_path):
    path = write_video(tmp_path / "ok.mp4", seconds=4)
    info = frames.probe(str(path))
    assert 3.5 < info.seconds < 4.5
    sampled = frames.sample(str(path), info, count=8, max_side=160)
    assert len(sampled) == 8
    assert sampled[0].jpeg[:2] == b"\xff\xd8"  # JPEG
    assert [f.t for f in sampled] == sorted(f.t for f in sampled)
    assert quality.assess(info, sampled, 2, 90).reject_reason is None


def test_sample_times_spread_evenly():
    assert frames.sample_times(8, 4) == [1.0, 3.0, 5.0, 7.0]
    assert frames.sample_times(0, 4) == []


def test_unreadable_video(tmp_path):
    path = tmp_path / "bad.mp4"
    path.write_bytes(b"not a video")
    try:
        frames.probe(str(path))
    except frames.UnreadableVideo:
        pass
    else:
        raise AssertionError("expected UnreadableVideo")


def test_rejects_short_and_dark(tmp_path):
    short = write_video(tmp_path / "short.mp4", seconds=1)
    info = frames.probe(str(short))
    report = quality.assess(info, frames.sample(str(short), info, 4, 160), 2, 90)
    assert "quá ngắn" in report.reject_reason

    dark = write_video(tmp_path / "dark.mp4", seconds=3, brightness=5)
    info = frames.probe(str(dark))
    report = quality.assess(info, frames.sample(str(dark), info, 4, 160), 2, 90)
    assert "quá tối" in report.reject_reason


def test_low_resolution_is_note_not_reject(tmp_path):
    path = write_video(tmp_path / "small.mp4", seconds=3, size=(176, 144))
    info = frames.probe(str(path))
    report = quality.assess(info, frames.sample(str(path), info, 4, 160), 2, 90)
    assert report.reject_reason is None
    assert any("phân giải" in n for n in report.notes)
