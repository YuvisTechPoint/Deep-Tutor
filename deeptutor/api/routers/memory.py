"""
Two-file public memory API: SUMMARY and PROFILE.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from deeptutor.services.memory import MemoryFile, get_memory_service
from deeptutor.services.session import get_session_store

router = APIRouter()
logger = logging.getLogger(__name__)

_VALID_FILES: set[MemoryFile] = {"summary", "profile"}
_VALID_ENHANCE_MODES: set[str] = {"polish", "expand"}


def get_sqlite_session_store():
    """Backward-compatible hook for tests and legacy monkeypatches."""
    return get_session_store()


def _snap_dict(snap) -> dict:
    return {
        "summary": snap.summary,
        "profile": snap.profile,
        "summary_updated_at": snap.summary_updated_at,
        "profile_updated_at": snap.profile_updated_at,
    }


class FileUpdateRequest(BaseModel):
    file: MemoryFile
    content: str = ""


class MemoryRefreshRequest(BaseModel):
    session_id: str | None = None
    language: str = "en"


class MemoryClearRequest(BaseModel):
    file: MemoryFile | None = None


class MemoryEnhanceRequest(BaseModel):
    """Run the active memory file through the LLM to polish or expand it.

    ``mode``:
      - ``"polish"`` — tighten prose, fix grammar/structure, keep the same
                       length and information, output markdown.
      - ``"expand"`` — preserve everything in the input, then expand
                       sparse bullets into 1–3 sentence elaborations and add
                       missing canonical sections (e.g. "Open Questions"
                       for SUMMARY, "Preferences" for PROFILE).
    """

    file: MemoryFile
    content: str = Field(default="", max_length=64_000)
    mode: str = Field(default="polish", pattern="^(polish|expand)$")


@router.get("")
async def get_memory():
    return _snap_dict(get_memory_service().read_snapshot())


@router.put("")
async def update_memory(payload: FileUpdateRequest):
    if payload.file not in _VALID_FILES:
        raise HTTPException(status_code=400, detail=f"Invalid file: {payload.file}")
    snap = get_memory_service().write_file(payload.file, payload.content)
    return {**_snap_dict(snap), "saved": True}


@router.post("/refresh")
async def refresh_memory(payload: MemoryRefreshRequest):
    store = get_sqlite_session_store()
    session_id = str(payload.session_id or "").strip()
    if session_id:
        session = await store.get_session(session_id)
        if session is None:
            raise HTTPException(status_code=404, detail="Session not found")

    result = await get_memory_service().refresh_from_session(
        session_id or None,
        language=payload.language,
    )
    snap = get_memory_service().read_snapshot()
    return {**_snap_dict(snap), "changed": result.changed}


_POLISH_PROMPT = """You are editing a learner's long-form **{file}** memory file. The memory is a
markdown document the AI tutor reads across sessions to stay grounded.

Your job: **polish** the document.

Rules (strict):
- Preserve every fact in the input. Do NOT invent new information.
- Keep the same length (±10%). This is not an expansion pass.
- Fix grammar, tense, parallel structure, and bullet style.
- Use markdown: `##` for sections, `-` bullets, `**bold**` for emphasis.
- Output ONLY the polished markdown — no preamble, no commentary,
  no ``` fences, no trailing "Hope this helps".

Current {file} memory:
---
{content}
---

Polished {file} memory (markdown only):
"""

_EXPAND_PROMPT = """You are editing a learner's long-form **{file}** memory file. The memory is a
markdown document the AI tutor reads across sessions to stay grounded.

Your job: **expand and deepen** the document.

Rules (strict):
- Preserve every existing fact and section. Only ADD detail.
- For each existing bullet, elaborate to 1-3 sentences if it is currently a
  single fragment.
- If standard sections are missing for this file, add them. For a SUMMARY:
  `## Current Focus`, `## Accomplishments`, `## Open Questions`,
  `## Next Steps`. For a PROFILE: `## Identity`, `## Learning Style`,
  `## Knowledge Level`, `## Preferences`, `## Strengths & Gaps`.
