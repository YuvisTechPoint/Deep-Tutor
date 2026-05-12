"""Tests for durable domain event SQLite store."""

from __future__ import annotations

from pathlib import Path

from deeptutor.analytics.event_store import DomainEventStore


def test_append_and_list_recent(tmp_path: Path) -> None:
    db = tmp_path / "e.sqlite"
    store = DomainEventStore(db)
    e1 = store.append("LearningProfileUpdated", payload={"x": 1})
    e2 = store.append("PracticeSessionCompleted", payload={"score": 80})
    rows = store.list_recent(limit=10)
    assert len(rows) == 2
    assert rows[0].event_id == e2  # desc by time
    assert rows[0].name == "PracticeSessionCompleted"
    assert rows[1].event_id == e1


def test_fetch_unexported_and_mark(tmp_path: Path) -> None:
    db = tmp_path / "e2.sqlite"
    store = DomainEventStore(db)
    a = store.append("A", payload={})
    b = store.append("B", payload={})
    pending = store.fetch_unexported(limit=100)
    assert len(pending) == 2
    assert pending[0].name == "A"
    n = store.mark_exported([a, b])
    assert n >= 1
    assert store.fetch_unexported(limit=100) == []
