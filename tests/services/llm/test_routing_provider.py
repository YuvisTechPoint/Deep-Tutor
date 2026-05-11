"""Tests for the routing provider wrapper."""

import asyncio
from collections.abc import AsyncGenerator

import pytest

from deeptutor.services.llm.config import LLMConfig
from deeptutor.services.llm.exceptions import LLMConfigError
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
