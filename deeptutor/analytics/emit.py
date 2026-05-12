"""Fire-and-forget domain event emission (never raises to callers)."""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)


def _resolve_actor_id(explicit: str | None) -> str | None:
    if explicit is not None:
        return explicit or None
    try:
        from deeptutor.multi_user.context import get_current_user_or_none

        u = get_current_user_or_none()
        if u is None:
            return None
        return str(u.id)
    except Exception:
        return None


def emit_domain_event(
    name: str,
    *,
    actor_id: str | None = None,
    correlation_id: str | None = None,
    subject_type: str | None = None,
    subject_id: str | None = None,
    payload: dict[str, Any] | None = None,
) -> None:
    """Append a durable domain event. Swallows errors so HTTP paths stay fast."""
    try:
        from deeptutor.analytics.event_store import get_domain_event_store

        store = get_domain_event_store()
        store.append(
            name,
            actor_id=_resolve_actor_id(actor_id),
            correlation_id=correlation_id,
            subject_type=subject_type,
            subject_id=subject_id,
            payload=payload,
        )
    except Exception:
        logger.debug("emit_domain_event failed for %s", name, exc_info=True)


__all__ = ["emit_domain_event"]
