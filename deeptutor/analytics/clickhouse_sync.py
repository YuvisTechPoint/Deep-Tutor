"""Optional replication of domain_events to ClickHouse (blueprint ch 15–16)."""

from __future__ import annotations

import json
import logging
import os
from typing import Any

logger = logging.getLogger(__name__)


def _truthy(name: str) -> bool:
    return os.getenv(name, "").strip().lower() in {"1", "true", "yes", "on"}


def _client():
    if not _truthy("CLICKHOUSE_ENABLED"):
        return None
    try:
        import clickhouse_connect
    except ImportError:
        logger.warning("clickhouse_connect not installed; skip ClickHouse sync")
        return None

    host = os.getenv("CLICKHOUSE_HOST", "localhost").strip()
    port = int(os.getenv("CLICKHOUSE_HTTP_PORT", "8123").strip() or "8123")
    user = os.getenv("CLICKHOUSE_USER", "default").strip()
    password = os.getenv("CLICKHOUSE_PASSWORD", "").strip()
    try:
        client = clickhouse_connect.get_client(
            host=host,
            port=port,
            username=user,
            password=password,
            database="default",
            connect_timeout=5,
            send_receive_timeout=30,
        )
    except Exception:
        logger.warning("ClickHouse client connection failed", exc_info=True)
        return None
    return client


def ensure_domain_events_table(client: Any) -> None:
    db = os.getenv("CLICKHOUSE_DATABASE", "deeptutor").strip()
    client.command(f"CREATE DATABASE IF NOT EXISTS {db}")
    client.command(
        f"""
        CREATE TABLE IF NOT EXISTS {db}.domain_events (
            event_id String,
            name String,
            schema_version UInt32,
            actor_id Nullable(String),
            correlation_id Nullable(String),
            subject_type Nullable(String),
            subject_id Nullable(String),
            payload String,
            created_at_ms UInt64
        )
        ENGINE = MergeTree
        ORDER BY (created_at_ms, name)
        """
    )


def flush_once(batch_limit: int = 500) -> int:
    """Push unexported SQLite rows to ClickHouse; mark exported on success."""
    client = _client()
    if client is None:
        return 0
    from deeptutor.analytics.event_store import get_domain_event_store

    store = get_domain_event_store()
    rows = store.fetch_unexported(limit=batch_limit)
    if not rows:
        return 0
    try:
        ensure_domain_events_table(client)
    except Exception:
        logger.warning("ClickHouse ensure table failed", exc_info=True)
        return 0

    db = os.getenv("CLICKHOUSE_DATABASE", "deeptutor").strip()
    table = f"{db}.domain_events"
    data: list[list[Any]] = []
    ids: list[str] = []
    for r in rows:
        ids.append(r.event_id)
        data.append(
            [
                r.event_id,
                r.name,
                int(r.schema_version),
                r.actor_id,
                r.correlation_id,
                r.subject_type,
                r.subject_id,
                json.dumps(r.payload, ensure_ascii=False),
                int(r.created_at_ms),
            ]
        )
    try:
        client.insert(
            table,
            data,
            column_names=[
                "event_id",
                "name",
                "schema_version",
                "actor_id",
                "correlation_id",
                "subject_type",
                "subject_id",
                "payload",
                "created_at_ms",
            ],
        )
    except Exception:
        logger.warning("ClickHouse insert failed; events remain queued", exc_info=True)
        return 0

    try:
        store.mark_exported(ids)
    except Exception:
        logger.exception("Failed to mark events exported after ClickHouse insert")
    return len(ids)


__all__ = ["flush_once", "ensure_domain_events_table"]
