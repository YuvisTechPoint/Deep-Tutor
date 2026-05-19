"""Deterministic learning-plan generator.

This module purposefully does **not** call an LLM. Every milestone is
hand-curated and tagged with the open-source model role(s) needed to power its
interactive elements (e.g. coding mentor → DeepSeek-Coder, math mentor →
DeepSeek-Math, tutor → Qwen2.5-32B).

The frontend ``/roadmap`` page consumes this plan; once a learner completes a
milestone (via Practice / Missions / etc.) the gamification ledger emits events
and ``update_milestone_status`` flips the milestone to ``completed`` so the UI
auto-reflects progress.
"""

from __future__ import annotations

from datetime import datetime, timezone
import json
import logging
from pathlib import Path
import threading
from typing import Any

from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)

# ─── Plan templates ──────────────────────────────────────────────────────────

# Each milestone is annotated with:
#   * ``model_roles``: which open-source roles power its interactive tools
#   * ``trigger_actions``: gamification ledger ``action`` strings that mark
#     the milestone as auto-complete (e.g. ``practice.topic_master:dsa``)
#
# Resources point to canonical open educational resources so a fresh
# installation has a real, usable roadmap even before integrators add their own
# KB content.

_PLAN_TEMPLATES: dict[str, dict[str, Any]] = {
    "ml_engineer": {
        "title": "Software Engineer — AI / ML Track",
        "summary": "Foundations → Core CS → ML specialization → Career ready",
        "phases": [
            {
                "id": "foundations",
                "title": "Foundations",
                "subtitle": "Core programming & CS basics",
                "milestones": [
                    {
                        "id": "py_fundamentals",
                        "title": "Python Fundamentals",
                        "description": "Variables, control flow, functions, OOP basics",
                        "xp": 500,
                        "estimated_days": 7,
                        "skills": ["Python", "OOP", "Functions"],
                        "model_roles": ["coding"],
                        "trigger_actions": ["practice.topic_master:python"],
                        "resources": [
                            {"title": "Python Crash Course", "type": "article", "duration": "2h"},
                            {"title": "Build a calculator", "type": "exercise", "duration": "30m"},
                        ],
                    },
                    {
                        "id": "data_structures",
                        "title": "Data Structures",
                        "description": "Arrays, linked lists, trees, graphs, hash maps",
                        "xp": 800,
                        "estimated_days": 14,
                        "skills": ["DSA", "Arrays", "Trees", "Hash Maps"],
                        "model_roles": ["coding", "general"],
                        "trigger_actions": ["practice.topic_master:algorithms"],
                        "resources": [
                            {"title": "Visualgo — DS visualisations", "type": "video", "duration": "3h"},
                            {"title": "20 LeetCode-easy practice", "type": "exercise", "duration": "5h"},
                        ],
                    },
                ],
            },
            {
                "id": "core_skills",
                "title": "Core Skills",
                "subtitle": "Algorithms & system-design basics",
                "milestones": [
                    {
                        "id": "sorting_searching",
                        "title": "Sorting & Searching",
                        "description": "Binary search, quick sort, merge sort, time complexity",
                        "xp": 600,
                        "estimated_days": 7,
                        "skills": ["Algorithms", "Big-O", "Binary Search"],
                        "model_roles": ["coding", "math"],
                        "trigger_actions": ["practice.topic_master:algorithms"],
                        "resources": [
                            {"title": "Algorithms Part I — Princeton (Coursera, free)", "type": "video", "duration": "4h"},
                        ],
                    },
                    {
                        "id": "dynamic_programming",
                        "title": "Dynamic Programming",
                        "description": "Memoization, tabulation, classic DP problems",
                        "xp": 1000,
                        "estimated_days": 14,
                        "skills": ["DP", "Recursion", "Optimization"],
                        "model_roles": ["coding", "math", "general"],
                        "trigger_actions": ["practice.topic_master:dp"],
                        "resources": [
                            {"title": "DP on trees & grids", "type": "video", "duration": "3h"},
                            {"title": "NeetCode DP playlist", "type": "video", "duration": "6h"},
                            {"title": "15 DP LeetCode-medium", "type": "exercise", "duration": "8h"},
                        ],
                    },
                    {
                        "id": "graphs",
                        "title": "Graphs & Advanced Trees",
                        "description": "BFS, DFS, Dijkstra, topological sort, segment trees",
                        "xp": 1200,
                        "estimated_days": 14,
                        "skills": ["Graphs", "BFS", "DFS", "Dijkstra"],
                        "model_roles": ["coding", "math"],
                        "trigger_actions": ["practice.topic_master:graphs"],
                        "resources": [
                            {"title": "Graph Algorithms — Tim Roughgarden", "type": "video", "duration": "5h"},
                            {"title": "Competitive programming exercises", "type": "exercise", "duration": "10h"},
                        ],
                    },
                ],
            },
            {
                "id": "specialization",
                "title": "Specialization",
                "subtitle": "Machine Learning & AI engineering",
                "milestones": [
                    {
                        "id": "ml_fundamentals",
                        "title": "ML Fundamentals",
                        "description": "Supervised, unsupervised, evaluation metrics, scikit-learn",
                        "xp": 1500,
                        "estimated_days": 21,
                        "skills": ["ML", "scikit-learn", "Statistics"],
                        "model_roles": ["general", "math"],
                        "trigger_actions": ["practice.topic_master:ml"],
                        "resources": [
                            {"title": "fast.ai Practical Deep Learning", "type": "video", "duration": "20h"},
                            {"title": "Kaggle competition: Titanic", "type": "project", "duration": "5h"},
                        ],
                    },
                    {
                        "id": "deep_learning",
                        "title": "Deep Learning",
                        "description": "Neural networks, CNNs, transformers, PyTorch",
                        "xp": 2000,
                        "estimated_days": 28,
                        "skills": ["PyTorch", "Neural Networks", "Transformers"],
                        "model_roles": ["coding", "general", "vision"],
                        "trigger_actions": ["practice.topic_master:dl"],
                        "resources": [
                            {"title": "Karpathy — Neural Nets Zero to Hero", "type": "video", "duration": "15h"},
                            {"title": "Train a small language model", "type": "project", "duration": "10h"},
                        ],
                    },
                ],
            },
            {
                "id": "career_ready",
                "title": "Career Ready",
                "subtitle": "Interview prep & portfolio projects",
                "milestones": [
                    {
                        "id": "system_design",
                        "title": "System Design",
                        "description": "Distributed systems, scalability, databases, caching",
                        "xp": 2500,
                        "estimated_days": 21,
                        "skills": ["System Design", "Databases", "Scalability"],
                        "model_roles": ["general"],
                        "trigger_actions": ["practice.topic_master:system_design"],
                        "resources": [
                            {"title": "System Design Interview — Alex Xu", "type": "article", "duration": "8h"},
                        ],
                    },
                    {
                        "id": "portfolio",
                        "title": "Portfolio & Job Applications",
                        "description": "3 production projects, resume polish, interview simulation",
                        "xp": 3000,
                        "estimated_days": 30,
                        "skills": ["Portfolio", "Communication", "Interviews"],
                        "model_roles": ["general", "career"],
                        "trigger_actions": ["career.portfolio_submitted"],
                        "resources": [
                            {"title": "Build a full-stack AI app", "type": "project", "duration": "20h"},
                            {"title": "Mock interviews with AI Tutor", "type": "exercise", "duration": "5h"},
                        ],
                    },
                ],
            },
        ],
    },
    "data_scientist": {
        "title": "Data Scientist Track",
        "summary": "Statistics → Python → ML → Communication",
        "phases": [
            {
                "id": "statistics",
                "title": "Statistics & Maths",
                "subtitle": "Probability, distributions, hypothesis testing",
                "milestones": [
                    {
                        "id": "probability",
                        "title": "Probability & Statistics",
                        "description": "Random variables, distributions, hypothesis tests",
                        "xp": 700,
                        "estimated_days": 10,
                        "skills": ["Statistics", "Probability"],
                        "model_roles": ["math", "general"],
                        "trigger_actions": ["practice.topic_master:probability"],
                        "resources": [
                            {"title": "Statistical Rethinking — McElreath", "type": "video", "duration": "20h"},
                        ],
                    },
                ],
            },
            {
                "id": "tooling",
                "title": "Data Tooling",
                "subtitle": "Python data stack",
                "milestones": [
                    {
                        "id": "pandas",
                        "title": "Pandas & NumPy",
                        "description": "Wrangle, clean, and analyse tabular data",
                        "xp": 600,
                        "estimated_days": 7,
                        "skills": ["Pandas", "NumPy"],
                        "model_roles": ["coding"],
                        "trigger_actions": ["practice.topic_master:python"],
                        "resources": [
                            {"title": "Python for Data Analysis — McKinney", "type": "article", "duration": "6h"},
                        ],
                    },
                ],
            },
            {
                "id": "modeling",
                "title": "Modeling",
                "subtitle": "Predictive models end-to-end",
                "milestones": [
                    {
                        "id": "regression_classification",
                        "title": "Regression & Classification",
                        "description": "Build a churn predictor and an A/B test analysis",
                        "xp": 900,
                        "estimated_days": 14,
                        "skills": ["scikit-learn", "Model evaluation"],
                        "model_roles": ["general", "math"],
                        "trigger_actions": ["practice.topic_master:ml"],
                        "resources": [
                            {"title": "Kaggle Learn — Intro to ML", "type": "exercise", "duration": "4h"},
                        ],
                    },
                ],
            },
        ],
    },
    "backend_sde": {
        "title": "Backend Software Engineer Track",
        "summary": "Languages → APIs → Databases → System design → Interviews",
        "phases": [
            {
                "id": "languages",
                "title": "Languages & DSA",
                "subtitle": "Pick a primary backend language, master DSA",
                "milestones": [
                    {
                        "id": "primary_lang",
                        "title": "Primary backend language",
                        "description": "Pick Python / Go / Java and reach advanced fluency",
                        "xp": 800,
                        "estimated_days": 14,
                        "skills": ["Python", "Go", "Java"],
                        "model_roles": ["coding"],
                        "trigger_actions": ["practice.topic_master:python"],
                        "resources": [
                            {"title": "Real Python — fundamentals", "type": "article", "duration": "5h"},
                        ],
                    },
                ],
            },
            {
                "id": "apis",
                "title": "APIs & Services",
                "subtitle": "REST, gRPC, queues, observability",
                "milestones": [
                    {
                        "id": "rest_apis",
                        "title": "REST APIs with FastAPI",
                        "description": "Auth, rate limiting, OpenAPI, testing",
                        "xp": 700,
                        "estimated_days": 10,
                        "skills": ["FastAPI", "REST", "Auth"],
                        "model_roles": ["coding", "general"],
                        "trigger_actions": ["practice.topic_master:api"],
                        "resources": [
                            {"title": "FastAPI official docs", "type": "article", "duration": "3h"},
                        ],
                    },
                ],
            },
            {
                "id": "systems",
                "title": "Systems",
                "subtitle": "Databases + system design",
                "milestones": [
                    {
                        "id": "databases",
                        "title": "Databases & Caching",
                        "description": "Postgres, indexes, transactions, Redis caching layers",
                        "xp": 900,
                        "estimated_days": 14,
                        "skills": ["PostgreSQL", "Redis", "Indexing"],
                        "model_roles": ["general", "coding"],
                        "trigger_actions": ["practice.topic_master:db"],
                        "resources": [
                            {"title": "Use The Index, Luke", "type": "article", "duration": "4h"},
                        ],
                    },
                    {
                        "id": "system_design",
                        "title": "System Design",
                        "description": "Sharding, queues, consistency, scale",
                        "xp": 1100,
                        "estimated_days": 21,
                        "skills": ["System Design", "Scalability"],
                        "model_roles": ["general"],
                        "trigger_actions": ["practice.topic_master:system_design"],
                        "resources": [
                            {"title": "System Design Primer (GitHub)", "type": "article", "duration": "10h"},
                        ],
                    },
                ],
            },
        ],
    },
}


