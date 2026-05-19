"""Fan-out in-app notifications for live-session prep events."""

from __future__ import annotations

import logging
from typing import Any

from deeptutor.multi_user.identity import list_user_info
from deeptutor.multi_user.paths import admin_scope, get_path_service_for_scope, scope_for_user
from deeptutor.services.gamification.store import GamificationStore

logger = logging.getLogger(__name__)


def _store_for_scope(user_id: str, *, is_admin: bool) -> GamificationStore:
    scope = admin_scope() if is_admin else scope_for_user(user_id, is_admin=False)
    ps = get_path_service_for_scope(scope)
    return GamificationStore(base_dir=ps.user_data_dir / "learning")


def notify_current_user(payload: dict[str, Any]) -> None:
    """Append a notification to the signed-in user's workspace."""
    from deeptutor.multi_user.paths import get_current_path_service

    ps = get_current_path_service()
    store = GamificationStore(base_dir=ps.user_data_dir / "learning")
    try:
        store.add_notification(payload)
    except Exception as exc:
        logger.warning("notify_current_user failed: %s", exc)


def notify_mentor_staff(payload: dict[str, Any]) -> None:
    """Notify admin workspace once and each mentor/institution account."""
    users = list_user_info()
    admin_written = False
    for row in users:
        if row.get("disabled"):
            continue
        role = str(row.get("role") or "student")
        uid = str(row.get("id") or "")
        if not uid:
            continue
        if role == "admin":
            if admin_written:
                continue
            try:
                ps = get_path_service_for_scope(admin_scope())
                GamificationStore(base_dir=ps.user_data_dir / "learning").add_notification(payload)
                admin_written = True
            except Exception as exc:
                logger.warning("notify admin workspace failed: %s", exc)
        elif role in ("mentor", "institution"):
            try:
                _store_for_scope(uid, is_admin=False).add_notification(payload)
            except Exception as exc:
                logger.warning("notify mentor %s failed: %s", uid, exc)


def notify_user_by_id(user_id: str, *, role: str, payload: dict[str, Any]) -> None:
    """Deliver a notification to a specific user's learning store."""
    is_admin = role == "admin"
    try:
        if is_admin:
            ps = get_path_service_for_scope(admin_scope())
        else:
            ps = get_path_service_for_scope(scope_for_user(user_id, is_admin=False))
        GamificationStore(base_dir=ps.user_data_dir / "learning").add_notification(payload)
    except Exception as exc:
        logger.warning("notify_user_by_id %s failed: %s", user_id, exc)
