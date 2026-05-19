"""Realtime, question-specific practice hints (no answer leakage)."""

from __future__ import annotations

import json
import logging
import re

from deeptutor.services.llm.rate_limit_fallback import (
    looks_like_rate_or_quota_error,
    rate_limit_fallback_model,
)
from deeptutor.services.model_router import Intent
from deeptutor.services.practice.bank import Question
from deeptutor.services.practice.cache import get_cached_hint, store_hint
from deeptutor.services.practice.generator import (
    _JSON_BLOCK_RE,
    _TOPIC_ROUTING,
    _ask_llm,
    _resolve_practice_model,
    _strip_to_json,
)

logger = logging.getLogger(__name__)

_HINT_PROMPT = """You are a supportive tutor giving a short hint for one multiple-choice question.

Topic: {topic}
Difficulty: {difficulty}
Tags: {tags}

Question:
{question}

Options (do NOT name which letter is correct):
{options_block}

Write ONE hint (1–2 sentences) that:
- Helps the learner reason about THIS specific question only.
- Points at the underlying concept or how to eliminate wrong options.
- Does NOT state or imply the correct letter (A/B/C/D).
- Does NOT quote the full correct option text verbatim.

Return ONLY valid JSON:
{{"hint": "<your hint text>"}}
"""


def _options_block(options: dict[str, str]) -> str:
    lines = [f"{k}) {v}" for k, v in sorted(options.items())]
    return "\n".join(lines)


def _fallback_hint(q: Question) -> str:
    """Deterministic nudge when the LLM is unavailable — still question-specific."""
    stem = q.question.strip()
    if len(stem) > 120:
        stem = stem[:117].rstrip() + "…"
    tag = q.tags[0] if q.tags else q.topic.replace("_", " ")
    return (
        f"Re-read what the question is really asking about “{stem}”. "
        f"Think in terms of {tag}: rule out options that contradict the core idea."
    )


def _parse_hint_json(raw: str) -> str | None:
    try:
        parsed = json.loads(_strip_to_json(raw))
    except json.JSONDecodeError:
        m = _JSON_BLOCK_RE.search(raw or "")
        if not m:
            return None
        try:
            parsed = json.loads(m.group(0))
        except json.JSONDecodeError:
            return None
    if not isinstance(parsed, dict):
        return None
    hint = str(parsed.get("hint") or "").strip()
    if not hint or len(hint) < 12:
        return None
    # Block obvious answer leaks (letter + "correct" patterns).
    if re.search(r"\b(correct answer is|answer is)\s*[A-D]\b", hint, re.I):
        return None
    if re.search(r"\b(option|choice)\s+[A-D]\b.*\b(correct|right)\b", hint, re.I):
        return None
    return hint[:500]


async def generate_question_hint(q: Question) -> str:
    """LLM hint for a cached question; falls back to a local heuristic."""
    role, intent = _TOPIC_ROUTING.get(q.topic, ("general", Intent.ASSESSMENT))
    prompt = _HINT_PROMPT.format(
        topic=q.topic,
        difficulty=q.difficulty,
        tags=", ".join(q.tags) if q.tags else q.topic,
        question=q.question.strip(),
        options_block=_options_block(q.options),
    )
    primary = _resolve_practice_model(intent, role)
    fallback = rate_limit_fallback_model(primary)
    models: list[str | None] = [None] + ([fallback] if fallback else [])

    last_err: str | None = None
    for forced in models:
        try:
            raw = await _ask_llm(
                prompt,
                intent=intent,
                role=role,
                max_tokens=220,
                force_model=forced,
            )
            hint = _parse_hint_json(raw)
            if hint:
                return hint
            last_err = "Model hint JSON was empty or invalid."
        except Exception as exc:  # noqa: BLE001
            last_err = str(exc)
            logger.warning("Practice hint LLM failure (model=%r): %s", forced or primary, exc)
            if forced is None and fallback and looks_like_rate_or_quota_error(last_err):
                continue
            break

    logger.info("Practice hint using fallback for %s: %s", q.id, last_err)
    return _fallback_hint(q)


async def get_question_hint(quiz_id: str, q: Question) -> str:
    """Return a cached hint or generate one and store it on the quiz entry."""
    cached = get_cached_hint(quiz_id, q.id)
    if cached:
        return cached
    hint = await generate_question_hint(q)
    store_hint(quiz_id, q.id, hint)
    return hint


__all__ = ["generate_question_hint", "get_question_hint"]
