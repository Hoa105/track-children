from app.pose import model_files


def test_ensure_downloads_only_missing_known_models(tmp_path, monkeypatch):
    present = tmp_path / "hand_landmarker.task"
    present.write_bytes(b"model")
    calls = []
    monkeypatch.setattr(model_files, "download", lambda path: calls.append(path.name))
    model_files.ensure([str(tmp_path / "pose_landmarker_full.task"), str(present),
                        str(tmp_path / "unknown.task")])
    assert calls == ["pose_landmarker_full.task"]


def test_network_error_is_logged_not_raised(tmp_path, monkeypatch, caplog):
    def fail(path):
        raise OSError("Name or service not known")

    monkeypatch.setattr(model_files, "download", fail)
    model_files.ensure([str(tmp_path / "pose_landmarker_full.task")])
    assert "Chưa tải được" in caplog.text
