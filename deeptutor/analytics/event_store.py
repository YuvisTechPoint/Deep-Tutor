"""SQLite-backed append-only store for domain analytics events."""

from __future__ import annotations

import json
import logging
import sqlite3
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from uuid import uuid4

from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)

_SCHEMA_VERSION = 1

_lock = threading.Lock()
_store: "DomainEventStore | None" = None


@dataclass(frozen=True)
class DomainEventRecord:
    event_id: str
    name: str
    schema_version: int
    actor_id: str | None
    correlation_id: str | None
    subject_type: str | None
    subject_id: str | None
    payload: dict[str, Any]
    created_at_ms: int
    exported_at_ms: int | None


class DomainEventStore:
    """Single-writer SQLite queue; safe across process restarts."""

    def __init__(self, db_path: Path) -> None:
        self._db_path = db_path
        self._db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._db_path, timeout=30.0, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute("PRAGMA synchronous=NORMAL")
        return conn

    def _init_db(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS domain_events (
                    event_id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    schema_version INTEGER NOT NULL DEFAULT 1,
                    actor_id TEXT,
                    correlation_id TEXT,
                    subject_type TEXT,
                    subject_id TEXT,
                    payload_json TEXT NOT NULL,
                    created_at_ms INTEGER NOT NULL,
                    exported_at_ms INTEGER
                )
                """
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_domain_events_created "
                "ON domain_events(created_at_ms DESC)"
            )
            conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_domain_events_exported "
                "ON domain_events(exported_at_ms)"
            )
            conn.commit()

    def append(
        self,
        name: str,
        *,
        actor_id: str | None = None,
        correlation_id: str | None = None,
        subject_type: str | None = None,
        subject_id: str | None = None,
        payload: dict[str, Any] | None = None,
        event_id: str | None = None,
    ) -> str:
        eid = event_id or str(uuid4())
        now_ms = int(time.time() * 1000)
        body = dict(payload or {})
        try:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO domain_events (
                        event_id, name, schema_version, actor_id, correlation_id,
                        subject_type, subject_id, payload_json, created_at_ms, exported_at_ms
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
                    """,
                    (
                        eid,
                        name,
                        _SCHEMA_VERSION,
                        actor_id,
                        correlation_id,
                        subject_type,
                        subject_id,
                        json.dumps(body, ensure_ascii=False),
                        now_ms,
                    ),
                )
                conn.commit()
        except Exception:
            logger.exception("Failed to append domain event %s", name)
            raise
        return eid

    def list_recent(self, limit: int = 100) -> list[DomainEventRecord]:
        limit = max(1, min(limit, 500))
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT event_id, name, schema_version, actor_id, correlation_id,
                       subject_type, subject_id, payload_json, created_at_ms, exported_at_ms
                FROM domain_events
                ORDER BY created_at_ms DESC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        out: list[DomainEventRecord] = []
        for r in rows:
            try:
                payload = json.loads(r["payload_json"])
            except Exception:
                payload = {}
            out.append(
                DomainEventRecord(
                    event_id=str(r["event_id"]),
                    name=str(r["name"]),
                    schema_version=int(r["schema_version"]),
                    actor_id=r["actor_id"],
                    correlation_id=r["correlation_id"],
                    subject_type=r["subject_type"],
                    subject_id=r["subject_id"],
                    payload=payload,
                    created_at_ms=int(r["created_at_ms"]),
                    exported_at_ms=int(r["exported_at_ms"])
                    if r["exported_at_ms"] is not None
                    else None,
                )
            )
        return out

    def fetch_unexported(self, limit: int = 500) -> list[DomainEventRecord]:
        """Rows not yet copied to ClickHouse (exported_at_ms IS NULL)."""
        limit = max(1, min(limit, 2000))
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT event_id, name, schema_version, actor_id, correlation_id,
                       subject_type, subject_id, payload_json, created_at_ms, exported_at_ms
                FROM domain_events
                WHERE exported_at_ms IS NULL
                ORDER BY created_at_ms ASC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        out: list[DomainEventRecord] = []
        for r in rows:
            try:
                payload = json.loads(r["payload_json"])
            except Exception:
                payload = {}
            out.append(
                DomainEventRecord(
                    event_id=str(r["event_id"]),
                    name=str(r["name"]),
                    schema_version=int(r["schema_version"]),
                    actor_id=r["actor_id"],
                    correlation_id=r["correlation_id"],
                    subject_type=r["subject_type"],
                    subject_id=r["subject_id"],
                    payload=payload,
                    created_at_ms=int(r["created_at_ms"]),
                    exported_at_ms=None,
                )
            )
        return out

    def mark_exported(self, event_ids: list[str], exported_at_ms: int | None = None) -> int:
        if not event_ids:
            return 0
        ts = exported_at_ms if exported_at_ms is not None else int(time.time() * 1000)
        n = 0
        with self._connect() as conn:
            for eid in event_ids:
                cur = conn.execute(
                    "UPDATE domain_events SET exported_at_ms = ? WHERE event_id = ?",
                    (ts, eid),
                )
                n += cur.rowcount or 0
            conn.commit()
        return n


def _db_path() -> Path:
    ps = get_path_service()
    d = ps.user_data_dir / "learning"
    d.mkdir(parents=True, exist_ok=True)
    return d / "domain_events.sqlite"


def get_domain_event_store() -> DomainEventStore:
    global _store
    with _lock:
        if _store is None:
            _store = DomainEventStore(_db_path())
        return _store


__all__ = ["DomainEventRecord", "DomainEventStore", "get_domain_event_store"]
