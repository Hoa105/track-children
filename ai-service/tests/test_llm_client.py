import json
from types import SimpleNamespace

import anthropic
import httpx
import pytest

from app.llm import client as llm
from app.llm.prompts import OUTPUT_SCHEMA
from app.schemas.insight import Evidence, EvidenceMetric, InsightResult
from app.video.frames import Frame
from tests.conftest import new_insight

FRAMES = [Frame(t=0.5, jpeg=b"\xff\xd8a", brightness=120), Frame(t=1.5, jpeg=b"\xff\xd8b", brightness=120)]
OUTPUT = {
    "can_assess": True,
    "video_issue": "",
    "observations": ["Bé bật nhảy, hai chân rời sàn (theo số đo tự động: 3 lần)."],
    "comment": "Bé rất thích thú.",
    "positives": ["Bé giữ thăng bằng tốt khi tiếp đất"],
    "next_steps": ["Đặt một sợi dây trên sàn để bé nhảy qua."],
    "see_specialist": False,
    "specialist_note": "",
}


def response(stop_reason="end_turn", text=json.dumps(OUTPUT)):
    return SimpleNamespace(
        stop_reason=stop_reason,
        content=[SimpleNamespace(type="thinking", thinking=""), SimpleNamespace(type="text", text=text)],
        usage=SimpleNamespace(input_tokens=1200, output_tokens=300),
        model="claude-opus-5-5",
        _request_id="req_1",
    )


class FakeMessages:
    def __init__(self, result):
        self.result = result
        self.kwargs = None

    def create(self, **kwargs):
        self.kwargs = kwargs
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


def fake_client(result):
    messages = FakeMessages(result)
    return SimpleNamespace(messages=messages, beta=SimpleNamespace(messages=messages)), messages


def analyze(result, model="claude-opus-5-5", evidence=None, note=""):
    client, messages = fake_client(result)
    analyzer = llm.ClaudeVideoAnalyzer(model, "medium", client=client)
    out = analyzer.analyze(new_insight(note=note).context, FRAMES, 4.0, ["Video hơi tối"], evidence)
    return out, messages.kwargs


def test_schema_matches_result_model():
    assert set(OUTPUT_SCHEMA["required"]) == set(InsightResult.model_fields)


def test_parses_structured_output_and_sends_frames():
    evidence = Evidence(available=True, detection_ratio=0.9,
                        metrics=[EvidenceMetric(key="jump_count", label="Số lần bật nhảy", value=3, unit="lần")])
    out, kwargs = analyze(response(), evidence=evidence, note="Bé hơi ngại.")
    assert out.result.positives == OUTPUT["positives"]
    assert out.usage["input_tokens"] == 1200
    assert kwargs["model"] == "claude-opus-5-5"
    assert kwargs["fallbacks"] == "default" and kwargs["betas"] == [llm._FALLBACK_BETA]
    assert kwargs["output_config"]["format"]["schema"] == OUTPUT_SCHEMA
    content = kwargs["messages"][0]["content"]
    assert [c["type"] for c in content].count("image") == 2
    intro = content[0]["text"]
    assert "Số lần bật nhảy" in intro and "Video hơi tối" in intro
    assert "<ghi_chu>Bé hơi ngại.</ghi_chu>" in intro


def test_model_without_server_fallback_uses_plain_create():
    _, kwargs = analyze(response(), model="claude-haiku-5-5")
    assert "fallbacks" not in kwargs and "betas" not in kwargs


@pytest.mark.parametrize("stop_reason", ["refusal", "max_tokens"])
def test_refusal_and_truncation_are_permanent(stop_reason):
    with pytest.raises(llm.LLMError):
        analyze(response(stop_reason=stop_reason))


def test_invalid_json_is_permanent():
    with pytest.raises(llm.LLMError):
        analyze(response(text="{not json"))


def _status_error(cls, code):
    request = httpx.Request("POST", "https://api.anthropic.com/v1/messages")
    return cls("error", response=httpx.Response(code, request=request), body=None)


def test_rate_limit_and_overload_are_transient():
    with pytest.raises(llm.TransientLLMError):
        analyze(_status_error(anthropic.RateLimitError, 429))
    with pytest.raises(llm.TransientLLMError):
        analyze(_status_error(anthropic.APIStatusError, 529))


def test_bad_request_is_permanent():
    with pytest.raises(llm.LLMError):
        analyze(_status_error(anthropic.BadRequestError, 400))


def test_missing_api_key_is_permanent_with_clear_message():
    error = TypeError('"Could not resolve authentication method. Expected one of api_key"')
    with pytest.raises(llm.LLMError, match="ANTHROPIC_API_KEY"):
        analyze(error)
