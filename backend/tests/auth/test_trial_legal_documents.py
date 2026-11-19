from datetime import datetime, timezone
from pathlib import Path

from app.core.config import settings
from app.features.auth import registration
from app.features.auth.errors import AuthFailure


def test_trial_documents_available_at_vietnam_release_midnight(monkeypatch):
    path = Path(__file__).parents[2] / 'legal-documents.local.json'
    monkeypatch.setattr(settings, 'legal_documents_path', str(path))
    # Midnight 19 November in Vietnam is still 18 November in UTC.
    monkeypatch.setattr(registration.sec, 'now', lambda: datetime(
        2026, 11, 18, 17, 0, tzinfo=timezone.utc))
    result = registration.legal()
    assert isinstance(result, list)
    assert len(result) == 3
    assert all(doc['version'] == 'trial-1.0' for doc in result)


def test_trial_documents_reject_before_effective_time(monkeypatch):
    path = Path(__file__).parents[2] / 'legal-documents.local.json'
    monkeypatch.setattr(settings, 'legal_documents_path', str(path))
    monkeypatch.setattr(registration.sec, 'now', lambda: datetime(
        2026, 11, 18, 16, 59, 59, tzinfo=timezone.utc))
    assert isinstance(registration.legal(), AuthFailure)
