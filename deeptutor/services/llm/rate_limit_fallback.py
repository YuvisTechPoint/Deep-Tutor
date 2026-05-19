"""Pick a smaller/alternate model when the primary hits provider rate or daily quotas."""

from __future__ import annotations

import os

from deeptutor.services.llm.feature_model_defaults import (
    GROQ_STRUCTURED_FALLBACK_MODEL,
    GROQ_STRUCTURED_MODEL,
)


def rate_limit_fallback_model(primary: str) -> str | None:
    """Return a replacement model id, or ``None`` if no fallback is configured.

    Resolution order:

    1. ``LLM_RATE_LIMIT_FALLBACK_MODEL`` when set and different from ``primary``.
    2. Built-in pairs for common Groq/OpenAI-compat ids (large → small on the same API).

    The routing provider and feature generators (e.g. Practice Center) use this
    so a single env var—or sensible defaults—covers rate-limit retries.
    """
    p = (primary or "").strip()
    if not p:
        return None

    # Explicit configured fallback; preferred if set and different from primary
    env_fb = (os.getenv("LLM_RATE_LIMIT_FALLBACK_MODEL") or "").strip()
    if env_fb and env_fb != p:
        return env_fb

    low = p.lower()
    built_ins: dict[str, str] = {
        "llama-3.3-70b-versatile": GROQ_STRUCTURED_MODEL,
        "llama-3.1-70b-versatile": GROQ_STRUCTURED_MODEL,
        "llama3-70b-8192": "llama3-8b-8192",
        "mixtral-8x7b-32768": GROQ_STRUCTURED_MODEL,
        # Primary structured default → smaller Groq tier if still throttled
        GROQ_STRUCTURED_MODEL.lower(): GROQ_STRUCTURED_FALLBACK_MODEL,
    }
    fb = built_ins.get(low)
    if fb and fb != p:
        return fb
    # As a final safety, allow a conservative default fallback via
    # `LLM_RATE_LIMIT_FALLBACK_MODEL_DEFAULT` or built-in conservative id.
    default_fb = (
        (os.getenv("LLM_RATE_LIMIT_FALLBACK_MODEL_DEFAULT") or "").strip()
        or "llama-3.1-8b-instant"
    )
    if default_fb and default_fb != p:
        return default_fb
    return None


def looks_like_rate_or_quota_error(message: str) -> bool:
    t = (message or "").lower()
    return any(
        needle in t
        for needle in (
            "429",
            "rate limit",
            "quota",
            "tpd",
            "tokens per day",
            "too many requests",
            "resource exhausted",
        )
    )


__all__ = ["looks_like_rate_or_quota_error", "rate_limit_fallback_model"]
