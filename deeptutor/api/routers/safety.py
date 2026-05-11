"""Safety / moderation router — Llama Guard 3 moderation (self-hosted first).

Exposes:
  POST /api/v1/safety/moderate   — check text for unsafe content
  GET  /api/v1/safety/status     — service availability check

Llama Guard 3 returns a structured verdict: "safe" or "unsafe" with category codes.
This router is used by the Safety Agent to screen inputs and outputs.
"""
from __future__ import annotations

import logging
import os

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from deeptutor.services.hf_openai_compat import hf_hub_token_from_env
from deeptutor.services.llm.utils import normalize_hf_openai_compat_base_url

router = APIRouter()
logger = logging.getLogger(__name__)

_GUARD_MODEL = "meta-llama/Llama-Guard-3-8B"
_HF_BASE = "https://router.huggingface.co/v1"
_DEFAULT_TIMEOUT = 30.0

# Llama Guard 3 category codes → human-readable labels
_CATEGORY_LABELS: dict[str, str] = {
    "S1": "Violent Crimes",
    "S2": "Non-Violent Crimes",
    "S3": "Sex Crimes",
    "S4": "Child Exploitation",
    "S5": "Defamation",
    "S6": "Specialized Advice",
    "S7": "Privacy",
    "S8": "Intellectual Property",
    "S9": "Indiscriminate Weapons",
    "S10": "Hate",
    "S11": "Self-Harm",
    "S12": "Sexual Content",
    "S13": "Elections",
    "S14": "Code Interpreter Abuse",
}

_GUARD_SYSTEM = (
    "You are a content safety classifier. "
    "Evaluate the following message and respond ONLY with 'safe' or 'unsafe\\n<category_code>'."
)


def _hf_token() -> str:
    return hf_hub_token_from_env()


def _safety_base() -> str:
    # Prefer self-hosted moderation endpoint when configured.
    raw = (
        os.environ.get("SAFETY_BASE_URL")
        or os.environ.get("ROUTER_SAFETY_BASE_URL")
        or os.environ.get("FASTAPI_INFERENCE_BASE_URL")
        or os.environ.get("HF_INFERENCE_BASE_URL")
        or _HF_BASE
    ).strip().rstrip("/")
    return normalize_hf_openai_compat_base_url(raw).rstrip("/")


def _safety_auth_token() -> str:
    return (
        os.environ.get("SAFETY_API_KEY")
        or os.environ.get("ROUTER_SAFETY_API_KEY")
        or _hf_token()
    ).strip()


class ModerationRequest(BaseModel):
    text: str = Field(..., max_length=8192, description="Text to moderate.")
    role: str = Field(
        "user",
        description="'user' for input screening, 'assistant' for output screening.",
    )


class ModerationResponse(BaseModel):
    safe: bool
    verdict: str  # "safe" | "unsafe"
    categories: list[str] = []
    category_labels: list[str] = []
    model: str = _GUARD_MODEL
    raw: str = ""


class SafetyStatusResponse(BaseModel):
    available: bool
    model: str = _GUARD_MODEL
    detail: str = ""


def _parse_guard_response(raw: str) -> tuple[bool, list[str]]:
    """Parse Llama Guard response into (is_safe, category_codes)."""
    text = raw.strip().lower()
    if text.startswith("safe"):
        return True, []
    # "unsafe\nS1,S10" or "unsafe\nS1"
    lines = raw.strip().splitlines()
    codes: list[str] = []
    if len(lines) > 1:
        for part in lines[1].replace(",", " ").split():
            code = part.strip().upper()
            if code:
                codes.append(code)
    return False, codes


@router.get("/safety/status", response_model=SafetyStatusResponse)
async def safety_status() -> SafetyStatusResponse:
    token = _safety_auth_token()
    base = _safety_base()
    if not token:
        return SafetyStatusResponse(
            available=False,
            detail="No safety token configured. Set SAFETY_API_KEY or HF_TOKEN.",
        )
    return SafetyStatusResponse(
        available=True,
        detail=f"Llama Guard 3 ready ({base})",
    )


@router.post("/safety/moderate", response_model=ModerationResponse)
async def moderate_content(body: ModerationRequest) -> ModerationResponse:
    """Run Llama Guard 3 content moderation on the supplied text.

    Returns a verdict ("safe" or "unsafe") plus any triggered safety categories.
    Fails open (returns safe=True) if the moderation service is unavailable,
    to prevent false blocking of legitimate educational queries.
    """
    token = _safety_auth_token()
    if not token:
        logger.warning("Safety moderation skipped — SAFETY_API_KEY/HF_TOKEN not configured.")
        return ModerationResponse(safe=True, verdict="safe", raw="token_missing")

    base = _safety_base()
    url = f"{base}/chat/completions"

    payload = {
        "model": _GUARD_MODEL,
        "messages": [
            {"role": "system", "content": _GUARD_SYSTEM},
            {"role": "user", "content": body.text},
        ],
        "max_tokens": 64,
        "temperature": 0.0,
    }

    try:
        timeout = float(os.environ.get("HF_SAFETY_TIMEOUT", _DEFAULT_TIMEOUT))
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
    except httpx.TimeoutException:
        logger.warning("Llama Guard API timed out — failing open.")
        return ModerationResponse(safe=True, verdict="safe", raw="timeout")
    except httpx.RequestError as exc:
        logger.warning("Llama Guard network error: %s — failing open.", exc)
        return ModerationResponse(safe=True, verdict="safe", raw=f"network_error:{exc}")

    if resp.status_code != 200:
        logger.warning("Llama Guard API returned %d — failing open.", resp.status_code)
        return ModerationResponse(safe=True, verdict="safe", raw=f"http_{resp.status_code}")

    data = resp.json()
    raw_text = data.get("choices", [{}])[0].get("message", {}).get("content", "safe")
    is_safe, codes = _parse_guard_response(raw_text)

    return ModerationResponse(
        safe=is_safe,
        verdict="safe" if is_safe else "unsafe",
        categories=codes,
        category_labels=[_CATEGORY_LABELS.get(c, c) for c in codes],
        raw=raw_text.strip(),
    )
