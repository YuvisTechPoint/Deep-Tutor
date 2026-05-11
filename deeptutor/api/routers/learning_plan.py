"""Learning plan / roadmap API.

The roadmap UI fetches ``GET /api/v1/learning-plan`` to render phases and
milestones derived from the learner's profile. Milestone state is mutable via
``PATCH /api/v1/learning-plan/milestones/{id}`` and auto-flips to
``completed`` when the gamification ledger sees the corresponding trigger
event.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from deeptutor.api.routers.learning_profile import _load_raw as _load_profile
from deeptutor.services.learning_plan import (
    build_plan,
    list_plan_templates,
    update_milestone_status,
)

logger = logging.getLogger(__name__)

router = APIRouter()


class MilestoneStatusUpdate(BaseModel):
    status: str = Field(min_length=1, max_length=32)


@router.get("")
async def get_learning_plan() -> dict:
    profile = _load_profile()
    plan = build_plan(profile)
    plan["profile_summary"] = {
        "target_path": profile.get("target_path", ""),
        "goals": profile.get("goals", []) or [],
        "weekly_hours": profile.get("weekly_hours"),
        "experience_level": profile.get("experience_level", ""),
    }
    return plan


@router.get("/templates")
async def get_templates() -> dict:
    return {"templates": list_plan_templates()}


@router.patch("/milestones/{milestone_id}")
async def patch_milestone(milestone_id: str, body: MilestoneStatusUpdate) -> dict:
    try:
        updated = update_milestone_status(milestone_id, body.status)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"milestone_id": milestone_id, "status_record": updated}


__all__ = ["router"]
