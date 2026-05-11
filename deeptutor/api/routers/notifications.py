"""In-app notification center API.

The notifications store is file-backed and shared with the gamification module
so that ledger events (badge unlocks, streak rolls, new roadmap milestones) can
auto-publish notifications without a worker process.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from deeptutor.services.gamification import get_gamification_store

logger = logging.getLogger(__name__)

router = APIRouter()


class NotificationCreate(BaseModel):
    type: str = Field(default="system_update", max_length=64)
    title: str = Field(min_length=1, max_length=200)
    message: str = Field(default="", max_length=2000)
    is_mention: bool = False
    is_system: bool = False
    action_label: str | None = None
    action_href: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class NotificationPayload(NotificationCreate):
    id: str
    created_at: str
    read: bool = False
    read_at: str | None = None


def _ensure_seed(store) -> list[dict[str, Any]]:
    """Seed deterministic helpful notifications the first time the file is empty."""

    data = store.list_notifications()
    if data:
        return data
    seed_payloads: list[dict[str, Any]] = [
        {
            "type": "system_update",
            "title": "Welcome to DeepTutor",
            "message": (
                "Your AI tutor workspace is ready. Open the Onboarding wizard so the"
                " roadmap, dashboard, and career engines can personalise to you."
            ),
            "action_label": "Start onboarding",
            "action_href": "/onboarding",
            "is_system": True,
        },
        {
            "type": "new_roadmap_item",
            "title": "Roadmap preview available",
            "message": (
                "A seed roadmap derived from open-source curricula is available."
                " It refreshes automatically once you complete onboarding + the diagnostic."
            ),
            "action_label": "View roadmap",
            "action_href": "/roadmap",
        },
    ]
    for p in seed_payloads:
        store.add_notification(p)
    return store.list_notifications()


@router.get("")
async def list_notifications() -> dict:
    store = get_gamification_store()
    data = _ensure_seed(store)
    unread = sum(1 for n in data if not n.get("read"))
    mentions = sum(1 for n in data if n.get("is_mention"))
    system = sum(1 for n in data if n.get("is_system"))
    return {
        "items": data,
        "counts": {
            "total": len(data),
            "unread": unread,
            "mentions": mentions,
            "system": system,
        },
    }


@router.post("", response_model=NotificationPayload)
async def create_notification(body: NotificationCreate) -> NotificationPayload:
    store = get_gamification_store()
    payload = store.add_notification(body.model_dump())
    return NotificationPayload(**payload)


@router.post("/{notification_id}/read")
async def mark_read(notification_id: str) -> dict:
    store = get_gamification_store()
    ok = store.mark_notification_read(notification_id, read=True)
    if not ok:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"id": notification_id, "read": True}


@router.post("/{notification_id}/unread")
async def mark_unread(notification_id: str) -> dict:
    store = get_gamification_store()
    ok = store.mark_notification_read(notification_id, read=False)
    if not ok:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"id": notification_id, "read": False}


@router.post("/mark-all-read")
async def mark_all_read() -> dict:
    store = get_gamification_store()
    changed = store.mark_all_notifications_read()
    return {"updated": changed}


@router.delete("/{notification_id}")
async def dismiss(notification_id: str) -> dict:
    store = get_gamification_store()
    ok = store.dismiss_notification(notification_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"id": notification_id, "dismissed": True}


__all__ = ["router"]
