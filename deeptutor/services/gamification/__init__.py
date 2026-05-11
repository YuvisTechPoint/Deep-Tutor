"""Gamification service — XP ledger, streaks, badges, notifications.

File-backed (deterministic seed JSON inside ``data/user/learning/``) so the
sidebar features (Dashboard, Missions, Achievements, Notifications, Analytics)
have real, durable state without requiring Postgres provisioning.

All persistence goes through :class:`GamificationStore` which guarantees
ledger-style append-only semantics for XP events and idempotent updates for
streaks / badges / notifications.
"""

from deeptutor.services.gamification.store import (
    DEFAULT_BADGES,
    GamificationStore,
    LevelInfo,
    XPEvent,
    compute_level,
    get_gamification_store,
)

__all__ = [
    "DEFAULT_BADGES",
    "GamificationStore",
    "LevelInfo",
    "XPEvent",
    "compute_level",
    "get_gamification_store",
]
