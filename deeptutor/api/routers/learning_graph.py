"""Learning roadmap graph API (Neo4j optional)."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, Query

from deeptutor.analytics import neo4j_graph
from deeptutor.api.routers.auth import require_admin

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/next")
async def graph_next_milestones(
    milestone_id: str = Query(..., min_length=1, max_length=128),
) -> dict:
    """Return direct successor milestone ids from the graph (empty if Neo4j off)."""
    nxt = neo4j_graph.next_milestone_ids(milestone_id)
    return {
        "milestone_id": milestone_id,
        "next_milestone_ids": nxt,
        "source": "neo4j" if nxt else "fallback",
    }


@router.post("/sync")
async def graph_sync(
    _: object = Depends(require_admin),
) -> dict:
    """Rebuild milestone nodes/edges from built-in plan templates."""
    try:
        result = neo4j_graph.sync_milestone_graph_from_templates()
    except Exception as exc:
        logger.exception("Neo4j graph sync failed")
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    return {"ok": True, **result}


__all__ = ["router"]
