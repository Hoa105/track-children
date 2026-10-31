"""PostgreSQL connections (psycopg 3) for the AI database."""

from contextlib import contextmanager

import psycopg
from psycopg.rows import dict_row

from app.core.config import settings


@contextmanager
def connect():
    """One transaction per `with` block: commit on success, rollback on error."""
    with psycopg.connect(
        settings.database_url, row_factory=dict_row, connect_timeout=5
    ) as conn:
        yield conn
