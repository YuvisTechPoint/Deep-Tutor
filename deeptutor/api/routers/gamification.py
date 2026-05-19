"""Gamification API — XP ledger, level, streaks, badges, mission completions.

All endpoints are scoped under ``/api/v1/gamification`` and back every learner
surface (Dashboard, Missions, Achievements, Analytics, Notifications) with real
durable state from :mod:`deeptutor.services.gamification`.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from deeptutor.services.gamification import (
    DEFAULT_BADGES,
    XPEvent,
    compute_level,
    get_gamification_store,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# ─── Schemas ─────────────────────────────────────────────────────────────────


class LevelPayload(BaseModel):
    level: int
    xp_into_level: int
    xp_for_next_level: int
    total_xp: int
    progress_pct: int


class GamificationStatePayload(BaseModel):
    total_xp: int
    streak_current: int
    streak_max: int
    event_count: int
    xp_per_day: dict[str, int]
    xp_per_source: dict[str, int]
    active_days: list[str]
    badges_unlocked: dict[str, str]
    mission_completions: dict[str, str]
    level: LevelPayload
    last_synced_at: str
    reward_xp_spent_total: int = 0
    reward_xp_balance: int = 0
    reward_claims: list[dict[str, Any]] = Field(default_factory=list)


class AwardRequest(BaseModel):
    action: str = Field(min_length=1, max_length=100)
    xp: int = Field(gt=0, le=10_000)
    source: str = Field(min_length=1, max_length=200)
    metadata: dict[str, Any] = Field(default_factory=dict)


class AwardResponse(BaseModel):
    event: dict[str, Any]
    state: GamificationStatePayload


class XPHistoryItem(BaseModel):
    event_id: str
    action: str
    xp: int
    source: str
    timestamp: str
    metadata: dict[str, Any] = Field(default_factory=dict)


class XPHistoryResponse(BaseModel):
    items: list[XPHistoryItem]


# ─── Endpoints ───────────────────────────────────────────────────────────────


@router.get("/state", response_model=GamificationStatePayload)
async def get_state() -> GamificationStatePayload:
    store = get_gamification_store()
    return GamificationStatePayload(**store.get_state())


@router.get("/xp-history", response_model=XPHistoryResponse)
async def get_xp_history(limit: int = 20) -> XPHistoryResponse:
    store = get_gamification_store()
    items = store.get_recent_xp_events(limit=limit)
    return XPHistoryResponse(items=[XPHistoryItem(**item) for item in items])


@router.post("/award", response_model=AwardResponse)
async def award_xp(body: AwardRequest) -> AwardResponse:
    store = get_gamification_store()
    try:
        event = store.award(
            action=body.action,
            xp=body.xp,
            source=body.source,
            metadata=body.metadata,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return AwardResponse(
        event=event.to_dict(),
        state=GamificationStatePayload(**store.get_state()),
    )


@router.get("/level", response_model=LevelPayload)
async def get_level() -> LevelPayload:
    store = get_gamification_store()
    return LevelPayload(**compute_level(store.get_state()["total_xp"]).to_dict())


@router.get("/badges")
async def get_badges() -> dict[str, Any]:
    """Return badge catalog with per-badge status (unlocked / in-progress / locked)."""
    store = get_gamification_store()
    return {"badges": store.get_badges_status(), "catalog_size": len(DEFAULT_BADGES)}


# Helper used by other routers (no HTTP exposure):


def export_event_record(event: XPEvent) -> dict[str, Any]:
    return event.to_dict()


__all__ = ["router", "export_event_record"]
