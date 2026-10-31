"""Lưu file (ảnh / video nhật ký) trên MinIO.

Backend đọc / ghi qua MINIO_ENDPOINT (trong docker là minio:9000); mobile tải
bằng link ký sẵn có thời hạn, ký theo địa chỉ mobile thấy được (public_base).
"""

import datetime as dt
import logging
from functools import lru_cache
from typing import BinaryIO
from urllib.parse import urlsplit

from minio import Minio
from minio.error import S3Error

from app.core.config import settings

log = logging.getLogger(__name__)
# Đặt sẵn region để ký link không cần gọi MinIO (host công khai có thể không gọi được từ backend)
_REGION = "us-east-1"


class StorageError(Exception):
    pass


def _client(endpoint: str, secure: bool) -> Minio:
    return Minio(
        endpoint,
        access_key=settings.minio_access_key,
        secret_key=settings.minio_secret_key,
        secure=secure,
        region=_REGION,
    )


@lru_cache
def _internal() -> Minio:
    client = _client(settings.minio_endpoint, settings.minio_secure)
    if not client.bucket_exists(settings.minio_bucket):
        client.make_bucket(settings.minio_bucket)
    return client


@lru_cache(maxsize=16)
def _public(base_url: str) -> Minio:
    parts = urlsplit(base_url)
    return _client(parts.netloc, parts.scheme == "https")


def public_base(request_host: str | None) -> str:
    """Gốc URL cho link tải: MINIO_PUBLIC_URL, hoặc host mobile vừa gọi backend + cổng MinIO."""
    if settings.minio_public_url:
        return settings.minio_public_url.rstrip("/")
    host = urlsplit(f"//{request_host or 'localhost'}").hostname or "localhost"
    if ":" in host:  # IPv6
        host = f"[{host}]"
    return f"http://{host}:{settings.minio_public_port}"


def put(key: str, data: BinaryIO, length: int, content_type: str) -> None:
    try:
        _internal().put_object(settings.minio_bucket, key, data, length, content_type=content_type)
    except Exception as e:  # mạng / MinIO tắt / S3Error
        raise StorageError(str(e)) from e


def remove(key: str) -> None:
    """Xóa file; lỗi chỉ ghi log (dòng diary_media giữ status='deleted' để dọn sau)."""
    try:
        _internal().remove_object(settings.minio_bucket, key)
    except Exception:
        log.warning("Không xóa được %s trên MinIO", key, exc_info=True)


def presign(key: str, base_url: str) -> tuple[str, dt.datetime]:
    """Link GET có thời hạn (hỗ trợ Range nên phát video tua được)."""
    ttl = dt.timedelta(minutes=settings.media_url_ttl_minutes)
    try:
        url = _public(base_url).presigned_get_object(settings.minio_bucket, key, expires=ttl)
    except S3Error as e:
        raise StorageError(str(e)) from e
    return url, dt.datetime.now(dt.timezone.utc) + ttl
