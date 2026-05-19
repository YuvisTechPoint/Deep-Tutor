"""User-facing LLM error text for TutorBot (web chat and channels)."""

from __future__ import annotations

import ast

from deeptutor.services.llm.openai_error_message import user_message_from_openai_exception
from deeptutor.services.llm.rate_limit_fallback import looks_like_rate_or_quota_error


def _strip_error_prefix(raw: str) -> str:
    s = raw.strip()
    low = s.lower()
    for prefix in ("error calling llm:", "error:"):
        if low.startswith(prefix):
            return s[len(prefix) :].strip()
    return s


def _normalize_raw_message(raw: str) -> str:
    if raw.startswith("{") and "message" in raw:
        try:
            parsed = ast.literal_eval(raw)
            if isinstance(parsed, dict) and isinstance(parsed.get("message"), str):
                return parsed["message"].strip()
        except (SyntaxError, ValueError, MemoryError):
            pass
    return user_message_from_openai_exception(ValueError(raw), raw)


def friendly_llm_error_message(content: str | Exception | None) -> str:
    """Turn provider / harness errors into a short message for chat UIs."""
    if isinstance(content, Exception):
        msg = user_message_from_openai_exception(content)
    else:
        msg = _normalize_raw_message(_strip_error_prefix(str(content or "")))

    if looks_like_rate_or_quota_error(msg):
        return (
            "The AI provider rate or daily token limit was reached, so this reply could not be "
            "generated. The backend may automatically retry with a smaller fallback model if one "
            "is configured. You can set `LLM_RATE_LIMIT_FALLBACK_MODEL` to a smaller model (for "
            "example: `llama-3.1-8b-instant`) in your .env, or configure fallbacks via the "
            "Models & Providers admin UI, then restart the backend or re-apply settings. "
            "Alternatively upgrade your provider plan or wait for the quota to reset."
        )
    if len(msg) > 1200:
        return msg[:1200] + "…"
    return msg or "Unknown error"


def llm_error_code(content: str | None) -> str:
    return "rate_limit" if looks_like_rate_or_quota_error(content or "") else "llm_error"


__all__ = ["friendly_llm_error_message", "llm_error_code"]
