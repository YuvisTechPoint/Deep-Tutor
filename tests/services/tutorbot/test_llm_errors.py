"""Tests for TutorBot user-facing LLM error formatting."""

from deeptutor.tutorbot.providers.llm_errors import (
    friendly_llm_error_message,
    llm_error_code,
)


def test_friendly_rate_limit_from_dict_string():
    raw = "{'message': 'Rate limit reached for model llama-3.3-70b-versatile', 'type': 'tokens'}"
    msg = friendly_llm_error_message(raw)
    assert "rate or daily token limit" in msg.lower()
    assert "{" not in msg


def test_friendly_strips_error_calling_prefix():
    raw = "Error calling LLM: connection reset"
    assert friendly_llm_error_message(raw) == "connection reset"


def test_llm_error_code_rate_limit():
    assert llm_error_code("429 rate limit exceeded") == "rate_limit"
    assert llm_error_code("connection reset") == "llm_error"
