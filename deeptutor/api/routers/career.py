"""Career intelligence API — role matches & skill-gap analysis.

The role catalog ships with the repo (open-source, no proprietary taxonomies).
Match scoring is a deterministic skill-overlap computation against the learner
profile + accumulated practice mastery from the gamification ledger; this
implementation is **clearly tagged as a preview** so the UI can label it that
way. Once an embedding service is configured (BGE / e5), the scoring path can
be swapped for vector-based similarity.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter

from deeptutor.api.routers.learning_profile import _load_raw as _load_profile
from deeptutor.services.gamification import get_gamification_store

logger = logging.getLogger(__name__)

router = APIRouter()


# ─── Career path catalog ─────────────────────────────────────────────────────

LEVEL_ORDER = {"none": 0, "beginner": 1, "intermediate": 2, "advanced": 3}


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
        },
    ]


# ─── Skill mastery inference ────────────────────────────────────────────────


def _topic_mastery_from_ledger() -> dict[str, int]:
    """Derive per-topic mastery (0-100) from gamification events.

    Approximation: each ``practice.correct_answer`` event with metadata
    ``topic`` contributes 10 points to that topic (capped at 100). Each
    ``practice.incorrect_answer`` removes 5 (floored at 0).
    """

    store = get_gamification_store()
    events = store.get_recent_xp_events(limit=500)
    mastery: dict[str, int] = {}
    for evt in events:
        meta = evt.get("metadata") or {}
        topic = (meta.get("topic") or "").lower().strip()
        if not topic:
            continue
        cur = mastery.get(topic, 0)
        if evt.get("action") == "practice.correct_answer":
            mastery[topic] = min(100, cur + 10)
        elif evt.get("action") == "practice.incorrect_answer":
            mastery[topic] = max(0, cur - 5)
    return mastery


def _profile_skill_level(skill_name: str, base_experience: str) -> str:
    base = base_experience.lower() if base_experience else "none"
    if base in LEVEL_ORDER:
        return base
    return "none"


def _readiness(skills: list[dict[str, Any]], topic_mastery: dict[str, int], profile: dict[str, Any]) -> int:
    if not skills:
        return 0
    weighted_total = sum(s["weight"] for s in skills) or 1
    score = 0
    for s in skills:
        required = LEVEL_ORDER.get(s["required"], 0)
        current_label = _profile_skill_level(s["name"], profile.get("experience_level", ""))
        current = LEVEL_ORDER.get(current_label, 0)
        topic_key = s["name"].split("/")[0].lower()
        topic_score = topic_mastery.get(topic_key)
        if topic_score:
            current = max(current, _topic_to_level(topic_score))
        achieved = min(current, required)
        score += s["weight"] * (achieved / max(required, 1))
    return int(round((score / weighted_total) * 100))


def _topic_to_level(score: int) -> int:
    if score >= 80:
        return LEVEL_ORDER["advanced"]
    if score >= 50:
        return LEVEL_ORDER["intermediate"]
    if score > 0:
        return LEVEL_ORDER["beginner"]
    return LEVEL_ORDER["none"]


def _annotate_skills(skills: list[dict[str, Any]], topic_mastery: dict[str, int], profile: dict[str, Any]) -> list[dict[str, Any]]:
    annotated = []
    for s in skills:
        topic_key = s["name"].split("/")[0].lower()
        current_label = _profile_skill_level(s["name"], profile.get("experience_level", ""))
        if topic_key in topic_mastery:
            score = topic_mastery[topic_key]
            mapped = {
                LEVEL_ORDER["advanced"]: "advanced",
                LEVEL_ORDER["intermediate"]: "intermediate",
                LEVEL_ORDER["beginner"]: "beginner",
                LEVEL_ORDER["none"]: "none",
            }
            current_label = mapped[_topic_to_level(score)]
        annotated.append({**s, "current": current_label})
    return annotated


# ─── Endpoints ───────────────────────────────────────────────────────────────


@router.get("/paths")
async def list_paths() -> dict:
    profile = _load_profile()
    topic_mastery = _topic_mastery_from_ledger()
    paths = []
    for path in _path_catalog():
        annotated = _annotate_skills(path["skills"], topic_mastery, profile)
        readiness = _readiness(annotated, topic_mastery, profile)
        paths.append({**path, "skills": annotated, "readiness": readiness})
    return {
        "preview": True,
        "rationale": (
            "Matches are computed by a deterministic skill-overlap heuristic."
            " Vector-based matching (BGE embeddings) lands once an embedding"
            " backend is configured."
        ),
        "paths": paths,
        "profile_summary": {
            "target_path": profile.get("target_path", ""),
            "experience_level": profile.get("experience_level", ""),
            "goals": profile.get("goals", []),
        },
    }


@router.get("/paths/{path_id}")
async def get_path(path_id: str) -> dict:
    profile = _load_profile()
    topic_mastery = _topic_mastery_from_ledger()
    for path in _path_catalog():
        if path["id"] == path_id:
            annotated = _annotate_skills(path["skills"], topic_mastery, profile)
            readiness = _readiness(annotated, topic_mastery, profile)
            return {**path, "skills": annotated, "readiness": readiness, "preview": True}
    return {"error": "not_found", "path_id": path_id}


__all__ = ["router"]
