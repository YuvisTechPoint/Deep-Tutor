"""Learning Profile API — persists the learner's onboarding answers.

Endpoints:
  GET  /api/v1/learning-profile   — load profile (returns empty defaults if not found)
  PUT  /api/v1/learning-profile   — save / update profile
"""
from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter
from pydantic import BaseModel, Field

from deeptutor.services.path_service import get_path_service

router = APIRouter()
logger = logging.getLogger(__name__)


# ─── Schema ───────────────────────────────────────────────────────────────────

class LearningProfile(BaseModel):
    goals: list[str] = Field(default_factory=list)
    target_path: str = ""
    weekly_hours: int | None = None
    learning_styles: list[str] = Field(default_factory=list)
    experience_level: str = ""
    prior_summary: str = ""
    diagnostic_completed: bool = False
    updated_at: str | None = None


# ─── Storage helpers ──────────────────────────────────────────────────────────

def _profile_path() -> Path:
    """Return the path to learning_profile.json inside the user data dir."""
    path_svc = get_path_service()
    profile_dir = path_svc.user_data_dir / "learning"
    profile_dir.mkdir(parents=True, exist_ok=True)
    return profile_dir / "profile.json"


def _load_raw() -> dict:
    path = _profile_path()
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        logger.warning("Failed to read learning profile from %s", path)
        return {}


def _save_raw(data: dict) -> None:
    path = _profile_path()
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.get("", response_model=LearningProfile)
async def get_learning_profile() -> LearningProfile:
    """Return the stored learning profile. If none exists, returns empty defaults."""
    raw = _load_raw()
    return LearningProfile(**raw)


@router.put("", response_model=LearningProfile)
async def save_learning_profile(body: LearningProfile) -> LearningProfile:
    """Persist the learner's profile answers from onboarding."""
    payload = body.model_dump(exclude={"updated_at"})
    payload["updated_at"] = datetime.now(timezone.utc).isoformat()
    _save_raw(payload)
    return LearningProfile(**payload)
