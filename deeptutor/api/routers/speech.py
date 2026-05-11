"""Speech router — Whisper large-v3 transcription (self-hosted first).

Exposes:
  POST /api/v1/speech/transcribe   — audio → text (multipart upload)
  GET  /api/v1/speech/status       — service availability check
"""
from __future__ import annotations

import io
import logging
import os
from typing import Annotated

import httpx
from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

from deeptutor.services.hf_openai_compat import hf_hub_token_from_env
from deeptutor.services.llm.utils import normalize_hf_openai_compat_base_url

router = APIRouter()
logger = logging.getLogger(__name__)

_WHISPER_MODEL = "openai/whisper-large-v3"
_HF_BASE = "https://router.huggingface.co/v1"
_DEFAULT_TIMEOUT = 120.0


def _hf_token() -> str:
    return hf_hub_token_from_env()


def _speech_base() -> str:
    # Prefer self-hosted speech endpoint when configured.
    raw = (
        os.environ.get("STT_BASE_URL")
        or os.environ.get("ROUTER_SPEECH_BASE_URL")
        or os.environ.get("FASTAPI_INFERENCE_BASE_URL")
        or os.environ.get("HF_INFERENCE_BASE_URL")
        or _HF_BASE
    ).strip().rstrip("/")
    return normalize_hf_openai_compat_base_url(raw).rstrip("/")


def _speech_auth_token() -> str:
    return (
        os.environ.get("STT_API_KEY")
        or os.environ.get("ROUTER_SPEECH_API_KEY")
        or _hf_token()
    ).strip()


class TranscriptionResponse(BaseModel):
    text: str
    language: str | None = None
    duration_s: float | None = None
    model: str = _WHISPER_MODEL


class SpeechStatusResponse(BaseModel):
    available: bool
    model: str = _WHISPER_MODEL
    detail: str = ""


@router.get("/speech/status", response_model=SpeechStatusResponse)
async def speech_status() -> SpeechStatusResponse:
    """Check whether the Whisper transcription service is reachable."""
    token = _speech_auth_token()
    base = _speech_base()
    if not token:
        return SpeechStatusResponse(
            available=False,
            detail="No speech token configured. Set STT_API_KEY or HF_TOKEN.",
        )
    return SpeechStatusResponse(
        available=True,
        detail=f"Whisper large-v3 ready ({base})",
    )


@router.post("/speech/transcribe", response_model=TranscriptionResponse)
async def transcribe_audio(
    file: Annotated[UploadFile, File(description="Audio file (wav, mp3, m4a, ogg, webm)")],
    language: str | None = None,
) -> TranscriptionResponse:
    """Transcribe an audio file using Whisper large-v3 via Hugging Face Inference API.

    Accepts multipart/form-data with an `file` field containing the audio.
    Optional `language` field for forced language detection (ISO 639-1 code).
    """
    token = _speech_auth_token()
    if not token:
        raise HTTPException(
            status_code=503,
            detail="Speech transcription unavailable: STT_API_KEY/HF_TOKEN not configured.",
        )

    audio_bytes = await file.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Empty audio file.")

    if len(audio_bytes) > 25 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Audio file too large (max 25 MB).")

    base = _speech_base()
    url = f"{base}/audio/transcriptions"

    try:
        timeout = float(os.environ.get("HF_SPEECH_TIMEOUT", _DEFAULT_TIMEOUT))
        async with httpx.AsyncClient(timeout=timeout) as client:
            form: dict = {
                "model": _WHISPER_MODEL,
                "file": (file.filename or "audio.wav", io.BytesIO(audio_bytes), file.content_type or "audio/wav"),
                "response_format": "json",
            }
            if language:
                form["language"] = language

            resp = await client.post(
                url,
                headers={"Authorization": f"Bearer {token}"},
                files={"file": (file.filename or "audio.wav", io.BytesIO(audio_bytes), file.content_type or "audio/wav")},
                data={"model": _WHISPER_MODEL, "response_format": "json", **({"language": language} if language else {})},
            )
    except httpx.TimeoutException as exc:
        logger.warning("Whisper API timeout: %s", exc)
        raise HTTPException(status_code=504, detail="Whisper API timed out.") from exc
    except httpx.RequestError as exc:
        logger.error("Whisper API network error: %s", exc)
        raise HTTPException(status_code=502, detail=f"Network error calling Whisper API: {exc}") from exc

    if resp.status_code != 200:
        raise HTTPException(
            status_code=resp.status_code,
            detail=f"Whisper API error {resp.status_code}: {resp.text[:300]}",
        )

    data = resp.json()
    return TranscriptionResponse(
        text=data.get("text", ""),
        language=data.get("language"),
        duration_s=data.get("duration"),
        model=_WHISPER_MODEL,
    )
