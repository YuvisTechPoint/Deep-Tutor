"""Realtime quiz generator.

Every call to :func:`generate_quiz` hits the configured LLM and returns a fresh
set of questions. There is **no pre-defined bank**, no on-disk persistence, and
no deterministic seeding — the only way to obtain a quiz is to ask the model
for one.

The output is validated to a strict :class:`~deeptutor.services.practice.bank.Question`
shape; malformed model output is retried once (with a slightly stricter prompt)
before surfacing an error to the caller.

Routing: the generator picks its model per topic via
:class:`~deeptutor.services.model_router.router.ModelRouter`:

* code-flavoured topics (``python``, ``react``, ``algorithms``, ``dp``,
  ``graphs``, ``db``)            → :attr:`Intent.CODING`
* math-flavoured topics (``math``, ``probability``, ``ml``)
                                 → :attr:`Intent.MATH`
* everything else (``system_design``, …)
                                 → :attr:`Intent.ASSESSMENT` (general)

The ``HF_MODEL_PRACTICE_CODING`` / ``HF_MODEL_PRACTICE_MATH`` /
``HF_MODEL_PRACTICE_GENERAL`` env overrides win over the curated defaults.

On Groq-style OpenAI-compatible hosts, MCQs default to the shared structured-output
model (see ``deeptutor.services.llm.feature_model_defaults``) unless you set
``LLM_MODEL_PRACTICE`` or the ``HF_MODEL_PRACTICE_*`` vars, so Practice Center does
not share the same heavy model as chat by default. On ``api.openai.com``, the default
is ``gpt-4o-mini``.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
from typing import Any
import uuid

from deeptutor.services.llm.feature_model_defaults import default_structured_output_model
from deeptutor.services.llm.rate_limit_fallback import (
    looks_like_rate_or_quota_error,
    rate_limit_fallback_model,
)
from deeptutor.services.model_router import Intent, get_model_router
from deeptutor.services.practice.bank import Question

logger = logging.getLogger(__name__)


# Topic → (model role for the question metadata, model-router intent).
_TOPIC_ROUTING: dict[str, tuple[str, Intent]] = {
    "python": ("coding", Intent.CODING),
    "react": ("coding", Intent.CODING),
    "algorithms": ("coding", Intent.CODING),
    "dp": ("coding", Intent.CODING),
    "graphs": ("coding", Intent.CODING),
    "db": ("coding", Intent.CODING),
    "math": ("math", Intent.MATH),
    "probability": ("math", Intent.MATH),
    "ml": ("math", Intent.MATH),
    "dl": ("math", Intent.MATH),
    "system_design": ("general", Intent.ASSESSMENT),
    "api": ("general", Intent.ASSESSMENT),
    "general": ("general", Intent.ASSESSMENT),
}

# Feature-surface override (so the user can pin a specific model in .env):
#   HF_MODEL_PRACTICE_CODING / HF_MODEL_PRACTICE_MATH / HF_MODEL_PRACTICE_GENERAL
_FEATURE_FOR_ROLE: dict[str, str] = {
    "coding": "practice_coding",
    "math": "practice_math",
    "general": "practice_general",
}


_PROMPT_TEMPLATE = """You are an expert assessment designer building MCQ practice for a learner.

Generate exactly {limit} unique multiple-choice questions on the topic: **{topic}**
Difficulty: {difficulty}
Each question must test genuine conceptual understanding (not trivia), and each
distractor must be a plausible misconception a learner could realistically hold.

Return ONLY valid JSON in this exact shape, with no markdown fences and no commentary:

{{
  "questions": [
    {{
      "question": "<question text>",
      "options": {{"A": "<text>", "B": "<text>", "C": "<text>", "D": "<text>"}},
      "correct": "A",
      "explanation": "<1-2 concise sentences: why the correct option is right; avoid repeating the question>",
      "tags": ["<sub-concept-1>", "<sub-concept-2>"],
      "difficulty": "{difficulty}"
    }}
  ]
}}

