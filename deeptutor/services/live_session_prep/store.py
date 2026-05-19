"""SQLite persistence for session drafts and pre-session requests."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import json
import logging
import os
from pathlib import Path
import sqlite3
import threading
from typing import Any, Literal
import uuid

from deeptutor.multi_user.paths import SYSTEM_ROOT, ensure_system_dirs

logger = logging.getLogger(__name__)

DraftStatus = Literal["draft", "ready", "submitted"]
MentorStatus = Literal["open", "reviewed", "planned", "answered", "deferred"]
IntentType = Literal[
    "doubt",
    "concept_clarification",
    "code_review",
    "career_advice",
    "project_help",
    "other",
]
Priority = Literal["high", "medium", "low"]


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _new_id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:16]}"


def _parse_iso(s: str | None) -> datetime | None:
    if not s or not str(s).strip():
        return None
    txt = str(s).strip().replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(txt)
    except ValueError:
        return None


def is_past_session_start(live_session_starts_at: str | None) -> bool:
    dt = _parse_iso(live_session_starts_at)
    if dt is None:
        return False
    now = datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return now >= dt


def default_db_path() -> Path:
    ensure_system_dirs()
    override = os.getenv("LIVE_SESSION_PREP_DB", "").strip()
    if override:
        return Path(override).expanduser().resolve()
    return (SYSTEM_ROOT / "live_session_prep.sqlite").resolve()


@dataclass(frozen=True, slots=True)
class DraftRow:
    id: str
    user_id: str
    session_id: str
    topic: str
    goals: list[str]
    questions: list[str]
    notes: str
    attachments: list[dict[str, Any]]
    status: str
    created_at: str
    updated_at: str


@dataclass(frozen=True, slots=True)
class RequestRow:
    id: str
    user_id: str
    session_id: str
    draft_id: str | None
    title: str
    description: str
    intent_type: str
    priority: str
    anonymous: bool
    mentor_status: str
    queue_position: int
    attachments: list[dict[str, Any]]
    live_session_starts_at: str | None
    student_username: str
    created_at: str
    updated_at: str


class LiveSessionPrepStore:
    """Thread-safe SQLite access."""

    _global: LiveSessionPrepStore | None = None
    _global_lock = threading.Lock()

    def __init__(self, db_path: Path | None = None) -> None:
        self._db_path = db_path or default_db_path()
        self._db_path.parent.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()
        self._ensure_schema()

    @classmethod
    def get_instance(cls) -> LiveSessionPrepStore:
        with cls._global_lock:
            if cls._global is None:
                cls._global = cls()
            return cls._global

    @classmethod
    def reset_instance(cls) -> None:
        with cls._global_lock:
            cls._global = None

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self._db_path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def _ensure_schema(self) -> None:
        with self._lock:
            with self._connect() as conn:
                conn.executescript(
                    """
                    CREATE TABLE IF NOT EXISTS session_drafts (
                        id TEXT PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        session_id TEXT NOT NULL,
                        topic TEXT NOT NULL,
                        goals_json TEXT NOT NULL DEFAULT '[]',
                        questions_json TEXT NOT NULL DEFAULT '[]',
                        notes TEXT NOT NULL DEFAULT '',
                        attachments_json TEXT NOT NULL DEFAULT '[]',
                        status TEXT NOT NULL DEFAULT 'draft',
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL
                    );
                    CREATE INDEX IF NOT EXISTS idx_session_drafts_user_session
                        ON session_drafts(user_id, session_id, updated_at DESC);
                    CREATE INDEX IF NOT EXISTS idx_session_drafts_session
                        ON session_drafts(session_id);

                    CREATE TABLE IF NOT EXISTS pre_session_requests (
                        id TEXT PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        session_id TEXT NOT NULL,
                        draft_id TEXT,
                        title TEXT NOT NULL,
                        description TEXT NOT NULL,
                        intent_type TEXT NOT NULL,
                        priority TEXT NOT NULL,
                        anonymous INTEGER NOT NULL DEFAULT 0,
                        mentor_status TEXT NOT NULL DEFAULT 'open',
                        queue_position INTEGER NOT NULL DEFAULT 0,
                        attachments_json TEXT NOT NULL DEFAULT '[]',
                        live_session_starts_at TEXT,
                        student_username TEXT NOT NULL DEFAULT '',
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL,
                        FOREIGN KEY (draft_id) REFERENCES session_drafts(id) ON DELETE SET NULL
                    );
                    CREATE INDEX IF NOT EXISTS idx_psr_session_queue
                        ON pre_session_requests(session_id, queue_position);
                    CREATE INDEX IF NOT EXISTS idx_psr_session_created
                        ON pre_session_requests(session_id, created_at DESC);
                    CREATE INDEX IF NOT EXISTS idx_psr_user_session
                        ON pre_session_requests(user_id, session_id);
                    """
                )

    # --- drafts -----------------------------------------------------------------

    def list_drafts(self, *, user_id: str, session_id: str | None = None) -> list[DraftRow]:
        q = "SELECT * FROM session_drafts WHERE user_id = ?"
        args: list[Any] = [user_id]
        if session_id is not None:
            q += " AND session_id = ?"
            args.append(session_id)
        q += " ORDER BY updated_at DESC"
        with self._lock:
            with self._connect() as conn:
                rows = conn.execute(q, args).fetchall()
        return [self._row_to_draft(r) for r in rows]

    def get_draft(self, draft_id: str) -> DraftRow | None:
        with self._lock:
            with self._connect() as conn:
                row = conn.execute(
                    "SELECT * FROM session_drafts WHERE id = ?", (draft_id,)
                ).fetchone()
        return self._row_to_draft(row) if row else None

    def create_draft(
        self,
        *,
        user_id: str,
        session_id: str,
        topic: str,
        goals: list[str],
        questions: list[str],
        notes: str,
        attachments: list[dict[str, Any]],
        status: str = "draft",
    ) -> DraftRow:
        now = _utc_now()
        did = _new_id("sd")
        goals_j = json.dumps(goals, ensure_ascii=False)
        questions_j = json.dumps(questions, ensure_ascii=False)
        att_j = json.dumps(attachments, ensure_ascii=False)
        with self._lock:
            with self._connect() as conn:
                conn.execute(
                    """
                    INSERT INTO session_drafts (
                        id, user_id, session_id, topic, goals_json, questions_json,
                        notes, attachments_json, status, created_at, updated_at
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        did,
                        user_id,
                        session_id,
                        topic,
                        goals_j,
                        questions_j,
                        notes,
                        att_j,
                        status,
                        now,
                        now,
                    ),
                )
        return self.get_draft(did)  # type: ignore[return-value]

    def update_draft(
        self,
        draft_id: str,
        *,
        user_id: str,
        topic: str | None = None,
        goals: list[str] | None = None,
        questions: list[str] | None = None,
        notes: str | None = None,
        attachments: list[dict[str, Any]] | None = None,
        status: str | None = None,
    ) -> DraftRow | None:
        existing = self.get_draft(draft_id)
        if existing is None or existing.user_id != user_id:
            return None
        if existing.status == "submitted":
            return None
        now = _utc_now()
        fields: list[str] = []
        args: list[Any] = []
        if topic is not None:
            fields.append("topic = ?")
            args.append(topic)
        if goals is not None:
            fields.append("goals_json = ?")
            args.append(json.dumps(goals, ensure_ascii=False))
        if questions is not None:
            fields.append("questions_json = ?")
            args.append(json.dumps(questions, ensure_ascii=False))
        if notes is not None:
            fields.append("notes = ?")
            args.append(notes)
        if attachments is not None:
            fields.append("attachments_json = ?")
            args.append(json.dumps(attachments, ensure_ascii=False))
        if status is not None:
            fields.append("status = ?")
            args.append(status)
        if not fields:
            return existing
        fields.append("updated_at = ?")
        args.append(now)
        args.append(draft_id)
        args.append(user_id)
        q = f"UPDATE session_drafts SET {', '.join(fields)} WHERE id = ? AND user_id = ?"
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute(q, args)
                if cur.rowcount == 0:
                    return None
        return self.get_draft(draft_id)

    def delete_draft(self, draft_id: str, *, user_id: str) -> bool:
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute(
                    "DELETE FROM session_drafts WHERE id = ? AND user_id = ?",
                    (draft_id, user_id),
                )
                return cur.rowcount > 0

    def _row_to_draft(self, row: sqlite3.Row) -> DraftRow:
        goals = json.loads(row["goals_json"] or "[]")
        questions = json.loads(row["questions_json"] or "[]")
        attachments = json.loads(row["attachments_json"] or "[]")
        return DraftRow(
            id=str(row["id"]),
            user_id=str(row["user_id"]),
            session_id=str(row["session_id"]),
            topic=str(row["topic"]),
            goals=goals if isinstance(goals, list) else [],
            questions=questions if isinstance(questions, list) else [],
            notes=str(row["notes"] or ""),
            attachments=attachments if isinstance(attachments, list) else [],
            status=str(row["status"] or "draft"),
            created_at=str(row["created_at"]),
            updated_at=str(row["updated_at"]),
        )

    # --- pre-session requests ---------------------------------------------------

    def _next_queue_position(self, conn: sqlite3.Connection, session_id: str) -> int:
        row = conn.execute(
            "SELECT COALESCE(MAX(queue_position), -1) + 1 AS n FROM pre_session_requests WHERE session_id = ?",
            (session_id,),
        ).fetchone()
        return int(row["n"]) if row else 0

    def create_request(
        self,
        *,
        user_id: str,
        session_id: str,
        draft_id: str | None,
        title: str,
        description: str,
        intent_type: str,
        priority: str,
        anonymous: bool,
        attachments: list[dict[str, Any]],
        live_session_starts_at: str | None,
        student_username: str,
    ) -> RequestRow | None:
        if draft_id:
            d = self.get_draft(draft_id)
            if d is None or d.user_id != user_id:
                return None
        now = _utc_now()
        rid = _new_id("psr")
        att_j = json.dumps(attachments, ensure_ascii=False)
        with self._lock:
            with self._connect() as conn:
                pos = self._next_queue_position(conn, session_id)
                conn.execute(
                    """
                    INSERT INTO pre_session_requests (
                        id, user_id, session_id, draft_id, title, description,
                        intent_type, priority, anonymous, mentor_status, queue_position,
                        attachments_json, live_session_starts_at, student_username,
                        created_at, updated_at
                    ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    (
                        rid,
                        user_id,
                        session_id,
                        draft_id,
                        title,
                        description,
                        intent_type,
                        priority,
                        1 if anonymous else 0,
                        "open",
                        pos,
                        att_j,
                        live_session_starts_at,
                        student_username,
                        now,
                        now,
                    ),
                )
        return self.get_request(rid)

    def get_request(self, request_id: str) -> RequestRow | None:
        with self._lock:
            with self._connect() as conn:
                row = conn.execute(
                    "SELECT * FROM pre_session_requests WHERE id = ?", (request_id,)
                ).fetchone()
        return self._row_to_request(row) if row else None

    def _row_to_request(self, row: sqlite3.Row) -> RequestRow:
        att = json.loads(row["attachments_json"] or "[]")
        return RequestRow(
            id=str(row["id"]),
            user_id=str(row["user_id"]),
            session_id=str(row["session_id"]),
            draft_id=str(row["draft_id"]) if row["draft_id"] else None,
            title=str(row["title"]),
            description=str(row["description"]),
            intent_type=str(row["intent_type"]),
            priority=str(row["priority"]),
            anonymous=bool(row["anonymous"]),
            mentor_status=str(row["mentor_status"] or "open"),
            queue_position=int(row["queue_position"] or 0),
            attachments=att if isinstance(att, list) else [],
            live_session_starts_at=str(row["live_session_starts_at"])
            if row["live_session_starts_at"]
            else None,
            student_username=str(row["student_username"] or ""),
            created_at=str(row["created_at"]),
            updated_at=str(row["updated_at"]),
        )

    def update_request_student(
        self,
        request_id: str,
        *,
        user_id: str,
        title: str | None = None,
        description: str | None = None,
        intent_type: str | None = None,
        priority: str | None = None,
        anonymous: bool | None = None,
        draft_id: str | None = None,
        update_draft_id: bool = False,
        attachments: list[dict[str, Any]] | None = None,
        live_session_starts_at: str | None = None,
    ) -> RequestRow | None:
        existing = self.get_request(request_id)
        if existing is None or existing.user_id != user_id:
            return None
        if is_past_session_start(existing.live_session_starts_at):
            return None
        now = _utc_now()
        fields: list[str] = []
        args: list[Any] = []
        if title is not None:
            fields.append("title = ?")
            args.append(title)
        if description is not None:
            fields.append("description = ?")
            args.append(description)
        if intent_type is not None:
            fields.append("intent_type = ?")
            args.append(intent_type)
        if priority is not None:
            fields.append("priority = ?")
            args.append(priority)
        if anonymous is not None:
            fields.append("anonymous = ?")
            args.append(1 if anonymous else 0)
        if update_draft_id:
            if not draft_id:
                fields.append("draft_id = NULL")
            else:
                d = self.get_draft(draft_id)
                if d is None or d.user_id != user_id:
                    return None
                fields.append("draft_id = ?")
                args.append(draft_id)
        if attachments is not None:
            fields.append("attachments_json = ?")
            args.append(json.dumps(attachments, ensure_ascii=False))
        if live_session_starts_at is not None:
            fields.append("live_session_starts_at = ?")
            args.append(live_session_starts_at)
        if not fields:
            return existing
        fields.append("updated_at = ?")
        args.append(now)
        args.extend([request_id, user_id])
        q = f"UPDATE pre_session_requests SET {', '.join(fields)} WHERE id = ? AND user_id = ?"
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute(q, args)
                if cur.rowcount == 0:
                    return None
        return self.get_request(request_id)

    def update_request_mentor(
        self,
        request_id: str,
        *,
        mentor_status: str,
    ) -> RequestRow | None:
        now = _utc_now()
        with self._lock:
            with self._connect() as conn:
                cur = conn.execute(
                    """
                    UPDATE pre_session_requests
                    SET mentor_status = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    (mentor_status, now, request_id),
                )
                if cur.rowcount == 0:
                    return None
        return self.get_request(request_id)

    def list_requests_for_student(self, *, user_id: str, session_id: str | None = None) -> list[RequestRow]:
        q = "SELECT * FROM pre_session_requests WHERE user_id = ?"
        args: list[Any] = [user_id]
        if session_id is not None:
            q += " AND session_id = ?"
            args.append(session_id)
        q += " ORDER BY queue_position ASC, created_at ASC"
        with self._lock:
            with self._connect() as conn:
                rows = conn.execute(q, args).fetchall()
        return [self._row_to_request(r) for r in rows]

    def list_requests_mentor(
        self,
        *,
        session_id: str | None = None,
        priority: str | None = None,
        intent_type: str | None = None,
        search: str | None = None,
    ) -> list[RequestRow]:
        clauses: list[str] = []
        args: list[Any] = []
        if session_id:
            clauses.append("session_id = ?")
            args.append(session_id)
        if priority:
            clauses.append("priority = ?")
            args.append(priority)
        if intent_type:
            clauses.append("intent_type = ?")
            args.append(intent_type)
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        q = f"SELECT * FROM pre_session_requests {where} ORDER BY queue_position ASC, created_at ASC"
        with self._lock:
            with self._connect() as conn:
                rows = conn.execute(q, args).fetchall()
        out = [self._row_to_request(r) for r in rows]
        if search and search.strip():
            needle = search.strip().lower()
            out = [
                r
                for r in out
                if needle in r.title.lower()
                or needle in r.description.lower()
                or needle in r.student_username.lower()
                or needle in r.user_id.lower()
            ]
        return out

    def reorder_requests(self, *, session_id: str, ordered_ids: list[str]) -> bool:
        if not ordered_ids:
            return True
        now = _utc_now()
        with self._lock:
            with self._connect() as conn:
                existing = conn.execute(
                    "SELECT id FROM pre_session_requests WHERE session_id = ?",
                    (session_id,),
                ).fetchall()
                eids = {str(r["id"]) for r in existing}
                if set(ordered_ids) != eids:
                    return False
                for pos, rid in enumerate(ordered_ids):
                    conn.execute(
                        """
                        UPDATE pre_session_requests
                        SET queue_position = ?, updated_at = ?
                        WHERE id = ? AND session_id = ?
                        """,
                        (pos, now, rid, session_id),
                    )
        return True


def get_live_session_prep_store() -> LiveSessionPrepStore:
    return LiveSessionPrepStore.get_instance()
