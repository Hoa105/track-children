"""Cross-process throttling without adding a PostgreSQL auth table."""
from concurrent.futures import ProcessPoolExecutor
import multiprocessing
import sqlite3

import pytest

from app.core.config import settings
from app.features.auth import rate_limit, service


def worker(path):
    settings.auth_rate_limit_path = path
    return rate_limit.consume('shared', 5, 900)


@pytest.fixture
def cache(tmp_path, monkeypatch):
    path = str(tmp_path/'rate.sqlite3')
    monkeypatch.setattr(settings, 'auth_rate_limit_path', path)
    return path


def test_shared_counter_across_processes(cache):
    with ProcessPoolExecutor(max_workers=2, mp_context=multiprocessing.get_context('spawn')) as pool:
        results = list(pool.map(worker, [cache]*8))
    assert results.count(None) == 5
    assert sum(isinstance(r, int) and 1 <= r <= 900 for r in results) == 3


def test_expiry_exact_boundary_and_clear(cache, monkeypatch):
    monkeypatch.setattr(rate_limit.time, 'time', lambda: 1000)
    assert rate_limit.consume('one',1,60) is None
    assert rate_limit.consume('one',1,60) == 60
    assert rate_limit.consume('two',1,60) is None
    rate_limit.clear('one')
    assert rate_limit.consume('one',1,60) is None
    monkeypatch.setattr(rate_limit.time, 'time', lambda: 1060)
    assert rate_limit.consume('two',1,60) is None


@pytest.mark.parametrize('exception', [sqlite3.OperationalError('locked'), OSError('unwritable')])
def test_cache_failure_does_not_bypass_security(cache, monkeypatch, exception):
    def unavailable(*args):
        raise exception
    monkeypatch.setattr(rate_limit, 'consume', unavailable)
    failure = service.quota(None,'key',5,900)
    assert failure.status_code == 503 and failure.code == 'RATE_LIMIT_UNAVAILABLE'


def test_purge_preserves_active_counters(cache, monkeypatch):
    monkeypatch.setattr(rate_limit.time, 'time', lambda: 1000)
    rate_limit.consume('expired',1,10)
    rate_limit.consume('active',1,100)
    monkeypatch.setattr(rate_limit.time, 'time', lambda: 1010)
    rate_limit.purge()
    with sqlite3.connect(cache) as db:
        assert db.execute('SELECT key FROM counters').fetchall() == [('active',)]
