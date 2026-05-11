"""Hugging Face OpenAI-compatible inference router — env tokens and base URL helpers.

This module must not import ``deeptutor.services.llm`` (package ``__init__``
pulls in ``llm.config``, which imports ``provider_runtime``).
"""

from __future__ import annotations

import os
import re
from urllib.parse import urlparse

# OpenAI-compatible inference router (not the Hugging Face website).
HF_OPENAI_COMPAT_ROUTER_BASE = "https://router.huggingface.co/v1"
_HF_HUB_WEB_HOSTS = frozenset(
    {"huggingface.co", "www.huggingface.co", "hf.co", "www.hf.co"}
)


def hf_hub_token_from_env() -> str:
    """Return the first non-empty Hugging Face token from known env vars.

    Any one of these is sufficient for ``router.huggingface.co``. Never log or
    echo returned values.
    """
    for key in (
        "HF_TOKEN",
        "HF_API_TOKEN",
        "HF_ACCESS_TOKEN",
        "HUGGINGFACE_HUB_TOKEN",
        "HUGGING_FACE_HUB_TOKEN",
        "HUGGINGFACE_TOKEN",
    ):
        value = (os.environ.get(key) or "").strip()
        if value:
            return value
    return ""


def normalize_hf_openai_compat_base_url(base_url: str | None) -> str:
    """Rewrite Hub *website* origins to the OpenAI-compatible inference router."""
    raw = (base_url or "").strip().rstrip("/")
    if not raw:
        return HF_OPENAI_COMPAT_ROUTER_BASE

    if not re.match(r"^[a-zA-Z]+://", raw):
        raw = f"https://{raw}"

    try:
        parsed = urlparse(raw)
    except ValueError:
        return raw

    host = (parsed.hostname or "").lower()
    if host in _HF_HUB_WEB_HOSTS:
        return HF_OPENAI_COMPAT_ROUTER_BASE
    return raw


__all__ = [
    "HF_OPENAI_COMPAT_ROUTER_BASE",
    "hf_hub_token_from_env",
    "normalize_hf_openai_compat_base_url",
]
