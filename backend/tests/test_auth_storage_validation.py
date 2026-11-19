from datetime import datetime, timezone
from uuid import uuid4
import pytest

from app.features.auth import code_storage, storage_validation as shapes
from app.features.auth.transactions import known_devices, load
from app.features.auth.errors import AuthFailure
from types import SimpleNamespace


@pytest.mark.parametrize('value', [None, {}, [None], [{'hash': 'x'}],
    [{'hash': 'a'*64, 'lastAuthenticatedAt': '2026-11-19'}],
    [{'hash': 'a'*64, 'lastAuthenticatedAt': 'bad'}],
    [{'hash': 'a'*64, 'lastAuthenticatedAt': '2026-11-19T00:00:00+07:00'}]*2])
def test_device_shape_rejects_malformed_and_duplicate_entries(value):
    assert not shapes.valid_devices(value)
    assert known_devices({'auth_known_devices': value}) == set()


def test_device_boundaries_and_timezone():
    device = lambda n: {'hash': f'{n:064x}', 'lastAuthenticatedAt': datetime.now(timezone.utc).isoformat()}
    assert shapes.valid_devices([])
    assert shapes.valid_devices([device(n) for n in range(16)])
    assert not shapes.valid_devices([device(n) for n in range(17)])


@pytest.mark.parametrize('value', [None, {}, [], [None],
    [{'type': 'terms', 'version': 'trial-1.0', 'sha256': 'bad'}],
    [{'type': 'terms', 'version': 'trial-1.0', 'sha256': 'a'*64}]*2])
def test_consent_shape_rejects_invalid_snapshots(value):
    assert not shapes.valid_documents(value)


def test_consent_preserves_versioned_snapshot():
    docs = [{'type': kind, 'version': 'trial-1.0', 'sha256': 'a'*64}
            for kind in ['terms','privacy','data_policy']]
    assert shapes.valid_documents(docs)
    assert docs[0]['version'] == 'trial-1.0'


@pytest.mark.parametrize('purpose,metadata', [('reauth', []), ('phone_signup', {'notice': {}}),
    ('reauth', {'limiter': True, 'notice': {}}), ('reauth', {'legacyCode': True})])
def test_cannot_mix_system_records_and_capabilities(purpose, metadata):
    with pytest.raises(ValueError):
        shapes.validate_metadata(purpose, metadata)


class FakeDB:
    def __init__(self, value):
        self.value = value
    def execute(self, *args):
        return self
    def fetchone(self):
        return self.value


@pytest.mark.parametrize('compact', [False, True])
def test_legacy_storage_cutover_detects_actual_schema(compact):
    table, purpose = code_storage.storage(FakeDB({'compact': compact}))
    assert table == ('account.auth_transactions' if compact else 'account.auth_codes')
    assert purpose == ('legacy_verify_contact' if compact else 'verify_contact')


@pytest.mark.parametrize('metadata', [{'limiter': True}, {'notice': {}}, {'appleEvent': 'consent-revoked'}, {'legacyCode': True}])
def test_system_record_cannot_be_loaded_as_reauth_capability(metadata):
    row = {'purpose': 'reauth', 'metadata': metadata}
    result = load(FakeDB(row), SimpleNamespace(transactionId=uuid4()), 'reauth')
    assert isinstance(result, AuthFailure)
