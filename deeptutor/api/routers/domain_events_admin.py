"""Admin-only read access to durable domain analytics events."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from deeptutor.analytics.event_store import get_domain_event_store
from deeptutor.analytics.funnel import compute_funnel
from deeptutor.api.routers.auth import require_admin

router = APIRouter()


@router.get("/domain-events")
async def list_domain_events(
    _: object = Depends(require_admin),
    limit: int = Query(default=50, ge=1, le=500),
) -> dict:
    rows = get_domain_event_store().list_recent(limit=limit)
    return {
        "items": [
            {
                "event_id": r.event_id,
                "name": r.name,
                "schema_version": r.schema_version,
                "actor_id": r.actor_id,
                "correlation_id": r.correlation_id,
                "subject_type": r.subject_type,
                "subject_id": r.subject_id,
                "payload": r.payload,
                "created_at_ms": r.created_at_ms,
                "exported_at_ms": r.exported_at_ms,
            }
            for r in rows
        ],
    }


@router.get("/analytics/funnel")
async def analytics_funnel(
    _: object = Depends(require_admin),
) -> dict:
    """Pilot funnel from local domain_events (ClickHouse replica is optional)."""
    return compute_funnel()


__all__ = ["router"]
