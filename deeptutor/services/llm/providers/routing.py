"""Routing provider bridging legacy provider functions.

This provider delegates to the existing function-based providers
(`cloud_provider` / `local_provider`) while inheriting the hardened
execution pipeline from `BaseLLMProvider` (traffic control, circuit
breaker, and exception mapping).

It exists to keep the public API stable while incrementally migrating
call sites to provider objects.
"""

from __future__ import annotations

import asyncio
from importlib import import_module
import logging
from typing import Protocol, cast

from ..config import LLMConfig
from ..exceptions import LLMConfigError, LLMRateLimitError
from ..rate_limit_fallback import rate_limit_fallback_model
from ..registry import register_provider
from ..types import AsyncStreamGenerator, TutorResponse, TutorStreamChunk
from ..utils import is_local_llm_server
from .base_provider import BaseLLMProvider

cloud_provider = import_module("deeptutor.services.llm.cloud_provider")
local_provider = import_module("deeptutor.services.llm.local_provider")

logger = logging.getLogger(__name__)


class CacheModule(Protocol):
    """Protocol for optional cache module bindings."""

    DEFAULT_CACHE_TTL: int

    @staticmethod
    def build_completion_cache_key(**kwargs: object) -> str: ...

    @staticmethod
    async def get_cached_completion(key: str) -> str | None: ...

    @staticmethod
    async def set_cached_completion(
        key: str,
        value: str,
        *,
        ttl_seconds: int,
    ) -> None: ...


def _coerce_int(value: object, default: int) -> int:
    if isinstance(value, bool):
        return default
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.isdigit():
        return int(value)
    return default


def _coerce_str(value: object, default: str) -> str:
    return value if isinstance(value, str) and value else default


