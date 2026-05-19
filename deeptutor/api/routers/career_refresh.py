"""Fire-and-forget career refresh broadcasts for connected clients."""

from __future__ import annotations

import asyncio
import logging
from typing import Any

logger = logging.getLogger(__name__)


def schedule_career_refresh(reason: str, **payload: Any) -> None:
    """Notify career page subscribers to refetch paths (non-blocking)."""
    try:
        from deeptutor.api.routers.career_updates import broadcast_career_update

        message: dict[str, Any] = {"type": "career_refresh", "reason": reason, **payload}
        asyncio.get_running_loop().create_task(broadcast_career_update(message))
    except RuntimeError:
        pass
    except Exception:
        logger.debug("career refresh broadcast skipped", exc_info=True)


__all__ = ["schedule_career_refresh"]
