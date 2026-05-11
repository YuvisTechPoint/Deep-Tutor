"""Achievements + XP / leaderboard API.

Exposes:

* ``GET  /api/v1/achievements``               — badge catalog + status
* ``GET  /api/v1/achievements/level``          — level info
* ``GET  /api/v1/achievements/xp-history``     — recent XP awards
* ``GET  /api/v1/achievements/leaderboard``    — single-user cohort placeholder
                                                 (clearly tagged ``preview``)
* ``POST /api/v1/achievements/{badge}/claim``  — manual claim (perfect quiz etc.)
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException

from deeptutor.services.gamification import (
    DEFAULT_BADGES,
    compute_level,
    get_gamification_store,
)
from deeptutor.services.session import get_session_store

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("")
async def list_achievements() -> dict:
    store = get_gamification_store()
    state = store.get_state()
    return {
        "total_xp": state["total_xp"],
        "level": state["level"],
        "achievements": store.get_badges_status(),
        "catalog_size": len(DEFAULT_BADGES),
    }


@router.get("/level")
async def get_level() -> dict:
    store = get_gamification_store()
    return compute_level(store.get_state()["total_xp"]).to_dict()


@router.get("/xp-history")
async def xp_history(limit: int = 20) -> dict:
    store = get_gamification_store()
    return {"items": store.get_recent_xp_events(limit=limit)}


@router.get("/leaderboard")
async def leaderboard() -> dict:
    """Cohort leaderboard.

    DeepTutor is a single-user runtime today, so we surface the learner's own
    progress as rank #1 and clearly mark the response as a preview. When a
    multi-user backend lands, this endpoint becomes a thin query over the cohort
    table.
    """
    store = get_gamification_store()
    state = store.get_state()
    level = state["level"]["level"]
    return {
        "preview": True,
        "label": "preview-cohort",
        "rows": [
            {
                "rank": 1,
                "name": "You",
                "level": level,
                "xp": state["total_xp"],
                "you": True,
            }
        ],
    }


@router.post("/{badge_id}/claim")
async def claim_badge(badge_id: str) -> dict:
    store = get_gamification_store()
    try:
        unlocked = store.unlock_badge_manual(badge_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return {"badge_id": badge_id, "unlocked_now": unlocked}


# Lightweight helper kept here because the session store is the right place to
# query cumulative activity counts and we want the route to stay self-contained.
async def session_count() -> int:
    store = get_session_store()
    sessions = await store.list_sessions(limit=200, offset=0)
    return len(sessions)


__all__ = ["router"]
