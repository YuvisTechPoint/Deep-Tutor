"""Career intelligence API — role matches & skill-gap analysis.

Scores paths from the learner profile (goals, preparing_for, target_path),
practice / coding XP ledger, diagnostic baseline, and gamification stats.
Paths re-sort as activity accrues; clients subscribe via ``/api/v1/career/ws``.
"""

from __future__ import annotations

from datetime import datetime, timezone
import logging
from typing import Any

from fastapi import APIRouter

from deeptutor.api.routers.learning_profile import _load_raw as _load_profile
from deeptutor.services.gamification import compute_level, get_gamification_store
from deeptutor.services.workflow.mastery import compute_topic_mastery

logger = logging.getLogger(__name__)

router = APIRouter()

LEVEL_ORDER = {"none": 0, "beginner": 1, "intermediate": 2, "advanced": 3}
LEVEL_FROM_ORDER = {v: k for k, v in LEVEL_ORDER.items()}

# Map catalog skill labels → ledger topic slugs (practice + coding).
SKILL_TOPIC_KEYS: dict[str, tuple[str, ...]] = {
    "python": ("python", "general", "coding"),
    "python/java/go": ("python", "java", "go", "coding", "general"),
    "pytorch/tf": ("ml", "dl", "pytorch", "tensorflow", "deep learning"),
    "ml theory": ("ml", "machine learning", "math"),
    "mlops/docker": ("docker", "mlops", "devops"),
    "sql": ("sql", "db", "database"),
    "distributed": ("system_design", "distributed", "scalability"),
    "system design": ("system_design", "system design", "lld"),
    "databases": ("db", "sql", "database"),
    "apis/rest": ("api", "rest", "backend"),
    "docker/k8s": ("docker", "k8s", "devops"),
    "dsa": ("algorithms", "dsa", "data structures", "dp", "graphs"),
    "statistics": ("statistics", "math", "probability"),
    "visualization": ("visualization", "data", "analytics"),
    "ml": ("ml", "machine learning"),
    "communication": ("general", "career"),
    "physics": ("physics", "science"),
    "mathematics": ("math", "mathematics", "algebra"),
    "chemistry": ("chemistry", "science"),
    "biology": ("biology", "science"),
    "problem solving": ("algorithms", "general", "practice"),
    "board subjects": ("general", "science", "math"),
}


