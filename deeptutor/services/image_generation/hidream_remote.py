"""Client for HiDream-O1-Image upstream Flask server.

HiDream-O1-Image is normally run as the upstream ``app.py`` (CUDA required).
Point DeepTutor at that server with:

    HIDREAM_SERVICE_URL=http://127.0.0.1:7860

Download model weights with the Hugging Face CLI using ``HF_TOKEN`` (or
``HUGGINGFACE_HUB_TOKEN``) — never commit tokens to the repository.

API shape matches HiDream-ai/HiDream-O1-Image ``app.py``:
  POST /api/generate/start  -> { "job_id": ... }
  GET  /api/generate/stream/<job_id>  (SSE; final event type \"done\" carries PNG base64)
"""

from __future__ import annotations

import base64
import json
import logging
import os
from typing import Any
from uuid import uuid4

import httpx

from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)


class HiDreamConfigurationError(ValueError):
    """Raised when HIDREAM_SERVICE_URL is missing or invalid."""


class HiDreamGenerationError(RuntimeError):
    """Raised when the upstream server reports an error or ends without an image."""


def _service_base_url() -> str:
    raw = (os.environ.get("HIDREAM_SERVICE_URL") or "").strip().rstrip("/")
    if not raw:
        raise HiDreamConfigurationError(
            "HIDREAM_SERVICE_URL is not set. Start HiDream-O1-Image "
            "(python app.py from the upstream repo) and set this to its base URL, "
            "e.g. http://127.0.0.1:7860"
        )
    return raw


def _optional_auth_headers() -> dict[str, str]:
    token = (os.environ.get("HIDREAM_SERVICE_TOKEN") or "").strip()
    if token:
        return {"Authorization": f"Bearer {token}"}
    return {}


def _timeout_seconds() -> float:
    raw = (os.environ.get("HIDREAM_SERVICE_TIMEOUT") or "").strip()
    if raw:
        try:
            return max(60.0, float(raw))
        except ValueError:
            logger.warning("Invalid HIDREAM_SERVICE_TIMEOUT=%r; using default", raw)
    return 900.0


def _parse_sse_data_line(line: str) -> dict[str, Any] | None:
    s = line.strip()
    if not s.startswith("data:"):
        return None
    payload = s[5:].strip()
    if payload == "[DONE]":
        return None
    try:
        return json.loads(payload)
    except json.JSONDecodeError:
        return None


async def generate_hidream_t2i_png(
    *,
    prompt: str,
    width: int = 1024,
    height: int = 1024,
    seed: int = 32,
) -> bytes:
    """Run text-to-image on the configured HiDream Flask server; return PNG bytes."""
    base = _service_base_url()
    headers = {"Accept": "text/event-stream", **_optional_auth_headers()}
    timeout = httpx.Timeout(_timeout_seconds(), connect=30.0)

    payload = {
        "prompt": prompt.strip(),
        "mode": "t2i",
        "width": int(width),
        "height": int(height),
        "seed": int(seed),
        "refs_b64": [],
        "keep_original_aspect": False,
    }

    async with httpx.AsyncClient(timeout=timeout) as client:
        start_res = await client.post(
            f"{base}/api/generate/start",
            json=payload,
            headers={**_optional_auth_headers(), "Content-Type": "application/json"},
        )
        start_res.raise_for_status()
        body = start_res.json()
        job_id = body.get("job_id")
        if not job_id:
            raise HiDreamGenerationError("HiDream start response missing job_id")

        stream_url = f"{base}/api/generate/stream/{job_id}"
        async with client.stream("GET", stream_url, headers=headers) as stream:
            stream.raise_for_status()
            image_b64: str | None = None
            async for line in stream.aiter_lines():
                evt = _parse_sse_data_line(line)
                if not evt:
                    continue
                etype = evt.get("type")
                if etype == "error":
                    raise HiDreamGenerationError(
                        str(evt.get("message") or evt.get("error") or "generation failed")
                    )
                if etype == "done":
                    image_b64 = evt.get("image")
                    break

        if not image_b64:
            raise HiDreamGenerationError("HiDream stream ended without image data")

        try:
            return base64.b64decode(image_b64)
        except Exception as exc:
            raise HiDreamGenerationError("Invalid base64 image payload") from exc


def save_hidream_png_to_chat_workspace(data: bytes) -> str:
    """Write PNG under workspace/chat/chat/hidream and return posix path relative to user data root."""
    ps = get_path_service()
    out_dir = ps.get_chat_feature_dir("chat") / "hidream"
    out_dir.mkdir(parents=True, exist_ok=True)
    name = f"{uuid4().hex}.png"
    path = out_dir / name
    path.write_bytes(data)
    rel = path.relative_to(ps.get_public_outputs_root())
    return rel.as_posix()
