"""Short baseline diagnostic quiz (reuses practice generator)."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from deeptutor.analytics.emit import emit_domain_event
from deeptutor.api.routers.practice import SubmitRequest, SubmitResponse
from deeptutor.services.gamification import get_gamification_store
from deeptutor.services.path_service import get_path_service
from deeptutor.services.practice import (
    drop_quiz,
    generate_quiz,
    get_quiz,
    score_quiz_against,
    store_quiz,
)

logger = logging.getLogger(__name__)

router = APIRouter()

_NUM = 3


def _profile_path():
    path_svc = get_path_service()
    profile_dir = path_svc.user_data_dir / "learning"
    profile_dir.mkdir(parents=True, exist_ok=True)
    return profile_dir / "profile.json"


def _merge_profile(**updates: object) -> dict:
    path = _profile_path()
    raw: dict = {}
    if path.exists():
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            raw = {}
    raw.update({k: v for k, v in updates.items() if v is not None})
    raw["updated_at"] = datetime.now(timezone.utc).isoformat()
    path.write_text(json.dumps(raw, ensure_ascii=False, indent=2), encoding="utf-8")
    return raw


@router.post("/start")
async def diagnostic_start() -> dict:
    try:
        qs = await generate_quiz(topic="general", difficulty="medium", limit=_NUM)
    except Exception as exc:
        logger.exception("diagnostic generate failed")
        raise HTTPException(
            status_code=503,
            detail=f"Diagnostic generator unavailable: {exc}",
        ) from exc
    if not qs:
        raise HTTPException(status_code=503, detail="No questions returned")
    quiz_id = store_quiz(qs, topic="diagnostic", difficulty="medium")
    return {
        "quiz_id": quiz_id,
        "items": [q.to_public_dict() for q in qs],
        "num_questions": _NUM,
    }


@router.post("/finish", response_model=SubmitResponse)
async def diagnostic_finish(body: SubmitRequest) -> SubmitResponse:
    questions = get_quiz(body.quiz_id)
    if questions is None:
        raise HTTPException(
            status_code=410,
            detail="Diagnostic quiz expired. Start again.",
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
        xp = 50 if is_correct else 5
        event = store.award(
            action=action,
            xp=xp,
            source=f"diagnostic:{question_obj.topic}",
            metadata={
                "question_id": question_obj.id,
                "topic": question_obj.topic,
                "diagnostic": True,
            },
        )
        events.append(event.to_dict())
        awarded += xp

    drop_quiz(body.quiz_id)

    merged = _merge_profile(
        diagnostic_completed=True,
        diagnostic_summary={
            "score": score,
            "completed_at": datetime.now(timezone.utc).isoformat(),
        },
    )
    emit_domain_event(
        "DiagnosticCompleted",
        subject_type="LearningProfile",
        subject_id="primary",
        payload={"score": score, "awarded_xp": awarded},
    )
    try:
        from deeptutor.services.revision import seed_from_practice_score

        seed_from_practice_score(score)
    except Exception:
        logger.debug("diagnostic revision seed skipped", exc_info=True)

    _ = merged  # persisted via _merge_profile
    return SubmitResponse(score=score, awarded_xp=awarded, events=events)


__all__ = ["router"]
