"""Cross-feature workflow orchestrator.

Two product-shaped questions answered here:

* :func:`get_learner_journey` — full journey snapshot for dashboards.
* :func:`get_next_action`     — single best next step with a deep-link CTA.

The orchestrator never persists state of its own; it composes the existing
learning-plan, gamification ledger, mission feed, and derived signals.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from deeptutor.services.gamification import get_gamification_store
from deeptutor.services.learning_plan import build_plan
from deeptutor.services.workflow.mastery import compute_topic_mastery
from deeptutor.services.workflow.signals import derived_action_signals

# Topic → practice topic-slug. The roadmap milestone IDs and the
# practice bank topic slugs do not always match 1:1 (e.g. milestone
# ``data_structures`` ↔ topic ``algorithms``). Mapping here keeps the
# hand-off URLs honest without forcing the planner or bank to agree
# on identifiers.
_MILESTONE_TO_PRACTICE_TOPIC: dict[str, str] = {
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


def _milestone_practice_topic(milestone: dict[str, Any]) -> str | None:
    """Pick the best practice topic for a milestone, falling back to skills."""
    explicit = _MILESTONE_TO_PRACTICE_TOPIC.get(milestone.get("id") or "")
    if explicit:
        return explicit
    # Heuristic fallback — look at the milestone skills and try a slug match.
    for skill in milestone.get("skills", []):
        slug = str(skill).strip().lower().replace(" ", "_")
        if slug in {"python", "dp", "graphs", "ml", "math", "db", "react"}:
            return slug
    return None


@dataclass
class NextAction:
    """A single concrete CTA the learner should perform next."""

    kind: str  # "practice" | "tutor" | "assessment" | "mission" | "co_writer"
    title: str
    description: str
    href: str
    milestone_id: str | None = None
    milestone_title: str | None = None
    topic: str | None = None
    estimated_minutes: int | None = None
    rationale: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "kind": self.kind,
            "title": self.title,
            "description": self.description,
            "href": self.href,
            "milestone_id": self.milestone_id,
            "milestone_title": self.milestone_title,
            "topic": self.topic,
            "estimated_minutes": self.estimated_minutes,
            "rationale": self.rationale,
        }


@dataclass
class JourneySnapshot:
    """Aggregated view of the learner's journey across all surfaces."""

    generated_at: str
    profile: dict[str, Any] = field(default_factory=dict)
    plan_summary: dict[str, Any] = field(default_factory=dict)
    current_milestone: dict[str, Any] | None = None
    next_milestones: list[dict[str, Any]] = field(default_factory=list)
    completed_milestones: list[dict[str, Any]] = field(default_factory=list)
    topic_mastery: list[dict[str, Any]] = field(default_factory=list)
    gamification: dict[str, Any] = field(default_factory=dict)
    derived_signals: list[str] = field(default_factory=list)
    next_action: dict[str, Any] | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "generated_at": self.generated_at,
            "profile": self.profile,
            "plan_summary": self.plan_summary,
            "current_milestone": self.current_milestone,
            "next_milestones": self.next_milestones,
            "completed_milestones": self.completed_milestones,
            "topic_mastery": self.topic_mastery,
            "gamification": self.gamification,
            "derived_signals": sorted(self.derived_signals),
            "next_action": self.next_action,
        }


def _load_profile() -> dict[str, Any]:
    """Load the learner profile through the same path the learning-plan uses."""
    # Local import to avoid a circular dependency with the FastAPI router that
    # actually owns the profile schema; this function is called from request
    # handlers so the late import is essentially free.
    from deeptutor.api.routers.learning_profile import _load_raw

    return _load_raw() or {}


def _pick_current_milestone(plan: dict[str, Any]) -> dict[str, Any] | None:
    for phase in plan.get("phases") or []:
        for milestone in phase.get("milestones") or []:
            if milestone.get("status") == "active":
                return {**milestone, "phase_title": phase.get("title")}
    # Fall back to the first non-completed milestone.
    for phase in plan.get("phases") or []:
        for milestone in phase.get("milestones") or []:
            if milestone.get("status") != "completed":
                return {**milestone, "phase_title": phase.get("title")}
    return None