def _path_catalog() -> list[dict[str, Any]]:
    return [
        {
            "id": "ml-engineer",
            "title": "ML Engineer",
            "description": (
                "Build, train, and deploy machine learning models at scale."
                " Bridges research and production."
            ),
            "company_types": ["AI startups", "Big Tech", "Research labs"],
            "avg_salary": "$130k – $220k",
            "demand": "high",
            "timeline": "6–9 months",
            "projects": [
                "Train a transformer from scratch",
                "Deploy a FastAPI model serving endpoint",
                "Build a RAG system over a domain corpus",
            ],
            "skills": [
                {"name": "Python", "required": "advanced", "weight": 10},
                {"name": "PyTorch/TF", "required": "advanced", "weight": 9},
                {"name": "ML Theory", "required": "intermediate", "weight": 8},
                {"name": "MLOps/Docker", "required": "intermediate", "weight": 7},
                {"name": "SQL", "required": "intermediate", "weight": 6},
                {"name": "Distributed", "required": "beginner", "weight": 5},
            ],
            "model_roles": ["general", "coding", "math"],
            "signals": ("ml", "machine learning", "ai", "deep learning", "research"),
        },
        {
            "id": "sde-backend",
            "title": "Backend SDE",
            "description": (
                "Design and build scalable APIs, microservices, and distributed"
                " backend systems."
            ),
            "company_types": ["Fintech", "E-commerce", "SaaS"],
            "avg_salary": "$110k – $185k",
            "demand": "high",
            "timeline": "3–5 months",
            "projects": [
                "Build a REST API with auth + rate limiting",
                "Design a URL shortener (LLD)",
                "Redis-based caching layer",
            ],
            "skills": [
                {"name": "Python/Java/Go", "required": "advanced", "weight": 10},
                {"name": "System Design", "required": "intermediate", "weight": 9},
                {"name": "Databases", "required": "advanced", "weight": 9},
                {"name": "APIs/REST", "required": "advanced", "weight": 8},
                {"name": "Docker/K8s", "required": "intermediate", "weight": 7},
                {"name": "DSA", "required": "advanced", "weight": 8},
            ],
            "model_roles": ["general", "coding"],
            "signals": ("backend", "sde", "software", "api", "fullstack", "engineering", "job"),
        },
        {
            "id": "data-scientist",
            "title": "Data Scientist",
            "description": (
                "Extract insights from data, build predictive models, and"
                " communicate findings to stakeholders."
            ),
            "company_types": ["Consulting", "Finance", "Healthcare"],
            "avg_salary": "$100k – $165k",
            "demand": "medium",
            "timeline": "8–12 months",
            "projects": [
                "Kaggle competition top 20%",
                "A/B test analysis report",
                "Customer churn prediction model",
            ],
            "skills": [
                {"name": "Statistics", "required": "advanced", "weight": 10},
                {"name": "Python", "required": "advanced", "weight": 9},
                {"name": "SQL", "required": "advanced", "weight": 8},
                {"name": "Visualization", "required": "intermediate", "weight": 7},
                {"name": "ML", "required": "intermediate", "weight": 8},
                {"name": "Communication", "required": "advanced", "weight": 7},
            ],
            "model_roles": ["general", "math", "career"],
            "signals": ("data", "analytics", "statistics", "scientist"),
        },
        {
            "id": "engineering-entrance",
            "title": "Engineering Entrance",
            "description": (
                "Competitive engineering exams (JEE, GATE, state boards) —"
                " physics, math, and timed problem sets."
            ),
            "company_types": ["IITs & NITs", "State engineering colleges", "GATE recruiters"],
            "avg_salary": "Scholarship / placement track",
            "demand": "high",
            "timeline": "8–14 months",
            "projects": [
                "Complete 30 full-length mock papers",
                "Weak-topic drill deck (physics + math)",
                "Previous-year paper analysis notebook",
            ],
            "skills": [
                {"name": "Physics", "required": "advanced", "weight": 10},
                {"name": "Mathematics", "required": "advanced", "weight": 10},
                {"name": "Chemistry", "required": "intermediate", "weight": 8},
                {"name": "Problem solving", "required": "advanced", "weight": 9},
            ],
            "model_roles": ["general", "math"],
            "signals": ("engineering", "jee", "gate", "exam prep", "entrance"),
        },
        {
            "id": "medical-entrance",
            "title": "Medical Entrance",
            "description": (
                "NEET / medical school prep — biology-heavy syllabus with"
                " chemistry and physics foundations."
            ),
            "company_types": ["Medical colleges", "NEET coaching", "Clinical pathways"],
            "avg_salary": "Scholarship / residency track",
            "demand": "high",
            "timeline": "10–16 months",
            "projects": [
                "Biology concept map (all units)",
                "Daily MCQ streak tracker",
                "Mock NEET score trend report",
            ],
            "skills": [
                {"name": "Biology", "required": "advanced", "weight": 10},
                {"name": "Chemistry", "required": "advanced", "weight": 9},
                {"name": "Physics", "required": "intermediate", "weight": 7},
                {"name": "Problem solving", "required": "intermediate", "weight": 8},
            ],
            "model_roles": ["general", "math"],
            "signals": ("medical", "neet", "medicine", "biology", "exam prep"),
        },
        {
            "id": "school-academics",
            "title": "School Academics",
            "description": (
                "Board exams and school coursework — structured revision,"
                " fundamentals, and exam technique."
            ),
            "company_types": ["School boards", "Tutoring", "Foundation programs"],
            "avg_salary": "Academic progression",
            "demand": "medium",
            "timeline": "3–8 months",
            "projects": [
                "Subject-wise revision timetable",
                "Past-paper error log",
                "Weekly self-quiz habit",
            ],
            "skills": [
                {"name": "Board subjects", "required": "intermediate", "weight": 9},
                {"name": "Mathematics", "required": "intermediate", "weight": 8},
                {"name": "Problem solving", "required": "intermediate", "weight": 7},
            ],
            "model_roles": ["general"],
            "signals": ("school", "board", "coursework", "university", "exam prep"),
        },
    ]


def _profile_blob(profile: dict[str, Any]) -> str:
    parts = [
        str(profile.get("target_path", "")),
        str(profile.get("career_path_id", "")),
        " ".join(profile.get("goals") or []),
        " ".join(profile.get("preparing_for") or []),
        str(profile.get("experience_level", "")),
        str(profile.get("prior_summary", "")),
    ]
    answers = profile.get("domain_answers")
    if isinstance(answers, dict):
        parts.append(" ".join(str(v) for v in answers.values()))
    diag = profile.get("diagnostic_summary")
    if isinstance(diag, dict):
        parts.append(str(diag.get("score", "")))
    return " ".join(parts).lower()


def _preparing_for_slug(profile: dict[str, Any]) -> set[str]:
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


