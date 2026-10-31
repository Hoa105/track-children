"""Gọi Claude API với các khung hình của video → InsightResult."""

import base64
import json
from dataclasses import dataclass
from typing import Protocol

import anthropic
from pydantic import ValidationError

from app.llm.prompts import OUTPUT_SCHEMA, PROMPT_VERSION, SYSTEM_PROMPT, context_text
from app.schemas.insight import Evidence, InsightContext, InsightResult
from app.video.frames import Frame

# Model nhận fallbacks: "default" (chuyển model khác khi bộ lọc an toàn từ chối nhầm)
_FALLBACK_MODELS = {"claude-opus-5-5", "claude-opus-5", "claude-fable-5-1", "claude-sonnet-5-5"}
_FALLBACK_BETA = "server-side-fallback-2026-07-01"


class TransientLLMError(Exception):
    """Lỗi tạm thời (rate limit, quá tải, mạng) — job được thử lại."""


class LLMError(Exception):
    """Lỗi không thử lại được (từ chối, cấu hình sai, đầu ra hỏng)."""


@dataclass
class Analysis:
    result: InsightResult
    model: str
    prompt_version: str
    usage: dict


class VideoAnalyzer(Protocol):
    def analyze(
        self,
        context: InsightContext,
        frames: list[Frame],
        duration_seconds: float,
        quality_notes: list[str],
        evidence: Evidence | None,
    ) -> Analysis: ...


def build_content(
    context: InsightContext,
    frames: list[Frame],
    duration_seconds: float,
    quality_notes: list[str],
    evidence: Evidence | None,
) -> list[dict]:
    content: list[dict] = [
        {"type": "text", "text": context_text(context, duration_seconds, quality_notes, evidence)}
    ]
    for frame in frames:
        content.append({"type": "text", "text": f"Giây {frame.t:.1f}:"})
        content.append(
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64.standard_b64encode(frame.jpeg).decode("ascii"),
                },
            }
        )
    content.append(
        {"type": "text", "text": "Hãy viết nhận xét cho ba mẹ theo đúng nguyên tắc và định dạng JSON."}
    )
    return content


class ClaudeVideoAnalyzer:
    def __init__(self, model: str, effort: str, client: anthropic.Anthropic | None = None):
        self.model = model
        self.effort = effort
        self._client = client

    @property
    def client(self) -> anthropic.Anthropic:
        # Tạo khi cần để service vẫn khởi động được khi chưa cấu hình khóa.
        # Đọc ANTHROPIC_API_KEY từ môi trường; SDK tự retry 2 lần cho 429 / 5xx.
        if self._client is None:
            self._client = anthropic.Anthropic(timeout=180)
        return self._client

    def analyze(self, context, frames, duration_seconds, quality_notes, evidence) -> Analysis:
        request = dict(
            model=self.model,
            max_tokens=16000,
            system=SYSTEM_PROMPT,
            output_config={
                "effort": self.effort,
                "format": {"type": "json_schema", "schema": OUTPUT_SCHEMA},
            },
            messages=[
                {
                    "role": "user",
                    "content": build_content(
                        context, frames, duration_seconds, quality_notes, evidence
                    ),
                }
            ],
        )
        try:
            if self.model in _FALLBACK_MODELS:
                response = self.client.beta.messages.create(
                    **request, betas=[_FALLBACK_BETA], fallbacks="default"
                )
            else:
                response = self.client.messages.create(**request)
        except (anthropic.RateLimitError, anthropic.APIConnectionError, anthropic.InternalServerError) as e:
            raise TransientLLMError(str(e)) from e
        except anthropic.AuthenticationError as e:
            raise LLMError("ANTHROPIC_API_KEY sai hoặc đã bị thu hồi") from e
        except TypeError as e:
            # SDK báo TypeError khi không tìm thấy khóa / token nào
            if "authentication" in str(e):
                raise LLMError("Chưa cấu hình ANTHROPIC_API_KEY cho ai-service") from e
            raise
        except anthropic.APIStatusError as e:
            if e.status_code >= 500:  # gồm 529 overloaded
                raise TransientLLMError(f"{e.status_code}: {e.message}") from e
            raise LLMError(f"{e.status_code}: {e.message}") from e

        if response.stop_reason == "refusal":
            raise LLMError("Claude từ chối phân tích video này")
        if response.stop_reason == "max_tokens":
            raise LLMError("Phản hồi bị cắt do vượt max_tokens")
        text = next((b.text for b in response.content if b.type == "text"), None)
        if text is None:
            raise LLMError("Phản hồi không có nội dung")
        try:
            result = InsightResult.model_validate(json.loads(text))
        except (json.JSONDecodeError, ValidationError) as e:
            raise LLMError(f"Đầu ra không đúng định dạng: {e}") from e

        usage = {
            "input_tokens": response.usage.input_tokens,
            "output_tokens": response.usage.output_tokens,
            "request_id": getattr(response, "_request_id", None),
        }
        return Analysis(result=result, model=response.model, prompt_version=PROMPT_VERSION, usage=usage)
