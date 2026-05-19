"""Spaced-revision cards (SM-2–lite) backed by SQLite."""

from __future__ import annotations

from dataclasses import dataclass
import logging
from pathlib import Path
import sqlite3
import threading
import time
from typing import Any
import uuid

from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)

_lock = threading.Lock()
_store: "RevisionStore | None" = None


@dataclass
class RevisionCard:
    id: str
    topic: str
    due_at_ms: int
    ease: float
    repetitions: int
    state: str


class RevisionStore:
    def __init__(self, db_path: Path) -> None:
        self._db_path = db_path
        self._db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init()

    def _connect(self) -> sqlite3.Connection:
        c = sqlite3.connect(self._db_path, timeout=30.0, check_same_thread=False)
        c.row_factory = sqlite3.Row
        return c

    def _init(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS revision_cards (
                    id TEXT PRIMARY KEY,
                    topic TEXT NOT NULL,
                    due_at_ms INTEGER NOT NULL,
                    ease REAL NOT NULL DEFAULT 2.5,
                    repetitions INTEGER NOT NULL DEFAULT 0,
                    state TEXT NOT NULL DEFAULT 'learning',
                    created_at_ms INTEGER NOT NULL,
                    updated_at_ms INTEGER NOT NULL
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_revision_due ON revision_cards(due_at_ms)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_revision_topic ON revision_cards(topic)"
            )
            conn.commit()

    def seed_topic_if_weak(self, topic: str, *, incorrect: int) -> str | None:
        topic = (topic or "").strip().lower()
        if not topic or incorrect <= 0:
            return None
        now = int(time.time() * 1000)
        due = now + 86_400_000  # +1 day
        cid = str(uuid.uuid4())
        with self._connect() as conn:
            row = conn.execute(
                "SELECT id FROM revision_cards WHERE topic = ? AND due_at_ms > ?",
                (topic, now),
            ).fetchone()
            if row:
                return str(row["id"])
            conn.execute(
                """
                INSERT INTO revision_cards (
                    id, topic, due_at_ms, ease, repetitions, state, created_at_ms, updated_at_ms
                ) VALUES (?, ?, ?, 2.5, 0, 'learning', ?, ?)
                """,
                (cid, topic, due, now, now),
            )
            conn.commit()
        return cid

    def list_due(self, limit: int = 20) -> list[RevisionCard]:
        limit = max(1, min(limit, 100))
        now = int(time.time() * 1000)
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT id, topic, due_at_ms, ease, repetitions, state
                FROM revision_cards
                WHERE due_at_ms <= ?
                ORDER BY due_at_ms ASC
                LIMIT ?
                """,
                (now, limit),
            ).fetchall()
        return [
            RevisionCard(
                id=str(r["id"]),
                topic=str(r["topic"]),
                due_at_ms=int(r["due_at_ms"]),
                ease=float(r["ease"]),
                repetitions=int(r["repetitions"]),
                state=str(r["state"]),
            )
            for r in rows
        ]

    def review(self, card_id: str, grade: str) -> RevisionCard | None:
        grade = grade.strip().lower()
        if grade not in {"again", "good", "easy"}:
            raise ValueError("grade must be again|good|easy")
        now = int(time.time() * 1000)
        mult = {"again": 0.15, "good": 1.0, "easy": 2.5}[grade]
        with self._connect() as conn:
            row = conn.execute(
                "SELECT * FROM revision_cards WHERE id = ?", (card_id,)
            ).fetchone()
            if row is None:
                return None
            ease = max(1.3, float(row["ease"]) + (0.1 if grade == "easy" else -0.2 if grade == "again" else 0.0))
            reps = int(row["repetitions"]) + 1
            interval_ms = int(86_400_000 * mult * (1 + 0.2 * reps))
            due = now + interval_ms
            conn.execute(
                """
                UPDATE revision_cards
                SET due_at_ms = ?, ease = ?, repetitions = ?, state = 'review', updated_at_ms = ?
                WHERE id = ?
                """,
                (due, ease, reps, now, card_id),
            )
            conn.commit()
            row2 = conn.execute(
                "SELECT id, topic, due_at_ms, ease, repetitions, state FROM revision_cards WHERE id = ?",
                (card_id,),
            ).fetchone()
        if row2 is None:
            return None
        return RevisionCard(
            id=str(row2["id"]),
            topic=str(row2["topic"]),
            due_at_ms=int(row2["due_at_ms"]),
            ease=float(row2["ease"]),
            repetitions=int(row2["repetitions"]),
            state=str(row2["state"]),
        )


def _db_path() -> Path:
    ps = get_path_service()
    d = ps.user_data_dir / "learning"
    d.mkdir(parents=True, exist_ok=True)
    return d / "revision.sqlite"


def get_revision_store() -> RevisionStore:
    global _store
    path = _db_path()
    with _lock:
        if _store is None or _store._db_path.resolve() != path.resolve():
            _store = RevisionStore(path)
        return _store


def seed_from_practice_score(score: dict[str, Any]) -> list[str]:
    """Create revision cards for topics with incorrect answers."""
    per = score.get("per_topic") or {}
    created: list[str] = []
    store = get_revision_store()
    for topic, bucket in per.items():
        if not isinstance(bucket, dict):
            continue
        inc = int(bucket.get("incorrect") or 0)
        cid = store.seed_topic_if_weak(str(topic), incorrect=inc)
        if cid:
            created.append(cid)
    return created


def list_due_cards(limit: int = 20) -> list[dict[str, Any]]:
    return [
        {
            "id": c.id,
            "topic": c.topic,
            "due_at_ms": c.due_at_ms,
            "ease": c.ease,
            "repetitions": c.repetitions,
            "state": c.state,
        }
        for c in get_revision_store().list_due(limit=limit)
    ]


def review_card(card_id: str, grade: str) -> dict[str, Any] | None:
    c = get_revision_store().review(card_id, grade)
    if c is None:
        return None
    return {
        "id": c.id,
        "topic": c.topic,
        "due_at_ms": c.due_at_ms,
        "ease": c.ease,
        "repetitions": c.repetitions,
        "state": c.state,
    }


__all__ = [
    "RevisionCard",
    "RevisionStore",
    "get_revision_store",
    "list_due_cards",
    "review_card",
    "seed_from_practice_score",
]
