"""Progressive login lockout for local JWT auth (not PocketBase)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
import json
import logging
import os
from pathlib import Path
import threading
from typing import Any

from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)

_LOCK = threading.Lock()
_USER_ATTEMPT_LOCKS: dict[str, threading.Lock] = {}
_USER_ATTEMPT_GUARD = threading.Lock()

AUTH_LOCKOUT_ENABLED: bool = os.getenv("AUTH_LOCKOUT_ENABLED", "true").strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}
AUTH_LOCKOUT_FAILURES_BEFORE_LOCK: int = max(3, int(os.getenv("AUTH_LOCKOUT_FAILURES_BEFORE_LOCK", "8")))
AUTH_LOCKOUT_INITIAL_MINUTES: int = max(1, int(os.getenv("AUTH_LOCKOUT_INITIAL_MINUTES", "5")))
AUTH_LOCKOUT_MAX_MINUTES: int = max(
    AUTH_LOCKOUT_INITIAL_MINUTES,
    int(os.getenv("AUTH_LOCKOUT_MAX_MINUTES", "1440")),
)


def _lockout_path() -> Path:
    ps = get_path_service()
    d = ps.user_data_dir / "auth"
    d.mkdir(parents=True, exist_ok=True)
    return d / "login_lockout.json"


def _load() -> dict[str, Any]:
    p = _lockout_path()
    if not p.exists():
        return {}
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except Exception:
        logger.warning("Could not read login lockout store")
        return {}


def _save(data: dict[str, Any]) -> None:
    _lockout_path().write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def normalize_login_key(username: str) -> str:
    return (username or "").strip().lower()


def user_login_attempt_lock(username: str) -> threading.Lock:
    """Serialize password login attempts for one account (prevents lockout races)."""
    key = normalize_login_key(username)
    with _USER_ATTEMPT_GUARD:
        lock = _USER_ATTEMPT_LOCKS.get(key)
        if lock is None:
            lock = threading.Lock()
            _USER_ATTEMPT_LOCKS[key] = lock
        return lock


def is_locked(username: str) -> tuple[bool, str | None]:
    """
    Return (locked, iso_unlock_time) if the account key is under an active lock.
    Expired locks are cleared lazily.
    """
    if not AUTH_LOCKOUT_ENABLED:
        return False, None
    key = normalize_login_key(username)
    if not key:
        return False, None
    with _LOCK:
        data = _load()
        entry = data.get(key)
        if not isinstance(entry, dict):
            return False, None
        until_raw = entry.get("locked_until")
        if not until_raw:
            return False, None
        try:
            until = datetime.fromisoformat(str(until_raw))
            if until.tzinfo is None:
                until = until.replace(tzinfo=timezone.utc)
        except Exception:
            entry.pop("locked_until", None)
            data[key] = entry
            _save(data)
            return False, None
        now = datetime.now(timezone.utc)
        if until > now:
            return True, until.isoformat()
        entry.pop("locked_until", None)
        entry["failures"] = 0
        data[key] = entry
        _save(data)
    return False, None


def record_failed_attempt(username: str) -> None:
    """Increment failures; apply progressive lock when threshold is reached."""
    if not AUTH_LOCKOUT_ENABLED:
        return
    key = normalize_login_key(username)
    if not key:
        return
    now = datetime.now(timezone.utc)
    with _LOCK:
        data = _load()
        entry: dict[str, Any] = dict(data.get(key) or {})
        failures = int(entry.get("failures") or 0) + 1
        entry["failures"] = failures
        wave = int(entry.get("wave") or 0)
        if failures >= AUTH_LOCKOUT_FAILURES_BEFORE_LOCK:
            wave += 1
            minutes = min(
                AUTH_LOCKOUT_MAX_MINUTES,
                AUTH_LOCKOUT_INITIAL_MINUTES * (2 ** min(wave - 1, 8)),
            )
            entry["locked_until"] = (now + timedelta(minutes=minutes)).isoformat()
            entry["failures"] = 0
            entry["wave"] = wave
            logger.info(
                "Login lockout applied for %r: wave=%s lock_minutes=%s",
                key,
                wave,
                minutes,
            )
        data[key] = entry
        _save(data)


def clear_failed_attempts(username: str) -> None:
    """Clear lockout state after a successful login."""
    if not AUTH_LOCKOUT_ENABLED:
        return
    key = normalize_login_key(username)
    if not key:
        return
    with _LOCK:
        data = _load()
        if key in data:
            data.pop(key, None)
            _save(data)
