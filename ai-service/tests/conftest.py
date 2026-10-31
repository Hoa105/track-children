import datetime as dt
import uuid
from pathlib import Path

import cv2
import numpy as np
import pytest

from app.schemas.insight import NewInsight


class MemoryInsightStore:
    """InsightStore trong bộ nhớ, cùng hành vi với PgInsightStore."""

    def __init__(self):
        self.rows: dict[uuid.UUID, dict] = {}

    def create(self, new: NewInsight, video_path: str) -> dict:
        row = {
            "id": uuid.uuid4(),
            "child_id": new.child_id,
            "requested_by": new.requested_by,
            "activity_ref": new.context.activity.id,
            "activity_group": new.context.activity.group,
            "context": new.context.model_dump(mode="json", by_alias=True),
            "video_path": video_path,
            "video_seconds": None,
            "status": "pending",
            "attempts": 0,
            "run_after": dt.datetime.now(dt.timezone.utc),
            "evidence": None,
            "result": None,
            "message": None,
            "error": None,
            "created_at": dt.datetime.now(dt.timezone.utc),
            "finished_at": None,
        }
        self.rows[row["id"]] = row
        return dict(row)

    def get(self, insight_id):
        row = self.rows.get(insight_id)
        return dict(row) if row else None

    def claim_next(self):
        now = dt.datetime.now(dt.timezone.utc)
        for row in sorted(self.rows.values(), key=lambda r: r["created_at"]):
            if row["status"] == "pending" and row["run_after"] <= now:
                row.update(status="running", attempts=row["attempts"] + 1)
                return dict(row)
        return None

    def requeue_stale(self, older_than):
        return 0

    def _finish(self, insight_id, **fields):
        self.rows[insight_id].update(finished_at=dt.datetime.now(dt.timezone.utc), **fields)

    def complete(self, insight_id, *, result, evidence, video_seconds, model, prompt_version, usage):
        self._finish(insight_id, status="done", result=result, evidence=evidence,
                     video_seconds=video_seconds, model=model, usage=usage)

    def reject(self, insight_id, message, video_seconds):
        self._finish(insight_id, status="rejected", message=message, video_seconds=video_seconds)

    def retry_later(self, insight_id, error, run_after):
        self.rows[insight_id].update(status="pending", error=error, run_after=run_after)

    def fail(self, insight_id, error, message):
        self._finish(insight_id, status="failed", error=error, message=message)

    def clear_video(self, insight_id):
        self.rows[insight_id]["video_path"] = None

    def delete_for_child(self, child_id):
        paths = []
        for key, row in list(self.rows.items()):
            if row["child_id"] == child_id:
                if row["video_path"]:
                    paths.append(row["video_path"])
                del self.rows[key]
        return paths


def write_video(path: Path, seconds: float, brightness: int = 160, fps: int = 10,
                size=(320, 240)) -> Path:
    """Video tổng hợp: nền xám + hình chữ nhật di chuyển."""
    writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), fps, size)
    for i in range(round(seconds * fps)):
        frame = np.full((size[1], size[0], 3), brightness, dtype=np.uint8)
        x = (i * 7) % (size[0] - 40)
        cv2.rectangle(frame, (x, 100), (x + 40, 160), (30, 90, 200), -1)
        writer.write(frame)
    writer.release()
    return path


def new_insight(group="gross_motor", metrics=None, note="") -> NewInsight:
    return NewInsight.model_validate({
        "childId": str(uuid.uuid4()),
        "requestedBy": str(uuid.uuid4()),
        "consentedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "context": {
            "activity": {
                "id": "g0-9",
                "title": "Nhảy tại chỗ hai chân",
                "group": group,
                "ageFromMonths": 20,
                "ageToMonths": 30,
                "guide": [{"title": "Cùng bé thực hiện", "text": "Ba mẹ làm mẫu rồi mời bé nhảy."}],
            },
            "criteria": {"name": "Vận động thô", "focus": ["Tư thế", "Thăng bằng"], "avoid": []},
            "childAgeMonths": 24,
            "parentNote": note,
            "metrics": metrics if metrics is not None else ["jump_count"],
        },
    })


@pytest.fixture
def store():
    return MemoryInsightStore()
