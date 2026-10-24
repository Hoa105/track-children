"""Persistent fixed-window counters shared by workers on one API host.

Operational cache, separate from the agreed PostgreSQL auth schema. All workers
must use the same local file. Multiple API hosts need a distributed limiter.
"""
from contextlib import contextmanager
import math
from pathlib import Path
import sqlite3
import time

from app.core.config import settings


@contextmanager
def connection():
    path = Path(settings.auth_rate_limit_path) if settings.auth_rate_limit_path else (
        Path(__file__).resolve().parents[3] / '.runtime' / 'auth-rate-limits.sqlite3')
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path, timeout=5, isolation_level=None)
    try:
        try:
            db.execute('CREATE TABLE IF NOT EXISTS counters (key TEXT PRIMARY KEY, attempts INTEGER NOT NULL, resets_at REAL NOT NULL)')
            db.execute('CREATE INDEX IF NOT EXISTS counters_expiry ON counters(resets_at)')
            db.execute('BEGIN IMMEDIATE')
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
    finally:
        db.close()


def consume(key, limit, seconds):
    now = time.time()
    with connection() as db:
        db.execute('DELETE FROM counters WHERE resets_at <= ?', (now,))
        db.execute('''INSERT INTO counters(key,attempts,resets_at) VALUES (?,1,?)
            ON CONFLICT(key) DO UPDATE SET attempts=attempts+1''', (key, now+seconds))
        attempts, reset = db.execute('SELECT attempts,resets_at FROM counters WHERE key=?', (key,)).fetchone()
        return max(1, math.ceil(reset-now)) if attempts > limit else None


def clear(key):
    with connection() as db:
        db.execute('DELETE FROM counters WHERE key=?', (key,))


def purge():
    with connection() as db:
        db.execute('DELETE FROM counters WHERE resets_at <= ?', (time.time(),))
