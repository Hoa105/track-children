"""HTTP client for ai-service internal endpoints (X-Internal-Token)."""

from typing import BinaryIO
from uuid import UUID

import httpx

from app.core.config import settings


class AiServiceError(Exception):
    def __init__(self, status_code: int, detail):
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


def _client() -> httpx.Client:
    if not settings.ai_service_token:
        raise AiServiceError(503, "Chưa cấu hình dịch vụ AI")
    return httpx.Client(
        base_url=settings.ai_service_url,
        headers={"X-Internal-Token": settings.ai_service_token},
        timeout=httpx.Timeout(10, read=120, write=120),
    )


def _send(make_request) -> httpx.Response:
    try:
        with _client() as client:
            response = make_request(client)
    except httpx.HTTPError:
        raise AiServiceError(503, "Dịch vụ AI tạm thời không khả dụng") from None
    if response.status_code >= 500:
        raise AiServiceError(502, "Dịch vụ AI gặp lỗi, vui lòng thử lại sau")
    if response.status_code >= 400 and response.status_code != 404:
        try:
            detail = response.json().get("detail")
        except ValueError:
            detail = response.text
        raise AiServiceError(response.status_code, detail)
    return response


def create_video_insight(video: BinaryIO, filename: str, content_type: str, meta: str) -> dict:
    response = _send(
        lambda c: c.post(
            "/internal/video-insights",
            data={"meta": meta},
            files={"video": (filename, video, content_type)},
        )
    )
    return response.json()


def get_video_insight(insight_id: UUID) -> dict | None:
    response = _send(lambda c: c.get(f"/internal/video-insights/{insight_id}"))
    return None if response.status_code == 404 else response.json()
