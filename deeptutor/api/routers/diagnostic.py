"""Short baseline diagnostic quiz (reuses practice generator)."""

from __future__ import annotations

from datetime import datetime, timezone
import json
import logging

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

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


class DiagnosticStartRequest(BaseModel):
    topic: str | None = None
    difficulty: str = "medium"


def _load_profile_raw() -> dict:
    path = _profile_path()
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _preparing_slugs(profile: dict) -> set[str]:
    slugs: set[str] = set()
    for label in profile.get("preparing_for") or []:
        low = str(label).lower().strip()
        if low in ("school",) or "school" in low:
            slugs.add("school")
        if low in ("engineering",) or "engineer" in low:
            slugs.add("engineering")
        if low in ("medical",) or "medical" in low or "medicine" in low:
            slugs.add("medical")
    return slugs


def _diagnostic_topic_from_profile() -> tuple[str, str]:
    raw = _load_profile_raw()
    path_id = str(raw.get("career_path_id") or "").strip()
    slugs = _preparing_slugs(raw)
    if path_id == "medical-entrance":
        return "biology", "medium"
    if path_id == "engineering-entrance":
        return "physics", "medium"
    if path_id == "school-academics":
        return "general", "medium"
    if path_id == "ml-engineer":
        return "ml", "medium"
    if path_id == "data-scientist":
        return "statistics", "medium"
    if path_id == "sde-backend":
        return "algorithms", "medium"
    if "medical" in slugs:
        return "biology", "medium"
    if "engineering" in slugs:
        return "physics", "medium"
    return "general", "medium"


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
async def diagnostic_start(body: DiagnosticStartRequest | None = None) -> dict:
    req = body or DiagnosticStartRequest()
    topic = (req.topic or "").strip()
    difficulty = (req.difficulty or "medium").strip() or "medium"
    if not topic:
        topic, difficulty = _diagnostic_topic_from_profile()
    try:
        qs = await generate_quiz(topic=topic, difficulty=difficulty, limit=_NUM)
    except Exception as exc:
        logger.exception("diagnostic generate failed")
        raise HTTPException(
            status_code=503,
            detail=f"Diagnostic generator unavailable: {exc}",
        ) from exc
    if not qs:
        raise HTTPException(status_code=503, detail="No questions returned")
    quiz_id = store_quiz(qs, topic=f"diagnostic:{topic}", difficulty=difficulty)
    return {
        "quiz_id": quiz_id,
        "items": [q.to_public_dict() for q in qs],
        "num_questions": _NUM,
        "topic": topic,
        "difficulty": difficulty,
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
        from deeptutor.api.routers.career_refresh import schedule_career_refresh

        schedule_career_refresh(
            "diagnostic_completed",
            accuracy_pct=score.get("percentage"),
        )
    except Exception:
        pass
    try:
        from deeptutor.services.revision import seed_from_practice_score

        seed_from_practice_score(score)
    except Exception:
        logger.debug("diagnostic revision seed skipped", exc_info=True)

    _ = merged  # persisted via _merge_profile
    return SubmitResponse(score=score, awarded_xp=awarded, events=events)


__all__ = ["router"]
