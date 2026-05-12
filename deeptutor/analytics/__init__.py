"""Durable domain analytics events (blueprint ch 15, 38)."""

from deeptutor.analytics.emit import emit_domain_event
from deeptutor.analytics.event_store import DomainEventRecord, get_domain_event_store

__all__ = ["DomainEventRecord", "emit_domain_event", "get_domain_event_store"]
