"""Ephemeral, process-local cache for live quizzes.

The practice center generates every quiz on the fly via the LLM and **never**
persists questions to disk. This module is the only place where the freshly
generated questions live between the ``GET /practice/questions`` call (which
serves the questions stripped of their answer keys) and the ``POST
/practice/submit`` call (which needs the answer keys to score).

Design choices:

* Pure in-memory dict, never written to disk. Restarting the backend wipes the
  cache — there is no persistent question bank.
* TTL: 30 minutes per quiz (long enough to finish a quiz, short enough that
  abandoned quizzes don't sit around).
* Max size: 256 active quizzes. When full, the oldest entry is evicted (LRU
  via insertion order — `dict` in Python 3.7+ preserves insertion order).
* Thread-safe via a single module-level lock.
"""

from __future__ import annotations

from dataclasses import dataclass
import logging
import threading
import time
from typing import TYPE_CHECKING
import uuid

if TYPE_CHECKING:
    from deeptutor.services.practice.bank import Question

logger = logging.getLogger(__name__)

_TTL_SECONDS: float = 30 * 60  # 30 minutes
_MAX_QUIZZES: int = 256


@dataclass
class _CacheEntry:
    questions: list["Question"]
    created_at: float
    topic: str
    difficulty: str
    hints: dict[str, str]


_quizzes: dict[str, _CacheEntry] = {}
_lock = threading.Lock()


def _evict_expired_locked(now: float) -> None:
    """Drop entries older than the TTL. Caller must hold ``_lock``."""
    stale = [qid for qid, entry in _quizzes.items() if now - entry.created_at > _TTL_SECONDS]
    for qid in stale:
        _quizzes.pop(qid, None)


def store_quiz(
    questions: list["Question"],
    *,
    topic: str,
    difficulty: str,
) -> str:
    """Cache a freshly generated quiz and return its opaque id."""
    quiz_id = f"quiz_{uuid.uuid4().hex}"
    now = time.time()
    with _lock:
        _evict_expired_locked(now)
        # LRU-style eviction once we exceed MAX.
        while len(_quizzes) >= _MAX_QUIZZES:
            oldest = next(iter(_quizzes))
            _quizzes.pop(oldest, None)
        _quizzes[quiz_id] = _CacheEntry(
            questions=list(questions),
            created_at=now,
            topic=topic,
            difficulty=difficulty,
            hints={},
        )
    logger.debug("Cached quiz %s (topic=%s, difficulty=%s, n=%d)",
                 quiz_id, topic, difficulty, len(questions))
    return quiz_id


def get_quiz(quiz_id: str) -> list["Question"] | None:
    """Return the cached question list for a quiz id, or None if expired/unknown."""
    if not quiz_id:
        return None
    now = time.time()
    with _lock:
        _evict_expired_locked(now)
        entry = _quizzes.get(quiz_id)
        if entry is None:
            return None
        return entry.questions


def get_cached_hint(quiz_id: str, question_id: str) -> str | None:
    """Return a previously generated hint for this question, if any."""
    if not quiz_id or not question_id:
        return None
    now = time.time()
    with _lock:
        _evict_expired_locked(now)
        entry = _quizzes.get(quiz_id)
        if entry is None:
            return None
        return entry.hints.get(question_id)


def store_hint(quiz_id: str, question_id: str, hint: str) -> bool:
    """Cache a hint on the quiz entry. Returns False if quiz is unknown/expired."""
    text = (hint or "").strip()
    if not quiz_id or not question_id or not text:
        return False
    now = time.time()
    with _lock:
        _evict_expired_locked(now)
        entry = _quizzes.get(quiz_id)
        if entry is None:
            return False
        entry.hints[question_id] = text[:500]
        return True


def drop_quiz(quiz_id: str) -> bool:
    """Forget a cached quiz (called from ``submit`` once scoring is done)."""
    with _lock:
        return _quizzes.pop(quiz_id, None) is not None


def cache_stats() -> dict:
    """Diagnostic snapshot of the cache (used by ``/api/v1/system`` if needed)."""
    with _lock:
        return {
            "active_quizzes": len(_quizzes),
            "max_quizzes": _MAX_QUIZZES,
            "ttl_seconds": int(_TTL_SECONDS),
        }


__all__ = [
    "cache_stats",
    "drop_quiz",
    "get_cached_hint",
    "get_quiz",
    "store_hint",
    "store_quiz",
]
