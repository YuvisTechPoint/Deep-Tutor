"""Tests for OpenAI-compatible error message extraction."""

from deeptutor.services.llm.openai_error_message import user_message_from_openai_exception
from deeptutor.tutorbot.providers.base import LLMProvider


def test_extract_from_nested_error_dict() -> None:
    body = {
        "error": {
            "message": "Rate limit reached for model X. Please try again in 1h.",
            "type": "tokens",
            "code": "rate_limit_exceeded",
        }
    }

    class E(Exception):
        pass

    assert user_message_from_openai_exception(E("ignored"), body).startswith("Rate limit")


def test_extract_from_json_string_body() -> None:
    body = '{"error": {"message": "Context length exceeded"}}'

    class E(Exception):
        pass

    assert user_message_from_openai_exception(E(), body) == "Context length exceeded"


def test_literal_eval_python_dict_repr() -> None:
    s = "{'message': 'Hello from gateway', 'type': 'tokens', 'code': 'x'}"

    class E(Exception):
        def __str__(self) -> str:
            return s

    assert user_message_from_openai_exception(E()) == "Hello from gateway"


def test_quota_daily_limit_detection() -> None:
    assert LLMProvider._is_quota_or_daily_limit_error(
        "Limit 100000, Used 99277. tokens per day (TPD)"
    )
    assert LLMProvider._is_quota_or_daily_limit_error(
        "Please try again in 2h27m10.944s."
    )
    assert not LLMProvider._is_quota_or_daily_limit_error("Please try again in 2s.")
    assert not LLMProvider._is_quota_or_daily_limit_error("Something else broke")
