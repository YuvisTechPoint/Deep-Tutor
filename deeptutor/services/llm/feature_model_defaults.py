"""Defaults for JSON-heavy tutor surfaces (Practice MCQ, Code lab generation).

These ids are chosen for **broad provider support**, **stable APIs**, and
**instruction-following** suitable for strict JSON — not for long-form chat.

Override per deployment with ``LLM_MODEL_PRACTICE`` (MCQ) and/or
``LLM_MODEL_CODING_PRACTICE`` (Code lab); router ``HF_MODEL_PRACTICE_*`` still
wins when using the Hugging Face inference path (``routed.api_key``).
"""

from __future__ import annotations

# Groq OpenAI-compatible: long-lived small instruct tier (docs / dashboard stable).
GROQ_STRUCTURED_MODEL = "llama-3.1-8b-instant"
# If the primary small model is still over quota, step down once more on Groq.
GROQ_STRUCTURED_FALLBACK_MODEL = "llama-3.2-3b-preview"

# Public OpenAI API (not Azure): low-latency JSON-friendly default.
OPENAI_STRUCTURED_MODEL = "gpt-4o-mini"


def _joined_urls(base_url: str | None, effective_url: str | None) -> str:
    return f"{base_url or ''} {effective_url or ''}".lower()


def is_groq_host(base_url: str | None, effective_url: str | None = None) -> bool:
    return "groq.com" in _joined_urls(base_url, effective_url)


def is_openai_api_host(base_url: str | None, effective_url: str | None = None) -> bool:
    s = _joined_urls(base_url, effective_url)
    if "azure" in s:
        return False
    return "api.openai.com" in s or ".openai.com" in s


def default_structured_output_model(
    base_url: str | None,
    effective_url: str | None = None,
) -> str | None:
    """Model id for MCQ/codegen when the user has not set a practice-specific override.

    Returns ``None`` for self-hosted / HF-router / unknown hosts so callers keep
    ``llm_cfg.model`` or router defaults.
    """
    if is_groq_host(base_url, effective_url):
        return GROQ_STRUCTURED_MODEL
    if is_openai_api_host(base_url, effective_url):
        return OPENAI_STRUCTURED_MODEL
    return None


__all__ = [
    "GROQ_STRUCTURED_FALLBACK_MODEL",
    "GROQ_STRUCTURED_MODEL",
    "OPENAI_STRUCTURED_MODEL",
    "default_structured_output_model",
    "is_groq_host",
    "is_openai_api_host",
]
