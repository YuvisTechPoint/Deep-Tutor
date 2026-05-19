"""Career intelligence updates — WebSocket stream for realtime path re-evaluation."""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

router = APIRouter()

# Global set of active WebSocket connections (per session)
_ACTIVE_CONNECTIONS: dict[str, list[WebSocket]] = {}
_CONNECTION_LOCK = asyncio.Lock()


async def broadcast_career_update(message: dict[str, Any]) -> None:
    """Broadcast a career/gamification update to all connected clients."""
    async with _CONNECTION_LOCK:
        # Clean up closed connections and send to active ones
        for session_id, ws_list in list(_ACTIVE_CONNECTIONS.items()):
            active_ws: list[WebSocket] = []
            for ws in ws_list:
                try:
                    await ws.send_json(message)
                    active_ws.append(ws)
                except Exception:
                    # Connection likely closed; skip it
                    pass
            if active_ws:
                _ACTIVE_CONNECTIONS[session_id] = active_ws
            else:
                del _ACTIVE_CONNECTIONS[session_id]


@router.websocket("/ws")
async def websocket_career_updates(ws: WebSocket) -> None:
    """WebSocket endpoint for realtime career path updates.

    When the learner earns XP from practice/coding/etc, this stream emits
    gamification_update events so the frontend can refresh without polling.
    """
    # Auth check — mirrors unified_ws.py approach
    from deeptutor.multi_user.context import (
        reset_current_user,
        set_current_user,
        user_from_token_payload,
    )
    from deeptutor.multi_user.paths import local_admin_user
    from deeptutor.services.auth import AUTH_ENABLED, decode_token

    user_token = None
    if AUTH_ENABLED:
        token = ws.query_params.get("token") or ws.cookies.get("dt_token")
        payload = decode_token(token) if token else None
        if not payload:
            await ws.close(code=4001)
            return
        user_token = set_current_user(user_from_token_payload(payload))
    else:
        user_token = set_current_user(local_admin_user())

    await ws.accept()
    session_id = ws.query_params.get("session_id", "default")

    # Register this connection
    async with _CONNECTION_LOCK:
        if session_id not in _ACTIVE_CONNECTIONS:
            _ACTIVE_CONNECTIONS[session_id] = []
        _ACTIVE_CONNECTIONS[session_id].append(ws)

    try:
        while True:
            # Wait for client messages (typically keepalive or unsubscribe)
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await ws.send_json({"type": "error", "content": "Invalid JSON."})
                continue

            msg_type = msg.get("type")

            # Currently we just support keepalive; other message types can be added
            if msg_type == "ping":
                await ws.send_json({"type": "pong"})
            elif msg_type == "unsubscribe":
                break
    except WebSocketDisconnect:
        logger.debug("Client disconnected from career updates")
    except Exception as exc:
        logger.error("Career updates WS error: %s", exc, exc_info=True)
    finally:
        # Unregister this connection
        async with _CONNECTION_LOCK:
            if session_id in _ACTIVE_CONNECTIONS:
                try:
                    _ACTIVE_CONNECTIONS[session_id].remove(ws)
                except ValueError:
                    pass
                if not _ACTIVE_CONNECTIONS[session_id]:
                    del _ACTIVE_CONNECTIONS[session_id]
        if user_token is not None:
            reset_current_user(user_token)


__all__ = ["broadcast_career_update", "router"]
