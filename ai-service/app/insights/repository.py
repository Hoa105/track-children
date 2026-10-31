"""Lưu trữ job / kết quả trong ai_vision.diary_video_insights."""

import datetime as dt
from typing import Protocol
from uuid import UUID

from psycopg.types.json import Jsonb

from app.core.db import connect
from app.schemas.insight import NewInsight

COLUMNS = """
    id, child_id, requested_by, activity_ref, activity_group, context, video_path,
    video_seconds, status, attempts, evidence, result, message, created_at, finished_at
"""


class InsightStore(Protocol):
    def create(self, new: NewInsight, video_path: str) -> dict: ...
    def get(self, insight_id: UUID) -> dict | None: ...
    def claim_next(self) -> dict | None: ...
    def requeue_stale(self, older_than: dt.timedelta) -> int: ...
    def complete(self, insight_id: UUID, *, result: dict, evidence: dict | None,
                 video_seconds: float, model: str, prompt_version: str, usage: dict) -> None: ...
    def reject(self, insight_id: UUID, message: str, video_seconds: float | None) -> None: ...
    def retry_later(self, insight_id: UUID, error: str, run_after: dt.datetime) -> None: ...
    def fail(self, insight_id: UUID, error: str, message: str) -> None: ...
    def clear_video(self, insight_id: UUID) -> None: ...
    def delete_for_child(self, child_id: UUID) -> list[str]: ...


class PgInsightStore:
    def create(self, new: NewInsight, video_path: str) -> dict:
        with connect() as conn:
            return conn.execute(
                f"""
                INSERT INTO ai_vision.diary_video_insights
                  (child_id, requested_by, activity_ref, activity_group, context,
                   video_path, consented_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                RETURNING {COLUMNS}
                """,
                (
                    new.child_id,
                    new.requested_by,
                    new.context.activity.id,
                    new.context.activity.group,
                    Jsonb(new.context.model_dump(mode="json", by_alias=True)),
                    video_path,
                    new.consented_at,
                ),
            ).fetchone()

    def get(self, insight_id: UUID) -> dict | None:
        with connect() as conn:
            return conn.execute(
                f"SELECT {COLUMNS} FROM ai_vision.diary_video_insights WHERE id = %s",
                (insight_id,),
            ).fetchone()

    def claim_next(self) -> dict | None:
        with connect() as conn:
            return conn.execute(
                f"""
                UPDATE ai_vision.diary_video_insights
                SET status = 'running', attempts = attempts + 1, started_at = now()
                WHERE id = (
                    SELECT id FROM ai_vision.diary_video_insights
                    WHERE status = 'pending' AND run_after <= now()
                    ORDER BY created_at
                    FOR UPDATE SKIP LOCKED
                    LIMIT 1
                )
                RETURNING {COLUMNS}
                """
            ).fetchone()

    def requeue_stale(self, older_than: dt.timedelta) -> int:
        with connect() as conn:
            return conn.execute(
                """
                UPDATE ai_vision.diary_video_insights
                SET status = 'pending', run_after = now()
                WHERE status = 'running' AND started_at < now() - %s
                """,
                (older_than,),
            ).rowcount

    def complete(self, insight_id, *, result, evidence, video_seconds, model, prompt_version, usage):
        with connect() as conn:
            conn.execute(
                """
                UPDATE ai_vision.diary_video_insights
                SET status = 'done', result = %s, evidence = %s, video_seconds = %s,
                    llm_model = %s, prompt_version = %s, usage = %s,
                    error = NULL, message = NULL, finished_at = now()
                WHERE id = %s
                """,
                (Jsonb(result), Jsonb(evidence) if evidence else None, video_seconds,
                 model, prompt_version, Jsonb(usage), insight_id),
            )

    def reject(self, insight_id, message, video_seconds):
        with connect() as conn:
            conn.execute(
                """
                UPDATE ai_vision.diary_video_insights
                SET status = 'rejected', message = %s, video_seconds = %s, finished_at = now()
                WHERE id = %s
                """,
                (message, video_seconds, insight_id),
            )

    def retry_later(self, insight_id, error, run_after):
        with connect() as conn:
            conn.execute(
                """
                UPDATE ai_vision.diary_video_insights
                SET status = 'pending', error = %s, run_after = %s
                WHERE id = %s
                """,
                (error, run_after, insight_id),
            )

    def fail(self, insight_id, error, message):
        with connect() as conn:
            conn.execute(
                """
                UPDATE ai_vision.diary_video_insights
                SET status = 'failed', error = %s, message = %s, finished_at = now()
                WHERE id = %s
                """,
                (error, message, insight_id),
            )

    def clear_video(self, insight_id):
        with connect() as conn:
            conn.execute(
                "UPDATE ai_vision.diary_video_insights SET video_path = NULL WHERE id = %s",
                (insight_id,),
            )

    def delete_for_child(self, child_id: UUID) -> list[str]:
        with connect() as conn:
            rows = conn.execute(
                """
                DELETE FROM ai_vision.diary_video_insights WHERE child_id = %s
                RETURNING video_path
                """,
                (child_id,),
            ).fetchall()
        return [r["video_path"] for r in rows if r["video_path"]]