def _path_match_score(path: dict[str, Any], profile: dict[str, Any]) -> int:
    blob = _profile_blob(profile)
    score = 35
    for sig in path.get("signals") or ():
        if sig in blob:
            score += 12
    prep = _preparing_for_slug(profile)
    pid = path["id"]
    if "engineering" in prep and pid == "engineering-entrance":
        score += 28
    if "medical" in prep and pid == "medical-entrance":
        score += 28
    if "school" in prep and pid == "school-academics":
        score += 28
    if not prep and pid in {"ml-engineer", "sde-backend", "data-scientist"}:
        score += 10
    selected = str(profile.get("career_path_id") or "").strip()
    if selected and selected == pid:
        score += 35
    return min(100, score)


def _ledger_events() -> list[dict[str, Any]]:
    return get_gamification_store().get_recent_xp_events(limit=1000)


def _coding_solves_by_topic(events: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for evt in events:
        if evt.get("action") != "coding_practice.solve":
            continue
        meta = evt.get("metadata") or {}
        topic = str(meta.get("topic") or "coding").strip().lower()
        counts[topic] = counts.get(topic, 0) + 1
    return counts


def _topic_mastery_scores(events: list[dict[str, Any]]) -> dict[str, int]:
    """Topic slug → mastery percent (0–100) from practice + coding activity."""
    mastery: dict[str, int] = {}
    for topic, entry in compute_topic_mastery(events).items():
        pct = int(round(entry.accuracy * 100))
        if entry.mastered:
            pct = max(pct, 80)
        mastery[topic] = min(100, pct)

    for topic, solves in _coding_solves_by_topic(events).items():
        boost = min(100, 40 + solves * 12)
        mastery[topic] = max(mastery.get(topic, 0), boost)

    # Legacy incremental rollup for topics only in metadata.topic
    incremental: dict[str, int] = {}
    for evt in events:
        meta = evt.get("metadata") or {}
        topic = (meta.get("topic") or "").lower().strip()
        if not topic:
            continue
        cur = incremental.get(topic, 0)
        if evt.get("action") == "practice.correct_answer":
            incremental[topic] = min(100, cur + 10)
        elif evt.get("action") == "practice.incorrect_answer":
            incremental[topic] = max(0, cur - 5)
    for topic, score in incremental.items():
        mastery[topic] = max(mastery.get(topic, 0), score)
    return mastery


def _skill_topic_keys(skill_name: str) -> tuple[str, ...]:
    key = skill_name.lower().strip()
    if key in SKILL_TOPIC_KEYS:
        return SKILL_TOPIC_KEYS[key]
    first = key.split("/")[0].strip()
    return SKILL_TOPIC_KEYS.get(first, (first, key))


def _best_topic_score(skill_name: str, topic_mastery: dict[str, int]) -> int:
    best = 0
    for slug in _skill_topic_keys(skill_name):
        best = max(best, topic_mastery.get(slug, 0))
    return best


def _experience_baseline(profile: dict[str, Any]) -> int:
    level = str(profile.get("experience_level") or "none").lower()
    return LEVEL_ORDER.get(level, 0)


def _score_to_level(score: int) -> str:
    return LEVEL_FROM_ORDER[_topic_to_level(score)]


def _topic_to_level(score: int) -> int:
    if score >= 80:
        return LEVEL_ORDER["advanced"]
    if score >= 50:
        return LEVEL_ORDER["intermediate"]
    if score > 0:
        return LEVEL_ORDER["beginner"]
    return LEVEL_ORDER["none"]


def _annotate_skills(
    skills: list[dict[str, Any]],
    topic_mastery: dict[str, int],
    profile: dict[str, Any],
) -> list[dict[str, Any]]:
    baseline = _experience_baseline(profile)
    annotated: list[dict[str, Any]] = []
    for s in skills:
        topic_score = _best_topic_score(s["name"], topic_mastery)
        current_order = max(baseline, _topic_to_level(topic_score))
        annotated.append({**s, "current": LEVEL_FROM_ORDER[current_order]})
    return annotated


def _readiness(skills: list[dict[str, Any]]) -> int:
    if not skills:
        return 0
    weighted_total = sum(s["weight"] for s in skills) or 1
    score = 0.0
    for s in skills:
        required = LEVEL_ORDER.get(s["required"], 0) or 1
        current = LEVEL_ORDER.get(s.get("current", "none"), 0)
        achieved = min(current, required)
        score += s["weight"] * (achieved / required)
    return int(round((score / weighted_total) * 100))


def _estimate_timeline(skills: list[dict[str, Any]], profile: dict[str, Any]) -> str:
    gaps = sum(
        1
        for s in skills
        if LEVEL_ORDER.get(s.get("current", "none"), 0)
        < LEVEL_ORDER.get(s["required"], 0)
    )
    weekly = profile.get("weekly_hours")
    hours = float(weekly) if weekly else 8.0
    weeks = max(4, int(round((gaps * 18) / max(hours, 2))))
    if weeks <= 8:
        return f"{max(1, weeks // 4)}–{max(2, (weeks + 3) // 4)} months"
    if weeks <= 24:
        return f"{weeks // 4}–{(weeks + 7) // 4} months"
    return f"{weeks // 4}–{(weeks + 11) // 4} months"


def _learner_stats(events: list[dict[str, Any]], profile: dict[str, Any]) -> dict[str, Any]:
    store = get_gamification_store()
    state = store.get_state()
    correct = sum(1 for e in events if e.get("action") == "practice.correct_answer")
    incorrect = sum(1 for e in events if e.get("action") == "practice.incorrect_answer")
    total_answers = correct + incorrect
    coding_solved = sum(1 for e in events if e.get("action") == "coding_practice.solve")
    mastery = compute_topic_mastery(events)
    diag_pct: int | None = None
    diag = profile.get("diagnostic_summary")
    if isinstance(diag, dict):
        score = diag.get("score") or {}
        if isinstance(score, dict) and score.get("total"):
            diag_pct = int(round((score.get("correct", 0) / score["total"]) * 100))

    return {
        "streak_current": int(state.get("streak_current") or 0),
        "streak_max": int(state.get("streak_max") or 0),
        "total_xp": int(state.get("total_xp") or 0),
        "level": compute_level(int(state.get("total_xp") or 0)),
        "practice_accuracy": (
            int(round((correct / total_answers) * 100)) if total_answers else 0
        ),
        "problems_solved": correct + coding_solved,
        "coding_solved": coding_solved,
        "topics_practiced": len(mastery),
        "topics_mastered": sum(1 for m in mastery.values() if m.mastered),
        "diagnostic_score_pct": diag_pct,
    }


def _build_paths(profile: dict[str, Any], events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    topic_mastery = _topic_mastery_scores(events)
    paths: list[dict[str, Any]] = []
    for path in _path_catalog():
        annotated = _annotate_skills(path["skills"], topic_mastery, profile)
        readiness = _readiness(annotated)
        match_score = _path_match_score(path, profile)
        combined = int(round(readiness * 0.55 + match_score * 0.45))
        paths.append(
            {
                **{k: v for k, v in path.items() if k != "signals"},
                "skills": annotated,
                "readiness": readiness,
                "match_score": match_score,
                "combined_score": combined,
                "timeline": _estimate_timeline(annotated, profile),
            }
        )
    paths.sort(key=lambda p: (-p["combined_score"], -p["readiness"]))
    return paths


def _has_live_activity(profile: dict[str, Any], events: list[dict[str, Any]]) -> bool:
    if profile.get("goals") or profile.get("preparing_for") or profile.get("target_path"):
        return True
    if profile.get("diagnostic_completed"):
        return True
    return any(
        e.get("action")
        in {
            "practice.correct_answer",
            "practice.incorrect_answer",
            "coding_practice.solve",
        }
        for e in events
    )


@router.get("/paths")
async def list_paths() -> dict:
    profile = _load_profile()
    events = _ledger_events()
    paths = _build_paths(profile, events)
    live = _has_live_activity(profile, events)
    recommended_id = paths[0]["id"] if paths else None
    return {
        "preview": not live,
        "live": live,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "rationale": (
            "Paths rank by your onboarding profile (goals, preparing_for, target path)"
            " plus live practice, coding lab, and diagnostic results."
            if live
            else (
                "Complete onboarding or run practice / coding / diagnostic to unlock"
                " personalised match scores."
            )
        ),
        "paths": paths,
        "recommended_path_id": recommended_id,
        "profile_summary": {
            "target_path": profile.get("target_path", ""),
            "experience_level": profile.get("experience_level", ""),
            "goals": profile.get("goals", []),
            "preparing_for": profile.get("preparing_for", []),
            "weekly_hours": profile.get("weekly_hours"),
            "diagnostic_completed": bool(profile.get("diagnostic_completed")),
        },
        "stats": _learner_stats(events, profile),
    }


@router.get("/paths/{path_id}")
async def get_path(path_id: str) -> dict:
    profile = _load_profile()
    events = _ledger_events()
    for path in _build_paths(profile, events):
        if path["id"] == path_id:
            return {**path, "preview": not _has_live_activity(profile, events), "live": _has_live_activity(profile, events)}
    return {"error": "not_found", "path_id": path_id}


__all__ = ["router"]
