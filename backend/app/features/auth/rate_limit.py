"""Fixed-window counters: shared SQLite on one host or atomic PostgreSQL counters.

PostgreSQL mode reuses auth_transactions after approved migrations 023/024.
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
    if settings.auth_rate_limit_backend=='postgres':
        return postgres_consume(key,limit,seconds)
    now = time.time()
    with connection() as db:
        db.execute('DELETE FROM counters WHERE resets_at <= ?', (now,))
        db.execute('''INSERT INTO counters(key,attempts,resets_at) VALUES (?,1,?)
            ON CONFLICT(key) DO UPDATE SET attempts=attempts+1''', (key, now+seconds))
        attempts, reset = db.execute('SELECT attempts,resets_at FROM counters WHERE key=?', (key,)).fetchone()
        return max(1, math.ceil(reset-now)) if attempts > limit else None


def clear(key):
    if settings.auth_rate_limit_backend=='postgres':
        return postgres_clear(key)
    with connection() as db:
        db.execute('DELETE FROM counters WHERE key=?', (key,))


def purge():
    if settings.auth_rate_limit_backend=='postgres':
        from app.core.database import transaction
        with transaction() as db:
            db.execute("DELETE FROM account.auth_transactions WHERE metadata->>'limiter'='true' AND expires_at<=now()")
        return
    with connection() as db:
        db.execute('DELETE FROM counters WHERE resets_at <= ?', (time.time(),))


def postgres_consume(key,limit,seconds):
    """Atomic shared counters in existing short-lived auth storage; no new table."""
    import psycopg
    from datetime import datetime,timedelta,timezone
    from app.core.database import transaction
    from app.core.security import secret_hash
    from psycopg.types.json import Jsonb
    now=datetime.fromtimestamp(time.time(),timezone.utc)
    try:
        with transaction() as db:
            row=db.execute("""INSERT INTO account.auth_transactions(purpose,secret_hash,metadata,expires_at,created_at)
              VALUES ('reauth',%s,%s,%s,%s) ON CONFLICT(secret_hash) DO UPDATE SET
              metadata=CASE WHEN account.auth_transactions.expires_at<=%s THEN EXCLUDED.metadata
                ELSE jsonb_set(account.auth_transactions.metadata,'{count}',to_jsonb(LEAST((account.auth_transactions.metadata->>'count')::int+1,%s))) END,
              expires_at=CASE WHEN account.auth_transactions.expires_at<=%s THEN EXCLUDED.expires_at ELSE account.auth_transactions.expires_at END
              RETURNING metadata,expires_at""",(secret_hash('limiter:'+key),Jsonb({'limiter':True,'count':1}),
              now+timedelta(seconds=seconds),now,now,limit+1,now)).fetchone()
        return max(1,math.ceil((row['expires_at']-now).total_seconds())) if row['metadata']['count']>limit else None
    except psycopg.Error as exc:
        raise sqlite3.OperationalError('Shared limiter unavailable') from None


def postgres_clear(key):
    import psycopg
    from app.core.database import transaction
    from app.core.security import secret_hash
    try:
        with transaction() as db:
            db.execute("DELETE FROM account.auth_transactions WHERE secret_hash=%s AND metadata->>'limiter'='true'",(secret_hash('limiter:'+key),))
    except psycopg.Error:
        raise sqlite3.OperationalError('Shared limiter unavailable') from None
