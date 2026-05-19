"""Code lab exam proctoring — fullscreen lock, violations, blacklist."""

from __future__ import annotations

from dataclasses import dataclass
import json
import logging
import os
from pathlib import Path
import threading
import time
from typing import Any, Literal
import uuid

from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)

ViolationReason = Literal[
    "tab_hidden",
    "fullscreen_exit",
    "window_blur",
    "navigation_attempt",
    "copy_attempt",
    "paste_attempt",
    "context_menu",
    "devtools_hotkey",
    "selection_blocked",
]

BLACKLIST_CONSECUTIVE_THRESHOLD = 3
_STATE_FILE = "coding_exam_guard.json"


@dataclass(frozen=True)
class ExamStatus:
    blacklisted: bool
    consecutive_violations: int
    violations_until_blacklist: int
    active: bool
    session_id: str | None
    warning_message: str | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "blacklisted": self.blacklisted,
            "consecutive_violations": self.consecutive_violations,
            "violations_until_blacklist": self.violations_until_blacklist,
            "active": self.active,
            "session_id": self.session_id,
            "warning_message": self.warning_message,
        }


class CodingExamGuardStore:
    """Per-user JSON persistence for code-lab exam integrity."""

    _instance: CodingExamGuardStore | None = None
    _lock = threading.Lock()

    def __init__(self, base_dir: Path | None = None) -> None:
        if base_dir is None:
            base_dir = get_path_service().user_data_dir / "learning"
        self._base = base_dir
        self._base.mkdir(parents=True, exist_ok=True)
        self._path = self._base / _STATE_FILE
        self._io_lock = threading.Lock()

    @classmethod
    def get_instance(cls) -> CodingExamGuardStore:
        with cls._lock:
            if cls._instance is None:
                cls._instance = cls()
            return cls._instance

    @classmethod
    def reset_instance(cls) -> None:
        with cls._lock:
            cls._instance = None

    def _default_state(self) -> dict[str, Any]:
        return {
            "blacklisted": False,
            "blacklisted_at": None,
            "consecutive_violations": 0,
            "total_violations": 0,
            "active_session": None,
            "recent_violations": [],
        }

    def _load(self) -> dict[str, Any]:
        if not self._path.exists():
            return self._default_state()
        try:
            raw = json.loads(self._path.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                return {**self._default_state(), **raw}
        except Exception:
            logger.warning("Failed to parse %s", self._path)
        return self._default_state()

    def _save(self, data: dict[str, Any]) -> None:
        tmp = self._path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(tmp, self._path)

    def _status_from_state(self, st: dict[str, Any]) -> ExamStatus:
        active = st.get("active_session")
        session_id = active.get("session_id") if isinstance(active, dict) else None
        consecutive = int(st.get("consecutive_violations") or 0)
        blacklisted = bool(st.get("blacklisted"))
        remaining = max(0, BLACKLIST_CONSECUTIVE_THRESHOLD - consecutive)
        warning = None
        if blacklisted:
            warning = (
                "You have been blacklisted from Code lab after repeated exam integrity "
                "violations. Contact an administrator to restore access."
            )
        elif consecutive > 0:
            warning = (
                f"Exam integrity warning: {consecutive} consecutive violation(s). "
                f"{remaining} more may result in a blacklist."
            )
        return ExamStatus(
            blacklisted=blacklisted,
            consecutive_violations=consecutive,
            violations_until_blacklist=remaining,
            active=bool(session_id),
            session_id=session_id,
            warning_message=warning,
        )

    def get_status(self) -> ExamStatus:
        with self._io_lock:
            st = self._load()
        return self._status_from_state(st)

    def assert_not_blacklisted(self) -> None:
        if self.get_status().blacklisted:
            raise PermissionError("blacklisted")

    def start_session(self, *, problem_id: str | None = None) -> dict[str, Any]:
        self.assert_not_blacklisted()
        with self._io_lock:
            st = self._load()
            if st.get("blacklisted"):
                raise PermissionError("blacklisted")
            active = st.get("active_session")
            if isinstance(active, dict) and active.get("session_id"):
                session_id = str(active["session_id"])
                if problem_id is not None:
                    active["problem_id"] = problem_id
                    st["active_session"] = active
                    self._save(st)
            else:
                session_id = f"exam_{uuid.uuid4().hex[:16]}"
                st["active_session"] = {
                    "session_id": session_id,
                    "started_at": time.time(),
                    "problem_id": problem_id,
                }
                self._save(st)
        status = self.get_status()
        return {"session_id": session_id, **status.to_dict()}

    def _append_violation_log(
        self,
        st: dict[str, Any],
        *,
        reason: str,
        session_id: str,
    ) -> None:
        log = st.setdefault("recent_violations", [])
        if not isinstance(log, list):
            log = []
            st["recent_violations"] = log
        log.append(
            {
                "at": time.time(),
                "reason": reason,
                "session_id": session_id,
            }
        )
        st["recent_violations"] = log[-50:]

    def record_violation(
        self,
        session_id: str,
        reason: ViolationReason,
    ) -> dict[str, Any]:
        with self._io_lock:
            st = self._load()
            if st.get("blacklisted"):
                return {**self._status_from_state(st).to_dict(), "blacklisted": True, "new_violation": False}

            active = st.get("active_session")
            if not isinstance(active, dict) or active.get("session_id") != session_id:
                raise ValueError("unknown_or_inactive_session")

            # Dedupe identical reasons within 3s (client may double-fire events).
            recent = st.get("recent_violations") or []
            now = time.time()
            if isinstance(recent, list) and recent:
                last = recent[-1]
                if (
                    isinstance(last, dict)
                    and last.get("reason") == reason
                    and last.get("session_id") == session_id
                    and now - float(last.get("at") or 0) < 3.0
                ):
                    return {**self._status_from_state(st).to_dict(), "new_violation": False}

            consecutive = int(st.get("consecutive_violations") or 0) + 1
            st["consecutive_violations"] = consecutive
            st["total_violations"] = int(st.get("total_violations") or 0) + 1
            self._append_violation_log(st, reason=reason, session_id=session_id)

            blacklisted_now = consecutive >= BLACKLIST_CONSECUTIVE_THRESHOLD
            if blacklisted_now:
                st["blacklisted"] = True
                st["blacklisted_at"] = now

            self._save(st)
            status = self._status_from_state(st)

        return {
            **status.to_dict(),
            "new_violation": True,
            "reason": reason,
            "just_blacklisted": blacklisted_now,
        }

    def end_session(self, session_id: str, *, submitted: bool) -> dict[str, Any]:
        with self._io_lock:
            st = self._load()
            active = st.get("active_session")
            if isinstance(active, dict) and active.get("session_id") == session_id:
                st["active_session"] = None
            if submitted:
                st["consecutive_violations"] = 0
            self._save(st)
        return self.get_status().to_dict()

    def clear_blacklist_for_testing(self) -> dict[str, Any]:
        """Reset blacklist and violation counters (local / dev testing only)."""
        with self._io_lock:
            st = self._load()
            st["blacklisted"] = False
            st["blacklisted_at"] = None
            st["consecutive_violations"] = 0
            st["active_session"] = None
            self._save(st)
        return self.get_status().to_dict()


def code_lab_dev_bypass_enabled() -> bool:
    """Whether ``POST /exam/dev/clear-blacklist`` is allowed."""
    raw = os.environ.get("DEEPTUTOR_CODE_LAB_DEV_BYPASS", "").strip().lower()
    if raw in ("1", "true", "yes", "on"):
        return True
    if raw in ("0", "false", "no", "off"):
        return False
    env = (
        os.environ.get("ENVIRONMENT", "")
        or os.environ.get("DEEPTUTOR_ENV", "")
        or os.environ.get("NODE_ENV", "")
    ).lower()
    return env not in ("production", "prod")


def get_exam_guard_store() -> CodingExamGuardStore:
    return CodingExamGuardStore.get_instance()


__all__ = [
    "BLACKLIST_CONSECUTIVE_THRESHOLD",
    "CodingExamGuardStore",
    "ExamStatus",
    "ViolationReason",
    "code_lab_dev_bypass_enabled",
    "get_exam_guard_store",
]