# ─── Mapping target → template ──────────────────────────────────────────────

_TARGET_KEYWORDS: dict[str, tuple[str, ...]] = {
    "ml_engineer": ("ml", "machine learning", "ai", "deep learning", "neural"),
    "data_scientist": ("data scient", "analytics", "data analyst", "statistics"),
    "backend_sde": ("backend", "sde", "software engineer", "fullstack", "full stack", "api", "web dev"),
}


def _classify(target_path: str, goals: list[str], preparing_for: list[str] | None = None) -> str:
    haystack = " ".join([target_path, *goals, *(preparing_for or [])]).lower()
    for plan_id, keywords in _TARGET_KEYWORDS.items():
        for kw in keywords:
            if kw in haystack:
                return plan_id
    return "ml_engineer"


# ─── Plan progress tracking ──────────────────────────────────────────────────

_progress_lock = threading.Lock()


def _progress_path() -> Path:
    base = get_path_service().user_data_dir / "learning"
    base.mkdir(parents=True, exist_ok=True)
    return base / "learning_plan_progress.json"


def _load_progress() -> dict[str, dict[str, Any]]:
    path = _progress_path()
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            return data
    except Exception:
        pass
    return {}


def _save_progress(data: dict[str, dict[str, Any]]) -> None:
    path = _progress_path()
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def update_milestone_status(milestone_id: str, status: str) -> dict[str, Any]:
    """Mark a milestone as ``active`` / ``completed`` / ``locked``."""

    status = status.lower().strip()
    if status not in {"active", "completed", "locked", "available"}:
        raise ValueError(f"Invalid status: {status}")
    with _progress_lock:
        data = _load_progress()
        data[milestone_id] = {
            "status": status,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        _save_progress(data)
    record = data[milestone_id]
    try:
        from deeptutor.analytics.emit import emit_domain_event

        emit_domain_event(
            "MilestoneStatusUpdated",
            subject_type="Milestone",
            subject_id=milestone_id,
            payload={"status": status, "record": record, "source": "planner"},
        )
    except Exception:
        logger.debug("domain event emit failed for milestone", exc_info=True)
    return record


def _gamification_signal(trigger_actions: list[str]) -> dict[str, Any]:
    """Inspect the gamification ledger for trigger-action hits.

    Looks at both:

    * raw events in the XP ledger (e.g. ``mission.complete``)
    * derived signals from :mod:`deeptutor.services.workflow.signals`
      (e.g. ``practice.topic_master:python`` projected from many
      ``practice.correct_answer`` events crossing a mastery threshold).

    Either source flipping a milestone's trigger-action set means the
    milestone auto-completes.
    """
    from deeptutor.services.gamification import get_gamification_store
    from deeptutor.services.workflow.signals import derived_action_signals

    store = get_gamification_store()
    events = store.get_recent_xp_events(limit=1000)
    trigger_set = set(trigger_actions or ())
    completed = False
    for evt in events:
        if evt.get("action") in trigger_set:
            completed = True
            break
    if not completed and trigger_set:
        derived = derived_action_signals(events)
        if trigger_set & derived:
            completed = True
    return {"auto_completed": completed}


# ─── Public API ─────────────────────────────────────────────────────────────


def list_plan_templates() -> list[dict[str, Any]]:
    """Return a slim listing of the available plan templates."""
    return [
        {
            "id": plan_id,
            "title": plan["title"],
            "summary": plan["summary"],
            "phases": [p["title"] for p in plan["phases"]],
        }
        for plan_id, plan in _PLAN_TEMPLATES.items()
    ]


def iter_milestone_prerequisite_edges() -> list[dict[str, Any]]:
    """Return ordered milestone pairs (from_id -> to_id) within each phase.

    Used to populate Neo4j ``(:Milestone)-[:NEXT]->(:Milestone)`` edges so the
    graph API can suggest the next roadmap step after a completed milestone.
    """
    edges: list[dict[str, Any]] = []
    for plan_id, plan in _PLAN_TEMPLATES.items():
        for phase in plan["phases"]:
            pid = str(phase["id"])
            prev: str | None = None
            for m in phase["milestones"]:
                mid = str(m["id"])
                if prev is not None:
                    edges.append(
                        {
                            "plan_id": plan_id,
                            "phase_id": pid,
                            "from_id": prev,
                            "to_id": mid,
                        }
                    )
                prev = mid
    return edges


def plan_signature(profile: dict[str, Any]) -> str:
    """Stable signature for caching — currently just the plan key."""
    return _classify(
        profile.get("target_path", ""),
        profile.get("goals", []),
        profile.get("preparing_for", []),
    )


def build_plan(profile: dict[str, Any]) -> dict[str, Any]:
    """Compose a plan for a given learner profile.

    Returns the JSON document the frontend ``/roadmap`` page expects, with
    progress overlay and model-role annotations.
    """

    plan_id = _classify(
        profile.get("target_path", ""),
        profile.get("goals") or [],
        profile.get("preparing_for") or [],
    )
    template = _PLAN_TEMPLATES[plan_id]
    progress = _load_progress()
    weekly_hours = int(profile.get("weekly_hours") or 6)
    experience = (profile.get("experience_level") or "beginner").lower()

    phases: list[dict[str, Any]] = []
    total_milestones = 0
    completed_milestones = 0
    total_xp_completed = 0
    next_active_set = False
    has_any_completed = False

    for phase in template["phases"]:
        milestones: list[dict[str, Any]] = []
        phase_done = 0
        for raw in phase["milestones"]:
            total_milestones += 1
            stored = progress.get(raw["id"])
            stored_status = stored["status"] if stored else None
            auto = _gamification_signal(list(raw.get("trigger_actions") or []))
            if auto["auto_completed"]:
                status = "completed"
            elif stored_status:
                status = stored_status
            elif not next_active_set:
                status = "active"
                next_active_set = True
            else:
                status = "available" if has_any_completed else "available"
            if status == "completed":
                phase_done += 1
                completed_milestones += 1
                total_xp_completed += raw["xp"]
                has_any_completed = True
            elif status == "active":
                next_active_set = True
            milestones.append(
                {
                    "id": raw["id"],
                    "title": raw["title"],
                    "description": raw["description"],
                    "xp": raw["xp"],
                    "estimated_days": _scale_days(raw["estimated_days"], weekly_hours, experience),
                    "skills": list(raw.get("skills") or []),
                    "model_roles": list(raw.get("model_roles") or ["general"]),
                    "resources": list(raw.get("resources") or []),
                    "status": status,
                    "auto_completed": auto["auto_completed"],
                    "trigger_actions": list(raw.get("trigger_actions") or []),
                }
            )
        phase_status = (
            "completed"
            if phase_done == len(phase["milestones"])
            else "active"
            if any(m["status"] in {"active", "available"} for m in milestones)
            else "locked"
        )
        phases.append(
            {
                "id": phase["id"],
                "title": phase["title"],
                "subtitle": phase["subtitle"],
                "status": phase_status,
                "milestones": milestones,
            }
        )

    progress_pct = (
        int((completed_milestones / total_milestones) * 100) if total_milestones else 0
    )
    return {
        "plan_id": plan_id,
        "title": template["title"],
        "summary": template["summary"],
        "is_preview": not bool(profile.get("target_path")),
        "weekly_hours": weekly_hours,
        "experience_level": experience,
        "totals": {
            "milestones_total": total_milestones,
            "milestones_completed": completed_milestones,
            "xp_completed": total_xp_completed,
            "progress_pct": progress_pct,
        },
        "phases": phases,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


def _scale_days(base_days: int, weekly_hours: int, experience: str) -> int:
    """Adjust estimated duration based on weekly hours + experience."""
    factor = 1.0
    if weekly_hours <= 0:
        weekly_hours = 6
    factor *= 6.0 / max(weekly_hours, 2)
    if experience == "advanced":
        factor *= 0.7
    elif experience == "intermediate":
        factor *= 0.85
    scaled = max(1, int(round(base_days * factor)))
    return scaled


__all__ = [
    "build_plan",
    "list_plan_templates",
    "plan_signature",
    "update_milestone_status",
]