- Stay specific to the learner — do NOT add generic filler. If you have no
  information for a new section, give it a single placeholder bullet like
  `- (to be discovered from upcoming sessions)`.
- Use markdown: `##` for sections, `-` bullets, `**bold**` for emphasis.
- Output ONLY the expanded markdown — no preamble, no commentary,
  no ``` fences.

Current {file} memory:
---
{content}
---

Expanded {file} memory (markdown only):
"""


@router.post("/enhance")
async def enhance_memory(payload: MemoryEnhanceRequest) -> dict:
    """Run the memory file through the LLM in `polish` or `expand` mode.

    Returns the enhanced content but does **not** persist it — the client
    decides whether to save (by hitting `PUT /api/v1/memory`).
    """
    if payload.file not in _VALID_FILES:
        raise HTTPException(status_code=400, detail=f"Invalid file: {payload.file}")
    if payload.mode not in _VALID_ENHANCE_MODES:
        raise HTTPException(status_code=400, detail=f"Invalid mode: {payload.mode}")

    raw = (payload.content or "").strip()
    if not raw:
        # Fall back to the persisted memory so the user can hit "Make it more
        # detailed" without first pasting anything.
        snap = get_memory_service().read_snapshot()
        raw = (snap.summary if payload.file == "summary" else snap.profile) or ""
    if not raw.strip():
        raise HTTPException(
            status_code=400,
            detail="No content to enhance. Write a few bullets first.",
        )

    template = _POLISH_PROMPT if payload.mode == "polish" else _EXPAND_PROMPT
    prompt = template.format(file=payload.file, content=raw)

    # Late imports keep the router lightweight if the LLM stack is optional.
    try:
        from deeptutor.services.llm import complete as llm_complete
        from deeptutor.services.llm.config import get_llm_config
        from deeptutor.services.model_router import get_model_router
    except ImportError as exc:
        raise HTTPException(
            status_code=503,
            detail=f"LLM stack is not installed: {exc}",
        ) from exc

    router_inst = get_model_router()
    routed = router_inst.route_feature("chat")
    llm_cfg = get_llm_config()
    api_key = routed.api_key or llm_cfg.api_key
    base_url = routed.api_base if routed.api_key else (llm_cfg.base_url or routed.api_base)
    model = routed.model if routed.api_key else (llm_cfg.model or routed.model)

    try:
        enhanced = await llm_complete(
            prompt=prompt,
            system_prompt=(
                "You are a meticulous editor for a learner's long-form memory."
                " You preserve facts, write in concise markdown, and never add"
                " commentary outside the markdown body."
            ),
            model=model,
            api_key=api_key,
            base_url=base_url,
            temperature=0.4 if payload.mode == "polish" else 0.55,
        )
    except Exception as exc:  # noqa: BLE001 — surface a clean error to the UI
        logger.exception("Memory enhance failed")
        raise HTTPException(
            status_code=503,
            detail=(
                "AI enhancement is unavailable. Check the LLM provider "
                f"(HF_TOKEN / LOCAL_LLM_BASE_URL). Details: {exc}"
            ),
        ) from exc

    cleaned = (enhanced or "").strip()
    # Strip the occasional ``` fence the model adds despite instructions.
    if cleaned.startswith("```"):
        cleaned = cleaned.split("\n", 1)[-1] if "\n" in cleaned else ""
        if cleaned.endswith("```"):
            cleaned = cleaned[: -3].rstrip()

    if not cleaned:
        raise HTTPException(
            status_code=502,
            detail="Model returned an empty response. Please retry.",
        )

    return {
        "file": payload.file,
        "mode": payload.mode,
        "content": cleaned,
        "original": raw,
        "model": model,
    }


@router.post("/clear")
async def clear_memory(payload: MemoryClearRequest | None = None):
    svc = get_memory_service()
    target = payload.file if payload else None
    if target and target not in _VALID_FILES:
        raise HTTPException(status_code=400, detail=f"Invalid file: {target}")

    if target:
        snap = svc.clear_file(target)
    else:
        snap = svc.clear_memory()
    return {**_snap_dict(snap), "cleared": True}
