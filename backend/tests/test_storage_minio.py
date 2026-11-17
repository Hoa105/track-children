"""Chạy với MinIO local (docker compose up -d minio); không có MinIO thì bỏ qua."""

import io
import uuid

import httpx
import pytest

from app.core.config import settings
from app.shared import storage


@pytest.fixture(scope="module")
def minio():
    try:
        httpx.get(f"http://{settings.minio_endpoint}/minio/health/live", timeout=2).raise_for_status()
    except httpx.HTTPError:
        pytest.skip("MinIO không chạy")


def test_put_signed_download_range_and_remove(minio):
    key = f"test/{uuid.uuid4()}.mp4"
    data = b"0123456789" * 100
    storage.put(key, io.BytesIO(data), len(data), "video/mp4")
    try:
        url, _ = storage.presign(key, storage.public_base("localhost:8000"))
        assert httpx.get(url).content == data
        # Trình phát video tua bằng Range
        part = httpx.get(url, headers={"Range": "bytes=10-19"})
        assert (part.status_code, part.content) == (206, b"0123456789")
        assert httpx.get(url.split("?")[0]).status_code == 403  # bucket không công khai
    finally:
        storage.remove(key)
    assert httpx.get(url).status_code == 404
