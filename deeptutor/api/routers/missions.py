"""Daily missions API.

Today's missions are derived from:
* the active milestone in the learning plan (one mission per active milestone)
* a deterministic mix of mode-balanced missions (practice / voice / read /
  bonus mock-interview)

Mission state is short-lived (per-day) and persisted in the gamification store.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from deeptutor.api.routers.learning_profile import _load_raw as _load_profile
from deeptutor.services.gamification import get_gamification_store
from deeptutor.services.learning_plan import build_plan

logger = logging.getLogger(__name__)

router = APIRouter()


class MissionCompleteRequest(BaseModel):
    mission_id: str = Field(min_length=1, max_length=100)
    xp_reward: int | None = Field(default=None, ge=0, le=2000)


def _today_local() -> str:
    return datetime.now(timezone.utc).date().isoformat()


def _build_today(profile: dict[str, Any]) -> list[dict[str, Any]]:
    plan = build_plan(profile)
    active_milestone: dict[str, Any] | None = None
    for phase in plan["phases"]:
        for m in phase["milestones"]:
            if m["status"] == "active":
                active_milestone = m
                break
        if active_milestone:
            break

    missions: list[dict[str, Any]] = []

    if active_milestone:
        missions.append(
            {
                "id": f"plan::{active_milestone['id']}",
                "title": f"Continue: {active_milestone['title']}",
                "description": active_milestone["description"],
                "category": "Roadmap",
                "xp": min(active_milestone.get("xp", 150) // 4, 200),
                "duration": "25–35 min",
                "icon": "play",
                "color": "violet",
                "cta_href": "/roadmap",
                "model_roles": active_milestone.get("model_roles", ["general"]),
            }
        )

    missions.extend(
        [
            {
                "id": "practice::adaptive_quiz",
                "title": "Adaptive 5-question quiz",
                "description": (
                    "Mixed-difficulty quiz across your active topics. Answers feed"
                    " the mastery tracker."
                ),
                "category": "Practice",
                "xp": 75,
                "duration": "8–10 min",
                "icon": "target",
                "color": "amber",
                "cta_href": "/practice",
                "model_roles": ["general", "math", "coding"],
            },
            {
                "id": "ai_tutor::deep_solve",
                "title": "Deep-solve session",
                "description": (
                    "Pick one of yesterday's wrong answers and run it through the"
                    " deep_solve capability for a step-by-step walkthrough."
                ),
                "category": "Tutor",
                "xp": 100,
                "duration": "15–20 min",
                "icon": "brain",
                "color": "blue",
                "cta_href": "/chat",
                "model_roles": ["general"],
            },
            {
                "id": "co_writer::explain_back",
                "title": "Teach-back via Co-Writer",
                "description": (
                    "Write a 200-word explanation of today's topic. The tutor will"
                    " grade clarity and flag misconceptions."
                ),
                "category": "Co-Writer",
                "xp": 75,
                "duration": "12 min",
                "icon": "pen",
                "color": "emerald",
                "cta_href": "/co-writer",
                "model_roles": ["general"],
            },
        ]
    )

    weekday = datetime.now(timezone.utc).weekday()
    if weekday in (0, 3):
        missions.append(
            {
                "id": "voice::elevator_pitch",
                "title": "Voice practice — explain a concept",
                "description": (
                    "Use voice mode to explain today's topic in your own words; the"
                    " tutor scores clarity once Whisper is wired."
                ),
                "category": "Voice",
                "xp": 60,
                "duration": "10 min",
                "icon": "mic",
                "color": "teal",
                "cta_href": "/chat",
                "model_roles": ["speech"],
                "requires_feature": "speech",
            }
        )

    return missions


@router.get("/today")
async def missions_today() -> dict:
    store = get_gamification_store()
    profile = _load_profile()
    today_iso = _today_local()
    completions = store.get_mission_completions()
    missions = _build_today(profile)
    payload: list[dict[str, Any]] = []
    completed = 0
    total_xp = 0
    for m in missions:
        completed_today = f"{today_iso}::{m['id']}" in completions
        if completed_today:
            completed += 1
            total_xp += m.get("xp", 0)
        payload.append({**m, "status": "completed" if completed_today else "available"})
    bonus = {
        "id": "bonus::mock_interview",
        "title": "Bonus: 30-min mock interview",
        "description": "Timed DSA + System Design mock interview, scored by the AI tutor.",
        "xp": 300,
        "duration": "30 min",
        "cta_href": "/practice",
        "model_roles": ["coding", "general"],
    }
    return {
        "date": today_iso,
        "missions": payload,
        "bonus": bonus,
        "totals": {
            "completed": completed,
            "total": len(payload),
            "xp_earned": total_xp,
            "xp_target": sum(m.get("xp", 0) for m in payload) + bonus["xp"],
        },
    }


@router.post("/{mission_id}/complete")
async def complete_mission(mission_id: str, body: MissionCompleteRequest) -> dict:
    if body.mission_id != mission_id:
        raise HTTPException(status_code=400, detail="mission_id mismatch")
    store = get_gamification_store()
    if store.mission_completed_today(mission_id):
        return {"mission_id": mission_id, "already_completed": True}
    store.mark_mission_complete(mission_id)
    xp = body.xp_reward or 50
    event = store.award(
        action="mission.complete",
        xp=xp,
        source=f"mission:{mission_id}",
        metadata={"mission_id": mission_id},
    )
    return {
        "mission_id": mission_id,
        "already_completed": False,
        "event": event.to_dict(),
    }


__all__ = ["router"]
