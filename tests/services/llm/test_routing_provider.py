"""Tests for the routing provider wrapper."""

import asyncio
from collections.abc import AsyncGenerator

import pytest


@pytest.fixture(autouse=True)
def _reset_circuit_breaker() -> None:
    """Reset circuit breaker and error-rate state between tests.

    Other tests in the suite may trigger failures on the "routing" provider
    that leave the circuit breaker open. These routing provider tests need
    a clean slate.
    """
    from deeptutor.utils.error_rate_tracker import tracker as _error_tracker
    from deeptutor.utils.network.circuit_breaker import circuit_breaker

    with circuit_breaker.lock:
        for prov in list(circuit_breaker.state.keys()):
            circuit_breaker.state[prov] = "closed"
            circuit_breaker.failure_count[prov] = 0
    _error_tracker._total_calls.clear()
    _error_tracker._errors.clear()
    _error_tracker._alerted.clear()

from deeptutor.services.llm.config import LLMConfig
from deeptutor.services.llm.exceptions import LLMConfigError, LLMRateLimitError
from deeptutor.services.llm.factory import complete
from deeptutor.services.llm.providers.routing import RoutingProvider


async def _collect_stream(provider: RoutingProvider) -> list[object]:
    chunks: list[object] = []
    async for chunk in provider.stream("hello", max_retries=0):
        chunks.append(chunk)
    return chunks


def test_routing_provider_local_complete(monkeypatch) -> None:
    """Routing provider should delegate to local provider for local URLs."""

    async def _fake_local_complete(**_kwargs: object) -> str:
        return "local"

    monkeypatch.setattr(
        "deeptutor.services.llm.local_provider.complete",
        _fake_local_complete,
    )

    config = LLMConfig(model="test", api_key="", base_url="http://localhost:11434")
    provider = RoutingProvider(config)
    result = asyncio.run(provider.complete("hello", use_cache=False, max_retries=0))

    assert result.content == "local"
    assert result.provider == "local"


def test_routing_provider_cloud_complete(monkeypatch) -> None:
    """Routing provider should delegate to cloud provider for remote URLs."""

    async def _fake_cloud_complete(**_kwargs: object) -> str:
        return "cloud"

    monkeypatch.setattr(
        "deeptutor.services.llm.cloud_provider.complete",
        _fake_cloud_complete,
    )

    config = LLMConfig(model="test", api_key="", base_url="https://api.openai.com")
    provider = RoutingProvider(config)
    result = asyncio.run(provider.complete("hello", use_cache=False, max_retries=0))

    assert result.content == "cloud"
    assert result.provider == "routing"


def test_routing_provider_stream(monkeypatch) -> None:
    """Routing provider should emit accumulated stream chunks."""

    async def _fake_stream(**_kwargs: object) -> AsyncGenerator[str, None]:
        yield "A"
        yield "B"

    monkeypatch.setattr("deeptutor.services.llm.local_provider.stream", _fake_stream)

    config = LLMConfig(model="test", api_key="", base_url="http://localhost:1234")
    provider = RoutingProvider(config)
    chunks = asyncio.run(_collect_stream(provider))

    assert chunks
    assert chunks[-1].is_complete is True
    assert chunks[-1].content == "AB"


def test_routing_complete_rate_limit_fallback(monkeypatch) -> None:
    """After rate limit on primary model, one immediate retry with fallback model."""
    calls: list[str] = []

    async def _fake_cloud_complete(**kwargs: object) -> str:
        m = str(kwargs.get("model") or "")
        calls.append(m)
        if m == "big-model":
            raise LLMRateLimitError("TPD exhausted")
        return "fallback-body"

    monkeypatch.setattr(
        "deeptutor.services.llm.cloud_provider.complete",
        _fake_cloud_complete,
    )
    monkeypatch.setenv("LLM_RATE_LIMIT_FALLBACK_MODEL", "small-model")

    config = LLMConfig(
        model="big-model",
        api_key="sk-test",
        base_url="https://api.groq.com/openai/v1",
        binding="openai",
    )
    provider = RoutingProvider(config)
    result = asyncio.run(
        provider.complete(
            "hello",
            model="big-model",
            use_cache=False,
            max_retries=0,
        )
    )

    assert result.content == "fallback-body"
    assert result.model == "small-model"
    assert calls == ["big-model", "small-model"]
    monkeypatch.delenv("LLM_RATE_LIMIT_FALLBACK_MODEL", raising=False)


def test_routing_stream_rate_limit_fallback(monkeypatch) -> None:
    """Stream retries once with fallback model when stream start hits rate limit."""

    async def _fake_stream(**kwargs: object) -> AsyncGenerator[str, None]:
        m = str(kwargs.get("model") or "")
        if m == "big-model":
            raise LLMRateLimitError("TPD exhausted")
        yield "ok"

    monkeypatch.setattr("deeptutor.services.llm.cloud_provider.stream", _fake_stream)
    monkeypatch.setenv("LLM_RATE_LIMIT_FALLBACK_MODEL", "small-model")

    config = LLMConfig(
        model="big-model",
        api_key="sk-test",
        base_url="https://api.groq.com/openai/v1",
        binding="openai",
    )
    provider = RoutingProvider(config)

    async def _run() -> list[object]:
        out: list[object] = []
        async for ch in provider.stream("hello", model="big-model", max_retries=0):
            out.append(ch)
        return out

    chunks = asyncio.run(_run())
    assert chunks[-1].is_complete is True
    assert chunks[-1].content == "ok"
    assert chunks[-1].model == "small-model"
    monkeypatch.delenv("LLM_RATE_LIMIT_FALLBACK_MODEL", raising=False)


def test_factory_rejects_remote_no_key_before_provider_call(monkeypatch) -> None:
    async def _unexpected_cloud_call(**_kwargs: object) -> str:
        raise AssertionError("cloud provider should not be called without credentials")

    monkeypatch.setattr(
        "deeptutor.services.llm.cloud_provider.complete",
        _unexpected_cloud_call,
    )

    with pytest.raises(LLMConfigError, match="No API key configured"):
        asyncio.run(
            complete(
                "hello",
                model="Qwen/Qwen3-32B",
                api_key="no-key",
                base_url="https://router.huggingface.co/v1",
                binding="huggingface",
                max_retries=0,
            )
        )