@register_provider("routing")
class RoutingProvider(BaseLLMProvider):
    """Provider that routes between cloud and local function providers."""

    def __init__(self, config: LLMConfig) -> None:
        super().__init__(config)
        # Use per-route provider name for circuit-breaker/metrics when possible.
        if is_local_llm_server(self.base_url or ""):
            self.provider_name = "local"

    async def complete(self, prompt: str, **kwargs: object) -> TutorResponse:
        """Complete via local_provider/cloud_provider with retries."""
        model = _coerce_str(kwargs.pop("model", None), self.config.model)
        if not model:
            raise LLMConfigError("Model is required")

        system_prompt = kwargs.pop("system_prompt", "You are a helpful assistant.")
        messages = kwargs.pop("messages", None)
        max_retries = _coerce_int(kwargs.pop("max_retries", 3), 3)
        sleep_value = kwargs.pop("sleep", None)
        sleep = sleep_value if callable(sleep_value) else None

        use_cache = bool(kwargs.pop("use_cache", True))
        cache_ttl_seconds = kwargs.pop("cache_ttl_seconds", None)
        cache_key = kwargs.pop("cache_key", None)

        call_kwargs = {
            "prompt": prompt,
            "system_prompt": system_prompt,
            "model": model,
            "api_key": self.api_key,
            "base_url": self.base_url,
            "messages": messages,
            **kwargs,
        }

        if is_local_llm_server(self.base_url or ""):
            target = local_provider.complete
        else:
            binding = _coerce_str(kwargs.pop("binding", None), self.config.binding)
            api_version = kwargs.pop("api_version", None) or self.config.api_version
            call_kwargs["binding"] = binding
            call_kwargs["api_version"] = api_version
            target = cloud_provider.complete

        async def _call() -> str:
            cache_enabled = use_cache
            cache_module: CacheModule | None = None
            if cache_enabled:
                try:
                    # Import lazily to keep routing provider lightweight.
                    module = import_module("deeptutor.services.llm.cache")
                    cache_module = cast(CacheModule, module)
                except ModuleNotFoundError:
                    logger.warning("LLM cache module unavailable; disabling routing cache.")
                    cache_enabled = False

            if cache_enabled and cache_module is not None:
                computed_cache_key = _coerce_str(cache_key, "")
                if not computed_cache_key:
                    computed_cache_key = cache_module.build_completion_cache_key(
                        model=model,
                        binding=str(call_kwargs.get("binding") or "openai"),
                        base_url=call_kwargs.get("base_url"),
                        system_prompt=system_prompt,
                        prompt=prompt,
                        messages=messages,
                        **{
                            k: v
                            for k, v in call_kwargs.items()
                            if k
                            not in {
                                "prompt",
                                "system_prompt",
                                "messages",
                                "model",
                                "api_key",
                                "base_url",
                                "binding",
                            }
                        },
                    )
                cached = await cache_module.get_cached_completion(computed_cache_key)
                if cached is not None:
                    return cached

                result = str(await target(**call_kwargs))
                await cache_module.set_cached_completion(
                    computed_cache_key,
                    result,
                    ttl_seconds=_coerce_int(
                        cache_ttl_seconds or cache_module.DEFAULT_CACHE_TTL,
                        cache_module.DEFAULT_CACHE_TTL,
                    ),
                )
                return result

            return str(await target(**call_kwargs))

        fallback_primary = rate_limit_fallback_model(model)
        effective_retries = 0 if fallback_primary else max_retries

        try:
            text = await self.execute_with_retry(
                _call,
                max_retries=effective_retries,
                sleep=sleep,
            )
        except LLMRateLimitError:
            fb = rate_limit_fallback_model(model)
            if not fb:
                raise
            logger.warning(
                "Primary model %r rate limited; retrying completion once with %r",
                model,
                fb,
            )
            call_kwargs["model"] = fb
            text = await self.execute(_call)
            model = fb

        return TutorResponse(
            content=str(text),
            raw_response={},
            usage={
                "prompt_tokens": 0,
                "completion_tokens": 0,
                "total_tokens": 0,
            },
            provider=self.provider_name,
            model=model,
            finish_reason=None,
            cost_estimate=0.0,
        )

    def stream(self, prompt: str, **kwargs: object) -> AsyncStreamGenerator:
        """Stream via local_provider/cloud_provider.

        Retry applies only to failures before the first yielded chunk.
        """
        model = _coerce_str(kwargs.pop("model", None), self.config.model)
        if not model:
            raise LLMConfigError("Model is required")

        system_prompt = kwargs.pop("system_prompt", "You are a helpful assistant.")
        messages = kwargs.pop("messages", None)
        max_retries = _coerce_int(kwargs.pop("max_retries", 3), 3)

        call_kwargs = {
            "prompt": prompt,
            "system_prompt": system_prompt,
            "model": model,
            "api_key": self.api_key,
            "base_url": self.base_url,
            "messages": messages,
            **kwargs,
        }

        if is_local_llm_server(self.base_url or ""):
            stream_func = local_provider.stream
        else:
            binding = _coerce_str(kwargs.pop("binding", None), self.config.binding)
            api_version = kwargs.pop("api_version", None) or self.config.api_version
            call_kwargs["binding"] = binding
            call_kwargs["api_version"] = api_version
            stream_func = cloud_provider.stream

        async def _stream() -> AsyncStreamGenerator:
            nonlocal model
            attempt = 0
            used_rl_fallback = False
            while True:
                attempt += 1
                emitted_any = False
                accumulated = ""

                try:
                    self._check_circuit_breaker()
                    async with self.traffic_controller:
                        iterator = stream_func(**call_kwargs)
                        async for delta in iterator:
                            emitted_any = True
                            accumulated += str(delta)
                            yield TutorStreamChunk(
                                content=accumulated,
                                delta=str(delta),
                                provider=self.provider_name,
                                model=model,
                                is_complete=False,
                            )

                        yield TutorStreamChunk(
                            content=accumulated,
                            delta="",
                            provider=self.provider_name,
                            model=model,
                            is_complete=True,
                        )
                        return
                except asyncio.CancelledError:
                    raise
                except Exception as exc:
                    mapped = self._map_exception(exc)
                    if emitted_any:
                        raise mapped from exc

                    fb = rate_limit_fallback_model(str(call_kwargs.get("model") or model))
                    if (
                        not used_rl_fallback
                        and isinstance(mapped, LLMRateLimitError)
                        and fb
                    ):
                        used_rl_fallback = True
                        call_kwargs["model"] = fb
                        model = fb
                        attempt = 0
                        logger.warning(
                            "Primary stream model rate limited; retrying with fallback %r",
                            fb,
                        )
                        continue

                    if attempt > max_retries + 1 or not self._should_retry_error(mapped):
                        raise mapped from exc

                    delay_seconds = min(60.0, 1.5**attempt)
                    logger.warning(
                        "Stream start failed (attempt %d/%d): %s; retrying in %.2fs"
                        % (attempt, max_retries + 1, mapped, delay_seconds)
                    )
                    await asyncio.sleep(delay_seconds)

        return _stream()
