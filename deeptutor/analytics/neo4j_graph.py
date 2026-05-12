"""Optional Neo4j milestone graph (blueprint ch 7, 16)."""

from __future__ import annotations

import logging
import os
from typing import Any

logger = logging.getLogger(__name__)


def _truthy(name: str) -> bool:
    return os.getenv(name, "").strip().lower() in {"1", "true", "yes", "on"}


def get_driver() -> Any | None:
    if not _truthy("NEO4J_ENABLED"):
        return None
    try:
        from neo4j import GraphDatabase
    except ImportError:
        logger.warning("neo4j driver not installed; graph features disabled")
        return None

    uri = os.getenv("NEO4J_URI", "bolt://localhost:7687").strip()
    user = os.getenv("NEO4J_USER", "neo4j").strip()
    password = os.getenv("NEO4J_PASSWORD", "").strip()
    if not password:
        logger.warning("NEO4J_PASSWORD not set; skip Neo4j")
        return None
    try:
        return GraphDatabase.driver(uri, auth=(user, password))
    except Exception:
        logger.warning("Neo4j driver creation failed", exc_info=True)
        return None


def sync_milestone_graph_from_templates() -> dict[str, int]:
    """MERGE milestones and NEXT edges from deterministic plan templates."""
    from deeptutor.services.learning_plan import iter_milestone_prerequisite_edges

    driver = get_driver()
    if driver is None:
        return {"edges_written": 0, "skipped": 1}
    edges = iter_milestone_prerequisite_edges()
    if not edges:
        driver.close()
        return {"edges_written": 0, "skipped": 0}
    cyph = """
    UNWIND $edges AS e
    MERGE (a:Milestone {id: e.from_id})
    SET a.plan_id = e.plan_id, a.phase_id = e.phase_id
    MERGE (b:Milestone {id: e.to_id})
    SET b.plan_id = e.plan_id, b.phase_id = e.phase_id
    MERGE (a)-[:NEXT]->(b)
    """
    try:
        with driver.session() as session:
            session.run(cyph, edges=edges)
    finally:
        driver.close()
    return {"edges_written": len(edges), "skipped": 0}


def next_milestone_ids(after_id: str) -> list[str]:
    """Return milestone ids reachable via one NEXT hop from ``after_id``."""
    driver = get_driver()
    if driver is None:
        return []
    q = """
    MATCH (:Milestone {id: $id})-[:NEXT]->(n:Milestone)
    RETURN n.id AS mid ORDER BY mid
    """
    try:
        with driver.session() as session:
            rows = session.run(q, id=after_id.strip())
            return [str(r["mid"]) for r in rows if r.get("mid")]
    except Exception:
        logger.debug("Neo4j next query failed", exc_info=True)
        return []
    finally:
        driver.close()


__all__ = ["get_driver", "next_milestone_ids", "sync_milestone_graph_from_templates"]
