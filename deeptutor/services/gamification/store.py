"""File-backed gamification store.

Stores three JSON documents inside ``<user_data>/learning/``:

* ``xp_events.jsonl``     — append-only ledger of XP awards
* ``gamification.json``   — derived state cache (XP total, streak counters, badge
                            unlock timestamps, mission progress)
* ``notifications.json``  — durable in-app notifications

The store is intentionally single-user and synchronous; it is wrapped by the
FastAPI routers which add async-friendly locking via ``asyncio.Lock``.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import threading
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)


# ─── Constants ────────────────────────────────────────────────────────────────


@dataclass(frozen=True)
class BadgeDefinition:
    badge_id: str
    icon: str
    title: str
    description: str
    xp_reward: int
    condition: str
    rare: bool = False


DEFAULT_BADGES: tuple[BadgeDefinition, ...] = (
    BadgeDefinition(
        "first_flame", "🔥", "First Flame",
        "Complete your first study session", 50, "Complete 1 session",
    ),
    BadgeDefinition(
        "speed_solver", "⚡", "Speed Solver",
        "Solve 5 practice questions in under 30 minutes", 100, "5 fast solves",
    ),
    BadgeDefinition(
        "sharp_mind", "🎯", "Sharp Mind",
        "Score 100% on a practice quiz", 150, "Perfect quiz score", rare=True,
    ),
    BadgeDefinition(
        "bookworm", "📚", "Bookworm",
        "Read 10 book chapters on DeepTutor", 120, "10 chapters read",
    ),
    BadgeDefinition(
        "week_warrior", "🌟", "Week Warrior",
        "Maintain a 7-day study streak", 200, "7-day streak",
    ),
    BadgeDefinition(
        "dsa_master_1", "🧠", "DSA Master Lv.1",
        "Reach 70% mastery in Data Structures", 300, "DSA mastery ≥ 70%", rare=True,
    ),
    BadgeDefinition(
        "century_club", "🏆", "Century Club",
        "Solve 100 practice questions", 500, "100 problems solved", rare=True,
    ),
    BadgeDefinition(
        "voice_virtuoso", "🎙️", "Voice Virtuoso",
        "Complete 20 voice Q&A sessions", 250, "20 voice sessions",
    ),
    BadgeDefinition(
        "streak_legend", "🔗", "Streak Legend",
        "Maintain a 30-day study streak", 600, "30-day streak", rare=True,
    ),
    BadgeDefinition(
        "system_architect", "🌐", "System Architect",
        "Reach 80% mastery in System Design", 400, "System Design ≥ 80%",
    ),
    BadgeDefinition(
        "ai_collaborator", "🤖", "AI Collaborator",
        "Complete 50 deep_solve sessions", 350, "50 deep_solve sessions",
    ),
    BadgeDefinition(
        "grandmaster", "👑", "Grandmaster",
        "Reach Level 15", 1000, "Reach Level 15", rare=True,
    ),
    BadgeDefinition(
        "polyglot", "🌈", "Polyglot",
        "Achieve 70%+ mastery in 5 different topics", 750, "5 topics ≥ 70%",
    ),
    BadgeDefinition(
        "rocket_learner", "🚀", "Rocket Learner",
        "Earn 500 XP in a single day", 400, "500 XP in one day",
    ),
    BadgeDefinition(
        "graduate", "🎓", "Graduate",
        "Complete an entire learning roadmap", 1200, "Full roadmap complete", rare=True,
    ),
    BadgeDefinition(
        "diamond_scholar", "💎", "Diamond Scholar",
        "Earn 50,000 total XP", 2000, "50,000 lifetime XP", rare=True,
    ),
)


@dataclass
class XPEvent:
    """One row in the XP ledger."""

    event_id: str
    action: str
    xp: int
    source: str
    timestamp: str
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "event_id": self.event_id,
            "action": self.action,
            "xp": self.xp,
            "source": self.source,
            "timestamp": self.timestamp,
            "metadata": self.metadata,
        }


@dataclass
class LevelInfo:
    level: int
    xp_into_level: int
    xp_for_next_level: int
    total_xp: int

    @property
    def progress_pct(self) -> int:
        if self.xp_for_next_level <= 0:
            return 100
        return min(100, round((self.xp_into_level / self.xp_for_next_level) * 100))

    def to_dict(self) -> dict[str, Any]:
        return {
            "level": self.level,
            "xp_into_level": self.xp_into_level,
            "xp_for_next_level": self.xp_for_next_level,
            "total_xp": self.total_xp,
            "progress_pct": self.progress_pct,
        }


def compute_level(total_xp: int) -> LevelInfo:
    """Triangular XP curve — level *n* requires n * 1000 XP cumulative.

    Level 1 thresholds: 0, 1000, 3000, 6000, 10000, 15000, 21000, ...
    """

    total_xp = max(0, int(total_xp))
    level = 1
    cumulative = 0
    while True:
        needed = level * 1000
        if cumulative + needed > total_xp:
            return LevelInfo(
                level=level,
                xp_into_level=total_xp - cumulative,
                xp_for_next_level=needed,
                total_xp=total_xp,
            )
        cumulative += needed
        level += 1
        # Defensive cap — never spin forever for absurd values.
        if level > 200:
            return LevelInfo(level=level, xp_into_level=0, xp_for_next_level=needed, total_xp=total_xp)


# ─── Store ────────────────────────────────────────────────────────────────────


class GamificationStore:
    """Synchronous file-backed gamification persistence."""

    _instance: "GamificationStore | None" = None
    _instance_lock = threading.Lock()

    def __init__(self, base_dir: Path | None = None) -> None:
        if base_dir is None:
            svc = get_path_service()
            base_dir = svc.user_data_dir / "learning"
        self._base = base_dir
        self._base.mkdir(parents=True, exist_ok=True)
        self._ledger = self._base / "xp_events.jsonl"
        self._state_file = self._base / "gamification.json"
        self._notif_file = self._base / "notifications.json"
        self._mission_file = self._base / "missions_state.json"
        self._lock = threading.Lock()
        self._async_lock = asyncio.Lock()

    # ── Singleton ────────────────────────────────────────────────────────────

    @classmethod
    def get_instance(cls) -> "GamificationStore":
        with cls._instance_lock:
            if cls._instance is None:
                cls._instance = cls()
            return cls._instance

    @classmethod
    def reset_instance(cls) -> None:
        with cls._instance_lock:
            cls._instance = None

    # ── Internal IO helpers ──────────────────────────────────────────────────

    def _read_json(self, path: Path, default: Any) -> Any:
        if not path.exists():
            return default
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            logger.warning("Failed to parse %s; returning default", path)
            return default

    def _write_json(self, path: Path, data: Any) -> None:
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(tmp, path)

    def _append_ledger(self, event: XPEvent) -> None:
        with self._ledger.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(event.to_dict(), ensure_ascii=False) + "\n")

    def _load_ledger(self) -> list[XPEvent]:
        if not self._ledger.exists():
            return []
        events: list[XPEvent] = []
        with self._ledger.open("r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    raw = json.loads(line)
                    events.append(
                        XPEvent(
                            event_id=str(raw.get("event_id", "")),
                            action=str(raw.get("action", "")),
                            xp=int(raw.get("xp", 0)),
                            source=str(raw.get("source", "")),
                            timestamp=str(raw.get("timestamp", "")),
                            metadata=raw.get("metadata") or {},
                        )
                    )
                except Exception:
                    continue
        return events

    # ── State derivation ─────────────────────────────────────────────────────

    def _derive_state(self) -> dict[str, Any]:
        """Walk the ledger once and recompute streaks / totals."""

        events = self._load_ledger()
        total_xp = sum(e.xp for e in events)
        days: set[date] = set()
        per_day: dict[str, int] = {}
        per_source: dict[str, int] = {}
        for e in events:
            try:
                d = datetime.fromisoformat(e.timestamp.replace("Z", "+00:00")).date()
            except Exception:
                continue
            days.add(d)
            iso = d.isoformat()
            per_day[iso] = per_day.get(iso, 0) + e.xp
            per_source[e.source] = per_source.get(e.source, 0) + e.xp

        streak_current = self._streak_from_days(days)
        streak_max = self._max_streak_from_days(days)
        return {
            "total_xp": total_xp,
            "streak_current": streak_current,
            "streak_max": streak_max,
            "active_days": sorted(d.isoformat() for d in days),
            "xp_per_day": per_day,
            "xp_per_source": per_source,
            "event_count": len(events),
        }

    @staticmethod
    def _streak_from_days(days: set[date]) -> int:
        if not days:
            return 0
        today = datetime.now(timezone.utc).date()
        # Streak counts back from today (or yesterday — grace day so the user
        # opening at 00:05 hasn't lost the streak yet).
        anchor = today if today in days else today - timedelta(days=1)
        if anchor not in days:
            return 0
        n = 0
        cur = anchor
        while cur in days:
            n += 1
            cur -= timedelta(days=1)
        return n

    @staticmethod
    def _max_streak_from_days(days: set[date]) -> int:
        if not days:
            return 0
        sorted_days = sorted(days)
        best = 1
        current = 1
        for prev, nxt in zip(sorted_days, sorted_days[1:]):
            if (nxt - prev).days == 1:
                current += 1
                best = max(best, current)
            else:
                current = 1
        return best

    # ── Public read API ──────────────────────────────────────────────────────

    def get_state(self) -> dict[str, Any]:
        """Return the derived gamification state (recomputed fresh each call)."""

        derived = self._derive_state()
        stored = self._read_json(self._state_file, {})
        badges_unlocked = stored.get("badges_unlocked") or {}
        derived["badges_unlocked"] = badges_unlocked
        derived["mission_completions"] = stored.get("mission_completions") or {}
        derived["level"] = compute_level(derived["total_xp"]).to_dict()
        derived["last_synced_at"] = datetime.now(timezone.utc).isoformat()
        return derived

    def get_recent_xp_events(self, limit: int = 20) -> list[dict[str, Any]]:
        events = self._load_ledger()
        events.sort(key=lambda e: e.timestamp, reverse=True)
        return [e.to_dict() for e in events[: max(1, limit)]]

    def get_badges_status(self) -> list[dict[str, Any]]:
        state = self.get_state()
        unlocked: dict[str, str] = state.get("badges_unlocked") or {}
        total_xp = state.get("total_xp", 0)
        streak_current = state.get("streak_current", 0)
        streak_max = state.get("streak_max", 0)
        xp_per_source = state.get("xp_per_source") or {}
        problems_solved = int(self._count_actions("practice.correct_answer"))
        voice_sessions = int(self._count_actions("voice.session_complete"))
        results: list[dict[str, Any]] = []
        for b in DEFAULT_BADGES:
            unlocked_at = unlocked.get(b.badge_id)
            status: str
            progress: int | None = None
            progress_max: int | None = None
            if unlocked_at:
                status = "unlocked"
            else:
                progress, progress_max, status = self._badge_progress(
                    b,
                    total_xp=total_xp,
                    streak_current=streak_current,
                    streak_max=streak_max,
                    problems_solved=problems_solved,
                    voice_sessions=voice_sessions,
                    xp_per_source=xp_per_source,
                )
            results.append(
                {
                    "badge_id": b.badge_id,
                    "icon": b.icon,
                    "title": b.title,
                    "description": b.description,
                    "xp_reward": b.xp_reward,
                    "condition": b.condition,
                    "rare": b.rare,
                    "status": status,
                    "unlocked_at": unlocked_at,
                    "progress": progress,
                    "progress_max": progress_max,
                }
            )
        return results

    def _count_actions(self, action: str) -> int:
        return sum(1 for e in self._load_ledger() if e.action == action)

    @staticmethod
    def _badge_progress(
        badge: BadgeDefinition,
        *,
        total_xp: int,
        streak_current: int,
        streak_max: int,
        problems_solved: int,
        voice_sessions: int,
        xp_per_source: dict[str, int],
    ) -> tuple[int | None, int | None, str]:
        """Return (progress, progress_max, status) for a not-yet-unlocked badge."""

        def in_progress(progress: int, target: int) -> tuple[int, int, str]:
            return min(progress, target), target, "in-progress" if progress > 0 else "locked"

        bid = badge.badge_id
        if bid == "first_flame":
            return in_progress(min(1, problems_solved), 1)
        if bid == "speed_solver":
            return in_progress(min(5, problems_solved), 5)
        if bid == "sharp_mind":
            # Surfaced via gamification event "practice.perfect_quiz".
            return (None, None, "locked")
        if bid == "bookworm":
            chapters = sum(1 for e in xp_per_source.items() if e[0].startswith("book."))
            return in_progress(min(10, chapters), 10)
        if bid == "week_warrior":
            return in_progress(min(7, streak_max), 7)
        if bid == "streak_legend":
            return in_progress(min(30, streak_max), 30)
        if bid == "century_club":
            return in_progress(min(100, problems_solved), 100)
        if bid == "voice_virtuoso":
            return in_progress(min(20, voice_sessions), 20)
        if bid == "rocket_learner":
            return (None, None, "locked")
        if bid == "diamond_scholar":
            return in_progress(min(50_000, total_xp), 50_000)
        if bid == "grandmaster":
            return in_progress(min(15, compute_level(total_xp).level), 15)
        return (None, None, "locked")

    # ── Public write API ─────────────────────────────────────────────────────

    def award(
        self,
        *,
        action: str,
        xp: int,
        source: str,
        metadata: dict[str, Any] | None = None,
    ) -> XPEvent:
        if xp <= 0 or xp > 10_000:
            raise ValueError("xp must be in (0, 10000]")
        event = XPEvent(
            event_id=f"xp_{int(datetime.now(timezone.utc).timestamp() * 1000)}",
            action=action,
            xp=int(xp),
            source=source,
            timestamp=datetime.now(timezone.utc).isoformat(),
            metadata=metadata or {},
        )
        with self._lock:
            self._append_ledger(event)
        self._maybe_unlock_badges()
        return event

    def _maybe_unlock_badges(self) -> None:
        state = self._derive_state()
        stored = self._read_json(self._state_file, {})
        unlocked = dict(stored.get("badges_unlocked") or {})
        total_xp = state["total_xp"]
        streak_max = state["streak_max"]
        problems_solved = self._count_actions("practice.correct_answer")
        voice_sessions = self._count_actions("voice.session_complete")
        now = datetime.now(timezone.utc).isoformat()
        thresholds: list[tuple[str, bool]] = [
            ("first_flame", problems_solved >= 1),
            ("speed_solver", problems_solved >= 5),
            ("week_warrior", streak_max >= 7),
            ("streak_legend", streak_max >= 30),
            ("century_club", problems_solved >= 100),
            ("voice_virtuoso", voice_sessions >= 20),
            ("diamond_scholar", total_xp >= 50_000),
            ("grandmaster", compute_level(total_xp).level >= 15),
        ]
        changed = False
        for bid, predicate in thresholds:
            if predicate and bid not in unlocked:
                unlocked[bid] = now
                changed = True
        if changed:
            stored["badges_unlocked"] = unlocked
            self._write_json(self._state_file, stored)

    def unlock_badge_manual(self, badge_id: str) -> bool:
        """Idempotently mark a badge as unlocked (used by practice perfect-score etc.)."""
        if badge_id not in {b.badge_id for b in DEFAULT_BADGES}:
            raise ValueError(f"Unknown badge: {badge_id}")
        with self._lock:
            stored = self._read_json(self._state_file, {})
            unlocked = dict(stored.get("badges_unlocked") or {})
            if badge_id in unlocked:
                return False
            unlocked[badge_id] = datetime.now(timezone.utc).isoformat()
            stored["badges_unlocked"] = unlocked
            self._write_json(self._state_file, stored)
            return True

    # ── Mission state ────────────────────────────────────────────────────────

    def get_mission_completions(self) -> dict[str, str]:
        return self._read_json(self._state_file, {}).get("mission_completions") or {}

    def mark_mission_complete(self, mission_id: str) -> bool:
        with self._lock:
            stored = self._read_json(self._state_file, {})
            completions = dict(stored.get("mission_completions") or {})
            today = datetime.now(timezone.utc).date().isoformat()
            key = f"{today}::{mission_id}"
            if key in completions:
                return False
            completions[key] = datetime.now(timezone.utc).isoformat()
            stored["mission_completions"] = completions
            self._write_json(self._state_file, stored)
            return True

    def mission_completed_today(self, mission_id: str) -> bool:
        completions = self.get_mission_completions()
        today = datetime.now(timezone.utc).date().isoformat()
        return f"{today}::{mission_id}" in completions

    # ── Notifications ────────────────────────────────────────────────────────

    def list_notifications(self) -> list[dict[str, Any]]:
        data = self._read_json(self._notif_file, None)
        if data is None:
            data = []
            self._write_json(self._notif_file, data)
        return list(data)

    def add_notification(self, payload: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            data = self._read_json(self._notif_file, [])
            notif = {
                "id": payload.get("id") or f"n_{int(datetime.now(timezone.utc).timestamp() * 1000)}",
                "type": payload.get("type") or "system_update",
                "title": payload.get("title") or "Notification",
                "message": payload.get("message") or "",
                "created_at": payload.get("created_at") or datetime.now(timezone.utc).isoformat(),
                "read": bool(payload.get("read", False)),
                "is_mention": bool(payload.get("is_mention", False)),
                "is_system": bool(payload.get("is_system", False)),
                "action_label": payload.get("action_label"),
                "action_href": payload.get("action_href"),
                "metadata": payload.get("metadata") or {},
            }
            data.insert(0, notif)
            self._write_json(self._notif_file, data[:200])
            return notif

    def mark_notification_read(self, notif_id: str, *, read: bool = True) -> bool:
        with self._lock:
            data = self._read_json(self._notif_file, [])
            for entry in data:
                if entry.get("id") == notif_id:
                    if entry.get("read") == read:
                        return False
                    entry["read"] = read
                    entry["read_at"] = datetime.now(timezone.utc).isoformat() if read else None
                    self._write_json(self._notif_file, data)
                    return True
            return False

    def mark_all_notifications_read(self) -> int:
        with self._lock:
            data = self._read_json(self._notif_file, [])
            changed = 0
            now = datetime.now(timezone.utc).isoformat()
            for entry in data:
                if not entry.get("read"):
                    entry["read"] = True
                    entry["read_at"] = now
                    changed += 1
            if changed:
                self._write_json(self._notif_file, data)
            return changed

    def dismiss_notification(self, notif_id: str) -> bool:
        with self._lock:
            data = self._read_json(self._notif_file, [])
            new_data = [n for n in data if n.get("id") != notif_id]
            if len(new_data) == len(data):
                return False
            self._write_json(self._notif_file, new_data)
            return True

    # ── Async wrappers ───────────────────────────────────────────────────────

    @property
    def async_lock(self) -> asyncio.Lock:
        return self._async_lock


def get_gamification_store() -> GamificationStore:
    return GamificationStore.get_instance()


__all__ = [
    "BadgeDefinition",
    "DEFAULT_BADGES",
    "GamificationStore",
    "LevelInfo",
    "XPEvent",
    "compute_level",
    "get_gamification_store",
]
