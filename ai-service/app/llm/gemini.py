"""Gọi Gemini API (Google) với các khung hình của video → InsightResult.

Cùng prompt, cùng schema đầu ra với Claude (app/llm/client.py); chọn bằng LLM_PROVIDER.
GEMINI_MODEL nhận danh sách cách nhau bởi dấu phẩy: model đầu quá tải / quá chậm
(503, 504, 429, hết thời gian) thì thử ngay model kế tiếp.
"""

import json

import httpx
from google import genai
from google.genai import errors, types
from pydantic import ValidationError

from app.llm.client import Analysis, LLMError, TransientLLMError
from app.llm.prompts import OUTPUT_SCHEMA, PROMPT_VERSION, SYSTEM_PROMPT, context_text
from app.schemas.insight import InsightResult

# Dừng vì bộ lọc nội dung / bản quyền → không thử lại
_BLOCKED = {"SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII", "RECITATION", "IMAGE_SAFETY"}


def build_parts(context, frames, duration_seconds, quality_notes, evidence) -> list[types.Part]:
    parts = [types.Part.from_text(text=context_text(context, duration_seconds, quality_notes, evidence))]
    for frame in frames:
        parts.append(types.Part.from_text(text=f"Giây {frame.t:.1f}:"))
        parts.append(types.Part.from_bytes(data=frame.jpeg, mime_type="image/jpeg"))
    parts.append(
        types.Part.from_text(text="Hãy viết nhận xét cho ba mẹ theo đúng nguyên tắc và định dạng JSON.")
    )
    return parts


class GeminiVideoAnalyzer:
    def __init__(
        self,
        model: str,
        api_key: str,
        client: genai.Client | None = None,
        timeout_seconds: float = 90,
    ):
        self.models = [m.strip() for m in model.split(",") if m.strip()]
        self.api_key = api_key
        self.timeout_ms = int(timeout_seconds * 1000)
        self._client = client

    @property
    def client(self) -> genai.Client:
        # Tạo khi cần để service vẫn khởi động được khi chưa cấu hình khóa
        if self._client is None:
            if not self.api_key:
                raise LLMError("Chưa cấu hình GEMINI_API_KEY cho ai-service")
            self._client = genai.Client(api_key=self.api_key)
        return self._client

    def analyze(self, context, frames, duration_seconds, quality_notes, evidence) -> Analysis:
        contents = [
            types.Content(
                role="user",
                parts=build_parts(context, frames, duration_seconds, quality_notes, evidence),
            )
        ]
        for i, model in enumerate(self.models):
            try:
                return self._analyze(model, contents)
            except TransientLLMError:
                if i == len(self.models) - 1:
                    raise  # hết model dự phòng: worker xếp lịch thử lại
        raise LLMError("Chưa cấu hình GEMINI_MODEL")

    def _analyze(self, model: str, contents) -> Analysis:
        try:
            response = self.client.models.generate_content(
                model=model,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    response_mime_type="application/json",
                    response_json_schema=OUTPUT_SCHEMA,
                    max_output_tokens=16000,
                    http_options=types.HttpOptions(timeout=self.timeout_ms),
                ),
            )
        except errors.ServerError as e:  # 5xx, gồm 503 quá tải
            raise TransientLLMError(f"{e.code}: {e.message}") from e
        except errors.ClientError as e:
            if e.code == 429:
                raise TransientLLMError(f"429: {e.message}") from e
            if e.code in (400, 401, 403) and "api key" in str(e).lower():
                raise LLMError("GEMINI_API_KEY sai, hết hạn hoặc chưa bật Gemini API") from e
            raise LLMError(f"{e.code}: {e.message}") from e
        except httpx.TransportError as e:
            raise TransientLLMError(f"Mất kết nối tới Gemini: {e}") from e

        feedback = response.prompt_feedback
        if feedback is not None and feedback.block_reason:
            raise LLMError(f"Gemini chặn yêu cầu: {feedback.block_reason}")
        candidate = response.candidates[0] if response.candidates else None
        reason = getattr(candidate.finish_reason, "name", str(candidate.finish_reason)) if candidate else None
        if reason in _BLOCKED:
            raise LLMError(f"Gemini từ chối phân tích video này ({reason})")
        if reason == "MAX_TOKENS":
            raise LLMError("Phản hồi bị cắt do vượt max_output_tokens")
        if not response.text:
            raise LLMError("Phản hồi không có nội dung")
        try:
            result = InsightResult.model_validate(json.loads(response.text))
        except (json.JSONDecodeError, ValidationError) as e:
            raise LLMError(f"Đầu ra không đúng định dạng: {e}") from e

        meta = response.usage_metadata
        usage = {
            "input_tokens": getattr(meta, "prompt_token_count", None),
            "output_tokens": getattr(meta, "candidates_token_count", None),
            "thinking_tokens": getattr(meta, "thoughts_token_count", None),
            "response_id": getattr(response, "response_id", None),
        }
        return Analysis(
            result=result,
            model=getattr(response, "model_version", None) or model,
            prompt_version=PROMPT_VERSION,
            usage=usage,
        )
