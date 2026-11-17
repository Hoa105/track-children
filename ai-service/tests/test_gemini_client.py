import json
from types import SimpleNamespace

import httpx
import pytest
from google.genai import errors

from app.llm import gemini
from app.llm.client import LLMError, TransientLLMError
from app.llm.prompts import OUTPUT_SCHEMA, SYSTEM_PROMPT
from app.video.frames import Frame
from tests.conftest import new_insight

FRAMES = [Frame(t=0.5, jpeg=b"\xff\xd8a", brightness=120), Frame(t=1.5, jpeg=b"\xff\xd8b", brightness=120)]
OUTPUT = {
    "can_assess": True,
    "video_issue": "",
    "observations": ["Bé bò qua gối, hai tay chống sàn."],
    "comment": "Bé rất hăng hái.",
    "positives": ["Bé phối hợp tay chân nhịp nhàng"],
    "next_steps": ["Thêm một chiếc gối thấp để bé bò qua."],
    "see_specialist": False,
    "specialist_note": "",
}


def response(text=json.dumps(OUTPUT), finish="STOP", block=None):
    return SimpleNamespace(
        prompt_feedback=SimpleNamespace(block_reason=block) if block else None,
        candidates=[SimpleNamespace(finish_reason=SimpleNamespace(name=finish))],
        text=text,
        usage_metadata=SimpleNamespace(prompt_token_count=900, candidates_token_count=250,
                                       thoughts_token_count=400),
        model_version="gemini-2.5-flash-001",
        response_id="resp_1",
    )


class FakeModels:
    def __init__(self, result):
        self.result = result
        self.kwargs = None

    def generate_content(self, **kwargs):
        self.kwargs = kwargs
        if isinstance(self.result, BaseException):
            raise self.result
        return self.result


def analyze(result, note=""):
    models = FakeModels(result)
    analyzer = gemini.GeminiVideoAnalyzer("gemini-2.5-flash", "key", client=SimpleNamespace(models=models))
    out = analyzer.analyze(new_insight(note=note).context, FRAMES, 4.0, ["Video hơi tối"], None)
    return out, models.kwargs


def test_parses_json_and_sends_frames_with_schema():
    out, kwargs = analyze(response(), note="Bé hơi ngại")
    assert out.result.next_steps == OUTPUT["next_steps"]
    assert out.model == "gemini-2.5-flash-001"
    assert out.usage == {"input_tokens": 900, "output_tokens": 250, "thinking_tokens": 400,
                         "response_id": "resp_1"}
    assert kwargs["model"] == "gemini-2.5-flash"
    assert kwargs["config"].http_options.timeout == 90_000
    config = kwargs["config"]
    assert config.system_instruction == SYSTEM_PROMPT
    assert config.response_mime_type == "application/json"
    assert config.response_json_schema == OUTPUT_SCHEMA
    parts = kwargs["contents"][0].parts
    images = [p for p in parts if p.inline_data is not None]
    assert len(images) == 2 and images[0].inline_data.mime_type == "image/jpeg"
    assert "<ghi_chu>Bé hơi ngại</ghi_chu>" in parts[0].text
    assert parts[1].text == "Giây 0.5:"


@pytest.mark.parametrize("finish", ["SAFETY", "PROHIBITED_CONTENT"])
def test_safety_block_is_permanent(finish):
    with pytest.raises(LLMError, match="từ chối"):
        analyze(response(finish=finish))


def test_prompt_block_and_truncation_and_bad_json_are_permanent():
    with pytest.raises(LLMError, match="chặn"):
        analyze(response(block="SAFETY"))
    with pytest.raises(LLMError, match="max_output_tokens"):
        analyze(response(finish="MAX_TOKENS"))
    with pytest.raises(LLMError, match="định dạng"):
        analyze(response(text="{oops"))


def _error(cls, code, message):
    return cls(code, {"error": {"code": code, "message": message, "status": "X"}})


def test_overload_rate_limit_and_network_are_transient():
    with pytest.raises(TransientLLMError):
        analyze(_error(errors.ServerError, 503, "The model is overloaded"))
    with pytest.raises(TransientLLMError):
        analyze(_error(errors.ClientError, 429, "Resource exhausted"))
    with pytest.raises(TransientLLMError):
        analyze(httpx.ConnectError("boom"))


def test_bad_key_is_permanent_with_clear_message():
    with pytest.raises(LLMError, match="GEMINI_API_KEY"):
        analyze(_error(errors.ClientError, 400, "API key not valid. Please pass a valid API key."))


def test_missing_key_fails_without_network():
    analyzer = gemini.GeminiVideoAnalyzer("gemini-2.5-flash", "")
    with pytest.raises(LLMError, match="GEMINI_API_KEY"):
        analyzer.analyze(new_insight().context, FRAMES, 4.0, [], None)


class SequenceModels:
    """Trả lần lượt từng kết quả, ghi lại model được gọi."""

    def __init__(self, *results):
        self.results = list(results)
        self.called = []

    def generate_content(self, **kwargs):
        self.called.append(kwargs["model"])
        result = self.results.pop(0)
        if isinstance(result, BaseException):
            raise result
        return result


def test_falls_back_to_next_model_when_overloaded():
    models = SequenceModels(_error(errors.ServerError, 503, "high demand"), response())
    analyzer = gemini.GeminiVideoAnalyzer(
        "gemini-3.8-flash, gemini-3.5-flash-lite", "key", client=SimpleNamespace(models=models)
    )
    out = analyzer.analyze(new_insight().context, FRAMES, 4.0, [], None)
    assert models.called == ["gemini-3.8-flash", "gemini-3.5-flash-lite"]
    assert out.result.can_assess


def test_permanent_error_does_not_try_next_model():
    models = SequenceModels(_error(errors.ClientError, 400, "API key not valid"), response())
    analyzer = gemini.GeminiVideoAnalyzer("a,b", "key", client=SimpleNamespace(models=models))
    with pytest.raises(LLMError):
        analyzer.analyze(new_insight().context, FRAMES, 4.0, [], None)
    assert models.called == ["a"]


def test_all_models_overloaded_is_transient():
    models = SequenceModels(httpx.ReadTimeout("slow"), _error(errors.ServerError, 504, "deadline"))
    analyzer = gemini.GeminiVideoAnalyzer("a,b", "key", client=SimpleNamespace(models=models))
    with pytest.raises(TransientLLMError):
        analyzer.analyze(new_insight().context, FRAMES, 4.0, [], None)
