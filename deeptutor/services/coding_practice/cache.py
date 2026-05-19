"""Ephemeral cache for LLM-generated coding problems (same lifecycle as practice quizzes)."""

from __future__ import annotations

from dataclasses import dataclass
import logging
import threading
import time
import uuid

logger = logging.getLogger(__name__)

_TTL_SECONDS: float = 30 * 60
_MAX: int = 256


@dataclass
class CodingProblemEntry:
    problem_id: str
    title: str
    description: str
    starter_code: str
    entrypoint: str
    tests: list[dict]
    hints: list[str]
    topic: str
    difficulty: str
    created_at: float
    language: str = "python"
    offline: bool = False


_problems: dict[str, CodingProblemEntry] = {}
_lock = threading.Lock()


def _evict(now: float) -> None:
    stale = [k for k, v in _problems.items() if now - v.created_at > _TTL_SECONDS]
    for k in stale:
        _problems.pop(k, None)


def store_problem(entry: CodingProblemEntry) -> str:
    pid = entry.problem_id or f"cp_{uuid.uuid4().hex}"
    now = time.time()
    entry = CodingProblemEntry(
        problem_id=pid,
        title=entry.title,
        description=entry.description,
        starter_code=entry.starter_code,
        entrypoint=entry.entrypoint,
        tests=list(entry.tests),
        hints=list(entry.hints),
        topic=entry.topic,
        difficulty=entry.difficulty,
        created_at=now,
        language=(entry.language or "python").strip().lower() or "python",
        offline=bool(entry.offline),
    )
    with _lock:
        _evict(now)
        while len(_problems) >= _MAX:
            oldest = next(iter(_problems))
            _problems.pop(oldest, None)
        _problems[pid] = entry
    logger.debug("Cached coding problem %s topic=%s", pid, entry.topic)
    return pid


def get_problem(problem_id: str) -> CodingProblemEntry | None:
    if not problem_id:
        return None
    now = time.time()
    with _lock:
        _evict(now)
        return _problems.get(problem_id)


def drop_problem(problem_id: str) -> bool:
    with _lock:
        return _problems.pop(problem_id, None) is not None


__all__ = ["CodingProblemEntry", "drop_problem", "get_problem", "store_problem"]
