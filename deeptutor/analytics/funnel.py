"""Pilot funnel counts from durable domain_events (SQLite)."""

from __future__ import annotations

from collections import Counter
from typing import Any

from deeptutor.analytics.event_store import get_domain_event_store


def compute_funnel(limit: int = 10_000) -> dict[str, Any]:
    rows = get_domain_event_store().list_recent(limit=limit)
    # list_recent is DESC — reverse for chronological optional; counts are order-independent
    names = Counter(r.name for r in rows)
    onboarded = int(names.get("LearnerOnboarded", 0))
    profile_updates = int(names.get("LearningProfileUpdated", 0))
    diagnostic_done = int(names.get("DiagnosticCompleted", 0))
    practice = int(names.get("PracticeSessionCompleted", 0))
    tutor_turns = int(names.get("TutorTurnCompleted", 0))
    missions = int(names.get("MissionCompleted", 0))
    milestones = int(names.get("MilestoneStatusUpdated", 0))

    # Heuristic: first practice after profile (pilot single-actor — total counts)
    return {
        "window_events": len(rows),
        "counts": {
            "LearnerOnboarded": onboarded,
            "LearningProfileUpdated": profile_updates,
            "DiagnosticCompleted": diagnostic_done,
            "PracticeSessionCompleted": practice,
            "TutorTurnCompleted": tutor_turns,
            "MissionCompleted": missions,
            "MilestoneStatusUpdated": milestones,
        },
        "funnel_hint": {
            "onboarded_to_practice": {
                "onboarded": onboarded,
                "practice_sessions": practice,
            },
            "onboarded_to_tutor": {
                "onboarded": onboarded,
                "tutor_turns": tutor_turns,
            },
        },
    }


__all__ = ["compute_funnel"]
