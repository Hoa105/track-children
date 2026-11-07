"""Lưu trữ đánh giá tổng hợp trong ai_vision.progress_reviews."""

from typing import Protocol
from uuid import UUID

from psycopg.types.json import Jsonb

from app.core.db import connect

COLUMNS = """
    id, child_id, requested_by, activity_ref, activity_group, activity_title, insight_ids,
    period_from, period_to, result, metrics, llm_model, prompt_version, created_at
"""


class ReviewStore(Protocol):
    def create(self, review: dict) -> dict: ...
    def find(self, child_id: UUID, insight_ids: list[UUID], prompt_version: str) -> dict | None: ...
    def get(self, review_id: UUID) -> dict | None: ...
    def list_for_child(self, child_id: UUID, activity_ref: str | None = None) -> list[dict]: ...
    def delete_for_child(self, child_id: UUID) -> None: ...


class PgReviewStore:
    def create(self, review: dict) -> dict:
        with connect() as conn:
            return conn.execute(
                f"""
                INSERT INTO ai_vision.progress_reviews
                  (child_id, requested_by, activity_ref, activity_group, activity_title,
                   insight_ids, period_from, period_to, result, metrics, llm_model,
                   prompt_version, usage)
                VALUES (%(child_id)s, %(requested_by)s, %(activity_ref)s, %(activity_group)s,
                        %(activity_title)s, %(insight_ids)s, %(period_from)s, %(period_to)s,
                        %(result)s, %(metrics)s, %(llm_model)s, %(prompt_version)s, %(usage)s)
                RETURNING {COLUMNS}
                """,
                {
                    **review,
                    "result": Jsonb(review["result"]),
                    "metrics": Jsonb(review["metrics"]),
                    "usage": Jsonb(review["usage"]),
                },
            ).fetchone()

    def find(self, child_id, insight_ids, prompt_version):
        with connect() as conn:
            return conn.execute(
                f"""
                SELECT {COLUMNS} FROM ai_vision.progress_reviews
                WHERE child_id = %s AND prompt_version = %s AND insight_ids = %s::uuid[]
                ORDER BY created_at DESC LIMIT 1
                """,
                (child_id, prompt_version, insight_ids),
            ).fetchone()

    def get(self, review_id):
        with connect() as conn:
            return conn.execute(
                f"SELECT {COLUMNS} FROM ai_vision.progress_reviews WHERE id = %s", (review_id,)
            ).fetchone()

    def list_for_child(self, child_id, activity_ref=None):
        with connect() as conn:
            return conn.execute(
                f"""
                SELECT {COLUMNS} FROM ai_vision.progress_reviews
                WHERE child_id = %s AND (%s::text IS NULL OR activity_ref = %s)
                ORDER BY created_at DESC LIMIT 100
                """,
                (child_id, activity_ref, activity_ref),
            ).fetchall()

    def delete_for_child(self, child_id):
        with connect() as conn:
            conn.execute("DELETE FROM ai_vision.progress_reviews WHERE child_id = %s", (child_id,))