Hard rules:
- Output MUST be parseable JSON. No prose outside the JSON.
- `correct` must be one of "A", "B", "C", "D".
- Exactly four distinct options per question.
- Questions must NOT reference each other.
- Do NOT include an "id" field; the server assigns one.
"""


_JSON_BLOCK_RE = re.compile(r"\{[\s\S]*\}")


def _strip_to_json(raw: str) -> str:
    """Best-effort extract of the first balanced JSON object in ``raw``."""
    raw = (raw or "").strip()
    if not raw:
        return "{}"
    # Strip common markdown fences if the model added them despite instructions.
    fence = re.search(r"```(?:json)?\s*([\s\S]+?)```", raw)
    if fence:
        raw = fence.group(1).strip()
    # Fall back to the first {...} block when there's leading prose.
    if not raw.startswith("{"):
        m = _JSON_BLOCK_RE.search(raw)
        if m:
            raw = m.group(0)
    return raw


def _validate_question(
    payload: Any,
    *,
    topic: str,
    model_role: str,
    fallback_difficulty: str,
) -> Question | None:
    """Coerce one model-emitted dict into a strict :class:`Question`.

    Returns ``None`` if any required field is missing or malformed; the caller
    decides whether to retry or surface an error.
    """
    if not isinstance(payload, dict):
        return None
    q_text = str(payload.get("question") or "").strip()
    options = payload.get("options")
    correct = str(payload.get("correct") or "").strip().upper()
    explanation = str(payload.get("explanation") or "").strip()
    tags_raw = payload.get("tags") or []
    difficulty = str(payload.get("difficulty") or fallback_difficulty).strip().lower()

    if difficulty not in {"easy", "medium", "hard"}:
        difficulty = fallback_difficulty
    if not isinstance(options, dict):
        return None
    opts = {str(k).strip().upper(): str(v).strip() for k, v in options.items() if v}
    if set(opts) != {"A", "B", "C", "D"}:
        return None
    if correct not in opts:
        return None
    if not q_text or not explanation:
        return None
    tags = tuple(str(t).strip() for t in tags_raw if str(t).strip())[:4]
    return Question(
        id=f"gen_{uuid.uuid4().hex[:12]}",
        topic=topic,
        difficulty=difficulty,  # type: ignore[arg-type]
        question=q_text,
        options=opts,
        correct=correct,
        explanation=explanation,
        tags=tags,
        model_role=model_role,
    )


def _resolve_practice_model(intent: Intent, role: str) -> str:
    """Model id for MCQ generation (stable defaults on Groq / OpenAI API)."""
    from deeptutor.services.llm.config import get_llm_config

    pin = (os.getenv("LLM_MODEL_PRACTICE") or "").strip()
    if pin:
        return pin

    router = get_model_router()
    feature = _FEATURE_FOR_ROLE.get(role, "practice_general")
    routed = router.route_feature(feature, intent=intent)
    llm_cfg = get_llm_config()

    if routed.api_key:
        return routed.model

    if router.model_for_feature(feature):
        return routed.model

    d = default_structured_output_model(llm_cfg.base_url, llm_cfg.effective_url)
    if d:
        return d

    return llm_cfg.model or routed.model


async def _ask_llm(
    prompt: str,
    *,
    intent: Intent,
    role: str,
    max_tokens: int,
    force_model: str | None = None,
) -> str:
    """Single LLM round-trip. Routes via ``feature → intent``."""
    # Late imports avoid circulars with the LLM package at module import time.
    from deeptutor.services.llm import complete as llm_complete
    from deeptutor.services.llm.config import get_llm_config

    router = get_model_router()
    feature = _FEATURE_FOR_ROLE.get(role, "practice_general")
    routed = router.route_feature(feature, intent=intent)

    llm_cfg = get_llm_config()
    api_key = routed.api_key or llm_cfg.api_key
    base_url = routed.api_base if routed.api_key else (llm_cfg.base_url or routed.api_base)
    if force_model:
        model = force_model
    else:
        model = _resolve_practice_model(intent, role)

    return await llm_complete(
        prompt=prompt,
        system_prompt=(
            "You are an expert assessment designer. You always respond with a"
            " single valid JSON object — no prose, no markdown fences."
        ),
        model=model,
        api_key=api_key,
        base_url=base_url,
        temperature=0.55,
        max_tokens=max_tokens,
    )


def _topic_for(topic: str | None) -> str:
    """Normalize the requested topic to a routing key (no question bank)."""
    if not topic or topic.lower() == "all":
        return "general"
    return topic.strip().lower()


async def generate_quiz(
    *,
    topic: str | None,
    difficulty: str | None,
    limit: int,
) -> list[Question]:
    """Generate a fresh quiz via the LLM. Raises ``RuntimeError`` on failure."""
    norm_topic = _topic_for(topic)
    role, intent = _TOPIC_ROUTING.get(norm_topic, ("general", Intent.ASSESSMENT))
    diff = (difficulty or "medium").lower()
    if diff not in {"easy", "medium", "hard"}:
        diff = "medium"
    n = max(1, min(int(limit or 5), 10))
    # Cap completion size so providers finish sooner (MCQ JSON is dense but bounded).
    max_tokens = min(4096, 900 + n * 420)

    prompt = _PROMPT_TEMPLATE.format(topic=norm_topic, difficulty=diff, limit=n)

    primary_model = _resolve_practice_model(intent, role)
    fallback_model = rate_limit_fallback_model(primary_model)
    model_chain: list[str | None] = [None] + ([fallback_model] if fallback_model else [])

    async def _llm_round() -> str:
        last_exc_msg: str | None = None
        for forced in model_chain:
            for gen_try in (1, 2):
                try:
                    return await _ask_llm(
                        prompt,
                        intent=intent,
                        role=role,
                        max_tokens=max_tokens,
                        force_model=forced,
                    )
                except Exception as exc:  # noqa: BLE001 — logged; surfaced after chain
                    last_exc_msg = f"LLM call failed: {exc}"
                    logger.warning(
                        "Practice LLM failure (model=%r gen_try=%s): %s",
                        forced or primary_model,
                        gen_try,
                        exc,
                    )
                    if gen_try < 2:
                        await asyncio.sleep(0.2)
            if (
                forced is None
                and fallback_model
                and looks_like_rate_or_quota_error(last_exc_msg or "")
            ):
                logger.info(
                    "Practice: using fallback model %r after limit on %r",
                    fallback_model,
                    primary_model,
                )
                continue
            break
        raise RuntimeError(last_exc_msg or "LLM call failed.")

    last_err: str | None = None
    for attempt in (1, 2):
        try:
            raw = await _llm_round()
        except RuntimeError as exc:
            last_err = str(exc)
            logger.warning("Practice generation LLM phase attempt %d: %s", attempt, exc)
            if attempt == 2:
                raise RuntimeError(last_err) from exc
            await asyncio.sleep(0.25)
            continue

        try:
            parsed = json.loads(_strip_to_json(raw))
        except json.JSONDecodeError as exc:
            last_err = f"Model returned invalid JSON: {exc}"
            logger.warning("Practice generation parse failure (attempt %d): %s", attempt, exc)
            continue

        items = parsed.get("questions")
        if not isinstance(items, list) or not items:
            last_err = "Model JSON missing a non-empty `questions` array."
            continue

        questions: list[Question] = []
        for raw_q in items[:n]:
            q = _validate_question(
                raw_q,
                topic=norm_topic,
                model_role=role,
                fallback_difficulty=diff,
            )
            if q is not None:
                questions.append(q)
        if len(questions) >= max(1, n - 1):  # tolerate at most one rejected item
            return questions
        last_err = (
            f"Only {len(questions)}/{n} questions passed validation — model"
            " output was malformed."
        )
        logger.warning("Practice generation rejected items (attempt %d): %s", attempt, last_err)

    raise RuntimeError(last_err or "Quiz generation failed for unknown reason.")


__all__ = ["generate_quiz"]
