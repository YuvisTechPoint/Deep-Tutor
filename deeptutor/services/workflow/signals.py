"""Derived action signals that bridge raw events to roadmap milestone triggers.

The learning-plan templates tag each milestone with ``trigger_actions`` such as
``practice.topic_master:python``. The raw gamification ledger does not store
that string verbatim — it stores per-attempt events like
``practice.correct_answer`` instead. This module produces the *virtual* action
strings the templates expect, computed on demand from the ledger.

The contract is intentionally small: callers ask for the *set* of derived
signals at any point in time, or check whether a single signal is present.
Adding a new derived signal (e.g. ``career.portfolio_submitted``) is a one-line
extension here.
"""

from __future__ import annotations

import logging
from typing import Iterable

from deeptutor.services.workflow.mastery import compute_topic_mastery

logger = logging.getLogger(__name__)


def derived_action_signals(ledger_events: Iterable[dict]) -> set[str]:
    """Project a ledger snapshot into the set of derived action strings.

    The returned strings are designed to be checked the same way the planner
    checks raw events: ``derived & set(milestone.trigger_actions)`` is enough
    to auto-complete a milestone.
    """
    events = list(ledger_events)
    signals: set[str] = set()

    # ── Topic-mastery signals (practice.topic_master:<topic>) ────────────────
    for topic, mastery in compute_topic_mastery(events).items():
        if mastery.mastered:
            signals.add(f"practice.topic_master:{topic}")

    # ── Career portfolio signal — emitted by the career router when a learner
    #    submits portfolio links. We keep it as a pass-through so the planner
    #    treats it the same as derived signals.
    for event in events:
        action = str(event.get("action") or "")
        if action in {
            "career.portfolio_submitted",
            "assessment.completed",
            "mission.complete",
        }:
            signals.add(action)

    return signals


def has_signal(signal: str, ledger_events: Iterable[dict]) -> bool:
    """Return True if the named derived signal is currently active."""
    return signal in derived_action_signals(ledger_events)


__all__ = ["derived_action_signals", "has_signal"]
