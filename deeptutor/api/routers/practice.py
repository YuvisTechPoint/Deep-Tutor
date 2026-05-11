"""Practice center API — realtime, LLM-generated quizzes only.

Endpoints:

* ``GET  /api/v1/practice/topics``        — curriculum topic labels.
* ``GET  /api/v1/practice/questions``     — generate a **fresh** quiz via the
                                            LLM. Returns ``quiz_id`` + items
                                            (with the answer keys stripped).
                                            The full questions live in an
                                            **ephemeral, process-local cache**
                                            for scoring — they are never
                                            written to disk.
* ``POST /api/v1/practice/submit``        — score against the cached quiz,
                                            award XP, emit ledger events, then
                                            drop the cache entry.

There is **no static question bank**. Restarting the backend wipes every
in-flight quiz.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from deeptutor.services.gamification import get_gamification_store
from deeptutor.services.practice import (
    drop_quiz,
    generate_quiz,
    get_quiz,
    list_topics,
    score_quiz_against,
    store_quiz,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ─── Schemas ─────────────────────────────────────────────────────────────────


class SubmittedAnswer(BaseModel):
    question_id: str
    answer: str


class SubmitRequest(BaseModel):
    quiz_id: str = Field(min_length=1, max_length=64)
    answers: list[SubmittedAnswer] = Field(min_length=1)
    duration_seconds: int | None = Field(default=None, ge=0, le=86_400)


class SubmitResponse(BaseModel):
    score: dict
    awarded_xp: int
    events: list[dict]


class CheckRequest(BaseModel):
    quiz_id: str = Field(min_length=1, max_length=64)
    question_id: str = Field(min_length=1, max_length=64)
    answer: str = Field(min_length=1, max_length=8)


class CheckResponse(BaseModel):
    question_id: str
    correct: str
    is_correct: bool
    explanation: str


# ─── Milestone → topic resolution ────────────────────────────────────────────
#
# When the practice page is launched from the roadmap with ``?milestone=<id>``
# we resolve the roadmap milestone id to a practice topic slug using the same
# mapping the workflow service uses. Keeping the lookup local avoids importing
# the workflow package at request time and keeps coupling shallow.

_MILESTONE_TO_TOPIC: dict[str, str] = {
    "py_fundamentals": "python",
    "data_structures": "algorithms",
    "sorting_searching": "algorithms",
    "dynamic_programming": "dp",
    "graphs": "graphs",
    "ml_fundamentals": "ml",
    "deep_learning": "ml",
    "system_design": "system_design",
    "portfolio": "system_design",
    "probability": "math",
    "pandas": "python",
    "regression_classification": "ml",
    "primary_lang": "python",
    "rest_apis": "db",
    "databases": "db",
}


# ─── Endpoints ───────────────────────────────────────────────────────────────


@router.get("/topics")
async def topics() -> dict:
    return {"topics": list_topics()}


@router.get("/questions")
async def questions(
    topic: str | None = None,
    difficulty: str | None = None,
    limit: int = Query(default=5, ge=1, le=10),
    milestone: str | None = None,
) -> dict:
    """Generate a fresh quiz live via the LLM.

    The response includes:

    * ``quiz_id`` — opaque token the client must echo back on submit. The
      server uses it to look up the *full* questions (with answer keys) from
      its ephemeral cache.
    * ``items``   — public view of each question (no ``correct`` / no
      ``explanation``) so the answer key never leaves the server until the
      learner has answered.
    """
    # If launched from the roadmap, prefer the mapped practice topic. Falls
    # back to whatever ``topic`` the client passed in.
    if milestone and not topic:
        topic = _MILESTONE_TO_TOPIC.get(milestone.strip().lower())

    try:
        qs = await generate_quiz(
            topic=topic,
            difficulty=difficulty,
            limit=limit,
        )
    except Exception as exc:  # noqa: BLE001 — surface a clean error to the UI
        logger.exception("Practice quiz generation failed")
        raise HTTPException(
            status_code=503,
            detail=(
                "Practice generator is unavailable. Check the LLM provider "
                "(HF_TOKEN / LOCAL_LLM_BASE_URL) and try again. "
                f"Details: {exc}"
            ),
        ) from exc

    if not qs:
        raise HTTPException(
            status_code=503,
            detail="The model returned no questions. Please retry.",
        )

    quiz_id = store_quiz(
        qs,
        topic=qs[0].topic if qs else (topic or "general"),
        difficulty=(difficulty or "medium"),
    )
    return {
        "quiz_id": quiz_id,
        "items": [q.to_public_dict() for q in qs],
        "filters": {
            "topic": topic,
            "difficulty": difficulty,
            "limit": limit,
            "milestone": milestone,
        },
        "generated": True,
    }


@router.post("/check", response_model=CheckResponse)
async def check_answer(body: CheckRequest) -> CheckResponse:
    """Reveal whether a single answer is correct (and explain why).

    Called after the learner commits an answer for a question so the UI can
    show per-question feedback without ever shipping the answer key in the
    initial ``GET /questions`` response. Reads from the same ephemeral cache
    used by ``/submit``; does **not** record XP or drop the cache entry.
    """
    questions = get_quiz(body.quiz_id)
    if questions is None:
        raise HTTPException(
            status_code=410,
            detail="Quiz expired or unknown. Refresh to generate a fresh quiz.",
        )
    q = next((x for x in questions if x.id == body.question_id), None)
    if q is None:
        raise HTTPException(
            status_code=404,
            detail="Unknown question_id for this quiz.",
        )
    chosen = body.answer.strip().upper()
    return CheckResponse(
        question_id=q.id,
        correct=q.correct,
        is_correct=q.correct == chosen,
        explanation=q.explanation,
    )


@router.post("/submit", response_model=SubmitResponse)
async def submit_quiz(body: SubmitRequest) -> SubmitResponse:
    """Score a submitted quiz against the cached questions and award XP.

    The cache entry is **dropped** on success so the same quiz cannot be
    submitted twice.
    """
    if not body.answers:
        raise HTTPException(status_code=400, detail="answers required")

    questions = get_quiz(body.quiz_id)
    if questions is None:
        raise HTTPException(
            status_code=410,
            detail=(
                "Quiz expired or unknown. Refresh the page to generate a "
                "fresh quiz — the practice center keeps no persistent bank."
            ),
        )

    answer_dicts = [a.model_dump() for a in body.answers]
    score = score_quiz_against(questions, answer_dicts)

    store = get_gamification_store()
    events: list[dict] = []
    awarded = 0
    by_id = {q.id: q for q in questions}
    for answer in body.answers:
        question_obj = by_id.get(answer.question_id)
        if question_obj is None:
            continue
        is_correct = question_obj.correct == answer.answer
        action = "practice.correct_answer" if is_correct else "practice.incorrect_answer"
        xp = 100 if is_correct else 10  # consolation XP for engagement
        event = store.award(
            action=action,
            xp=xp,
            source=f"practice:{question_obj.topic}",
            metadata={
                "question_id": question_obj.id,
                "topic": question_obj.topic,
                "difficulty": question_obj.difficulty,
                "model_role": question_obj.model_role,
                "generated": True,
            },
        )
        events.append(event.to_dict())
        awarded += xp

    if score["total"] > 0 and score["correct"] == score["total"]:
        bonus = store.award(
            action="practice.perfect_quiz",
            xp=150,
            source="practice:bonus",
            metadata={
                "reason": "perfect_quiz",
                "topic_count": len(score["per_topic"]),
            },
        )
        events.append(bonus.to_dict())
        awarded += 150
        store.unlock_badge_manual("sharp_mind")

    store.add_notification(
        {
            "type": "quiz_available",
            "title": f"Practice quiz scored {score['percentage']}%",
            "message": (
                f"You answered {score['correct']} / {score['total']} correctly."
                f" {awarded} XP awarded."
            ),
            "action_label": "View analytics",
            "action_href": "/analytics",
        }
    )

    drop_quiz(body.quiz_id)
    return SubmitResponse(score=score, awarded_xp=awarded, events=events)


__all__ = ["router"]