def _build_next_action(
    milestone: dict[str, Any] | None,
    mastery: dict[str, Any],
    ledger_events: list[dict[str, Any]],
) -> NextAction | None:
    """Pick the highest-value next step for the learner.

    Order of preference:
      1. If there's an active milestone with a mapped practice topic that is
         **not** yet mastered → recommend a practice round on that topic.
      2. If the milestone has no practice mapping, recommend an AI-tutor chat
         pre-filled with the milestone context.
      3. If everything is mastered, recommend the assessment center to
         consolidate.
    """
    if milestone is None:
        return NextAction(
            kind="onboarding",
            title="Complete onboarding",
            description=(
                "Tell us your goal and weekly time so we can build a roadmap"
                " tailored to you."
            ),
            href="/onboarding",
            estimated_minutes=5,
            rationale="No active learning plan detected.",
        )

    topic = _milestone_practice_topic(milestone)
    if topic and not mastery.get(topic, {}).get("mastered"):
        return NextAction(
            kind="practice",
            title=f"Practice: {milestone['title']}",
            description=(
                f"Answer 5 mixed-difficulty {topic.replace('_', ' ')} questions"
                " to make this milestone count toward your roadmap."
            ),
            href=f"/practice?topic={topic}&milestone={milestone['id']}",
            milestone_id=milestone["id"],
            milestone_title=milestone["title"],
            topic=topic,
            estimated_minutes=12,
            rationale=(
                f"Mastery threshold not met: need ≥5 correct & ≥60% accuracy"
                f" in {topic}."
            ),
        )

    # No practice topic mapping — push the learner to the AI tutor with the
    # milestone context pre-filled.
    return NextAction(
        kind="tutor",
        title=f"Discuss: {milestone['title']}",
        description=(
            "Ask the AI tutor to walk you through this milestone step-by-step."
            " The roadmap context is auto-attached."
        ),
        href=f"/chat?context=milestone:{milestone['id']}",
        milestone_id=milestone["id"],
        milestone_title=milestone["title"],
        topic=topic,
        estimated_minutes=20,
        rationale=(
            "Topic has no automated practice bank yet — guided tutor chat is"
            " the fastest hand-off."
        ),
    )


def get_learner_journey() -> JourneySnapshot:
    """Compose the full journey snapshot."""
    profile = _load_profile()
    plan = build_plan(profile)
    store = get_gamification_store()
    state = store.get_state()
    ledger_events = store.get_recent_xp_events(limit=1000)
    mastery = {t: m.to_dict() for t, m in compute_topic_mastery(ledger_events).items()}
    signals = sorted(derived_action_signals(ledger_events))

    current = _pick_current_milestone(plan)
    completed: list[dict[str, Any]] = []
    upcoming: list[dict[str, Any]] = []
    seen_active = False
    for phase in plan.get("phases") or []:
        for milestone in phase.get("milestones") or []:
            entry = {**milestone, "phase_title": phase.get("title")}
            if milestone.get("status") == "completed":
                completed.append(entry)
            elif milestone.get("status") != "completed" and (
                current is None or milestone.get("id") != current.get("id")
            ):
                if not seen_active and current and milestone.get("id") == current.get("id"):
                    seen_active = True
                    continue
                if len(upcoming) < 5:
                    upcoming.append(entry)

    next_action = _build_next_action(current, mastery, ledger_events)

    return JourneySnapshot(
        generated_at=datetime.now(timezone.utc).isoformat(),
        profile={
            "target_path": profile.get("target_path", ""),
            "goals": profile.get("goals") or [],
            "weekly_hours": profile.get("weekly_hours"),
            "experience_level": profile.get("experience_level", ""),
            "diagnostic_completed": bool(profile.get("diagnostic_completed")),
        },
        plan_summary={
            "plan_id": plan.get("plan_id"),
            "title": plan.get("title"),
            "summary": plan.get("summary"),
            "totals": plan.get("totals", {}),
            "is_preview": plan.get("is_preview", False),
        },
        current_milestone=current,
        next_milestones=upcoming,
        completed_milestones=completed,
        topic_mastery=sorted(mastery.values(), key=lambda m: -m["accuracy"]),
        gamification={
            "total_xp": state.get("total_xp", 0),
            "level": state.get("level"),
            "streak_current": state.get("streak_current", 0),
            "streak_max": state.get("streak_max", 0),
            "event_count": state.get("event_count", 0),
        },
        derived_signals=signals,
        next_action=next_action.to_dict() if next_action else None,
    )


def get_next_action() -> NextAction | None:
    """Return only the next-action recommendation (a lighter-weight call)."""
    profile = _load_profile()
    plan = build_plan(profile)
    store = get_gamification_store()
    ledger_events = store.get_recent_xp_events(limit=1000)
    mastery = {t: m.to_dict() for t, m in compute_topic_mastery(ledger_events).items()}
    current = _pick_current_milestone(plan)
    return _build_next_action(current, mastery, ledger_events)


__all__ = [
    "JourneySnapshot",
    "NextAction",
    "get_learner_journey",
    "get_next_action",
]
