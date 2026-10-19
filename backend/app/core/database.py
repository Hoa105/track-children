"""PostgreSQL connection pool (psycopg2) shared by API features."""

from collections.abc import Iterator
from threading import Lock

from psycopg2.extensions import connection as Connection
from psycopg2.extras import RealDictCursor
from psycopg2.pool import ThreadedConnectionPool

from app.core.config import settings

_pool: ThreadedConnectionPool | None = None
_pool_lock = Lock()


def _get_pool() -> ThreadedConnectionPool:
    global _pool
    with _pool_lock:
        if _pool is None:
            _pool = ThreadedConnectionPool(
                1, 10, settings.database_url, cursor_factory=RealDictCursor
            )
        return _pool


def get_db() -> Iterator[Connection]:
    """FastAPI dependency. Writes must run inside `with conn:` (commit/rollback)."""
    pool = _get_pool()
    conn = pool.getconn()
    try:
        yield conn
    finally:
        conn.rollback()  # đóng transaction đọc còn mở trước khi trả về pool
        pool.putconn(conn)
