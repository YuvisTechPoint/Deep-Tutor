"""Learner-facing analytics API.

Aggregates real data from:
* the unified session store (sessions, recent topics)
* the gamification ledger (XP per day, streaks, sources)
* the topic mastery rollup derived from practice events

If neither store has any data yet, the endpoints return empty-but-typed
payloads (no random numbers) so the UI shows real empty states.
"""

from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone
import logging
from typing import Any

from fastapi import APIRouter

from deeptutor.services.gamification import compute_level, get_gamification_store
from deeptutor.services.session import get_session_store

logger = logging.getLogger(__name__)

router = APIRouter()


# ─── Helpers ─────────────────────────────────────────────────────────────────


def _date_window(days: int) -> tuple[datetime, datetime]:
    end = datetime.now(timezone.utc)
    start = end - timedelta(days=days)
    return start, end


def _topic_mastery() -> list[dict[str, Any]]:
    store = get_gamification_store()
    events = store.get_recent_xp_events(limit=500)
    mastery: dict[str, dict[str, int]] = defaultdict(lambda: {"correct": 0, "incorrect": 0})
    for evt in events:
        meta = evt.get("metadata") or {}
        topic = (meta.get("topic") or "").strip().lower()
        if not topic:
            continue
        if evt.get("action") == "practice.correct_answer":
            mastery[topic]["correct"] += 1
        elif evt.get("action") == "practice.incorrect_answer":
            mastery[topic]["incorrect"] += 1
    rows: list[dict[str, Any]] = []
    for topic, counts in mastery.items():
        total = counts["correct"] + counts["incorrect"]
        if total == 0:
            continue
        mastery_pct = int(round((counts["correct"] / total) * 100))
        rows.append({"topic": topic, "mastery": mastery_pct, "answers": total})
    rows.sort(key=lambda r: -r["mastery"])
    return rows


# ─── Endpoints ───────────────────────────────────────────────────────────────


@router.get("/summary")
async def get_summary(window: str = "30d") -> dict:
    days = {"7d": 7, "30d": 30, "90d": 90}.get(window, 30)
    start, _end = _date_window(days)
    store = get_gamification_store()
    sessions_store = get_session_store()
    state = store.get_state()

    sessions = await sessions_store.list_sessions(limit=200, offset=0)
    sessions_in_window = 0
    for s in sessions:
        ts = s.get("updated_at") or s.get("created_at")
        if not ts:
            continue
        try:
            dt = datetime.fromtimestamp(float(ts) / 1000.0, tz=timezone.utc) if isinstance(ts, (int, float)) else datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
        except Exception:
            continue
        if dt >= start:
            sessions_in_window += 1

    xp_per_day = state.get("xp_per_day") or {}
    correct_events = sum(
        1
        for e in store.get_recent_xp_events(limit=500)
        if e.get("action") == "practice.correct_answer"
    )
    incorrect_events = sum(
        1
        for e in store.get_recent_xp_events(limit=500)
        if e.get("action") == "practice.incorrect_answer"
    )
    total_answers = correct_events + incorrect_events
    accuracy = int(round((correct_events / total_answers) * 100)) if total_answers else 0

    minutes_total = state.get("total_xp", 0) / 12  # ~12 XP per minute heuristic

    return {
        "range": window,
        "sessions": sessions_in_window,
        "accuracy": accuracy,
        "problems": total_answers,
        "hours": round(minutes_total / 60, 1),
        "streak_current": state.get("streak_current", 0),
        "streak_max": state.get("streak_max", 0),
        "total_xp": state.get("total_xp", 0),
        "level": state.get("level", compute_level(0).to_dict()),
        "xp_per_day": xp_per_day,
        "preview": total_answers == 0,
    }


@router.get("/topic-mastery")
async def topic_mastery() -> dict:
    return {"items": _topic_mastery()}


@router.get("/xp-trend")
async def xp_trend(window: str = "30d") -> dict:
    days = {"7d": 7, "30d": 30, "90d": 90}.get(window, 30)
    store = get_gamification_store()
    state = store.get_state()
    xp_per_day = state.get("xp_per_day") or {}
    today = datetime.now(timezone.utc).date()
    series: list[dict[str, Any]] = []
    for offset in range(days):
        d = today - timedelta(days=days - 1 - offset)
        series.append({"date": d.isoformat(), "xp": int(xp_per_day.get(d.isoformat(), 0))})
    return {"range": window, "series": series}


@router.get("/time-distribution")
async def time_distribution() -> dict:
    store = get_gamification_store()
    state = store.get_state()
    sources = state.get("xp_per_source") or {}
    total = sum(sources.values()) or 1
    rows: list[dict[str, Any]] = []
    label_map = {
        "practice": "Practice",
        "mission": "Missions",
        "tutor": "Tutor",
        "book": "Book",
        "co_writer": "Co-Writer",
        "voice": "Voice",
    }
    for source, xp in sources.items():
        prefix = source.split(":")[0]
        label = label_map.get(prefix, prefix.title() or "Other")
        rows.append({"label": label, "pct": int(round((xp / total) * 100)), "xp": int(xp)})
    rows.sort(key=lambda r: -r["pct"])
    return {"items": rows}


@router.get("/weak-areas")
async def weak_areas() -> dict:
    mastery_rows = _topic_mastery()
    weak = [r for r in mastery_rows if r["mastery"] < 70][:6]
    # Annotate with model role suggestions for the relevant practice surface.
    role_for = {
        "math": "math",
        "algorithms": "math",
        "dsa": "math",
        "system_design": "general",
        "python": "coding",
        "ml": "general",
    }
    for r in weak:
        topic = r["topic"]
        r["action"] = (
            f"Run a focused practice block on {topic} —"
            " the tutor routes to the appropriate open-source model."
        )
        r["recommended_model_role"] = role_for.get(topic, "general")
    return {"items": weak, "preview": not mastery_rows}


__all__ = ["router"]
