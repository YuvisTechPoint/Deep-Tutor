"""Cross-feature workflow API.

Provides two endpoints the frontend uses to stitch surfaces together:

* ``GET /api/v1/workflow/journey`` — full learner journey (dashboard).
* ``GET /api/v1/workflow/next``    — single best next-action CTA (sidebar /
                                     dashboard tile / chat empty-state).
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from deeptutor.services.workflow import (
    get_learner_journey,
    get_next_action,
)

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/journey")
async def journey() -> dict:
    """Return the unified Learner Journey snapshot."""
    snapshot = get_learner_journey()
    return snapshot.to_dict()


@router.get("/next")
async def next_action() -> dict:
    """Return the single best next action with a deep-link CTA."""
    action = get_next_action()
    if action is None:
        return {"action": None}
    return {"action": action.to_dict()}


__all__ = ["router"]
