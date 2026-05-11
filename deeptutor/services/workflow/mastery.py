"""Topic-mastery rollup derived from the XP ledger.

Mastery is computed from raw practice events:

* ``action == "practice.correct_answer"``     → 1 correct attempt for the topic
* ``action == "practice.incorrect_answer"``   → 1 incorrect attempt for the topic

Each event carries the topic in its ``source`` field as ``"practice:<topic>"``
(see :mod:`deeptutor.api.routers.practice`) so we recover it without a separate
store. The rollup intentionally only reads the ledger; it never mutates state.

A topic is considered *mastered* once the learner has both volume **and**
accuracy:

* at least :data:`MASTERY_MIN_CORRECT` correct answers, AND
* accuracy ≥ :data:`MASTERY_MIN_ACCURACY` (0.0–1.0)

The thresholds are deliberately conservative — they are the signal that flips a
roadmap milestone tagged ``practice.topic_master:<topic>`` to ``completed``.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable

# Tuned to make mastery feel earned without being unattainable in the seeded
# 9-question bank. Override via env or DB later if we add a settings surface.
MASTERY_MIN_CORRECT: int = 5
MASTERY_MIN_ACCURACY: float = 0.6


@dataclass(frozen=True)
class TopicMastery:
    """Per-topic mastery summary."""

    topic: str
    correct: int
    incorrect: int
    attempts: int
    accuracy: float  # 0.0 – 1.0
    mastered: bool

    def to_dict(self) -> dict:
        return {
            "topic": self.topic,
            "correct": self.correct,
            "incorrect": self.incorrect,
            "attempts": self.attempts,
            "accuracy": round(self.accuracy, 4),
            "accuracy_pct": int(round(self.accuracy * 100)),
            "mastered": self.mastered,
            "thresholds": {
                "min_correct": MASTERY_MIN_CORRECT,
                "min_accuracy": MASTERY_MIN_ACCURACY,
            },
        }


def _topic_from_source(source: str) -> str | None:
    """Extract ``<topic>`` from a ``"practice:<topic>"`` source string."""
    if not source or not source.startswith("practice:"):
        return None
    topic = source.split(":", 1)[1].strip().lower()
    return topic or None


def compute_topic_mastery(
    ledger_events: Iterable[dict],
) -> dict[str, TopicMastery]:
    """Aggregate practice events by topic.

    Parameters
    ----------
    ledger_events
        Iterable of event dicts as returned by
        :meth:`GamificationStore.get_recent_xp_events`. Only events with
        action ``practice.correct_answer`` / ``practice.incorrect_answer``
        contribute; everything else is ignored.

    Returns
    -------
    dict[str, TopicMastery]
        Mapping ``topic_slug → TopicMastery``. Topics with zero attempts are
        omitted.
    """
    correct: dict[str, int] = {}
    incorrect: dict[str, int] = {}
    for event in ledger_events:
        action = str(event.get("action") or "")
        if action not in {"practice.correct_answer", "practice.incorrect_answer"}:
            continue
        # Prefer the explicit metadata topic when present (set by the practice
        # router); fall back to parsing the source for robustness.
        meta = event.get("metadata") or {}
        topic = str(meta.get("topic") or "").strip().lower()
        if not topic:
            topic = _topic_from_source(str(event.get("source") or "")) or ""
        if not topic:
            continue
        bucket = correct if action == "practice.correct_answer" else incorrect
        bucket[topic] = bucket.get(topic, 0) + 1

    summary: dict[str, TopicMastery] = {}
    for topic in set(correct) | set(incorrect):
        c = correct.get(topic, 0)
        ic = incorrect.get(topic, 0)
        attempts = c + ic
        accuracy = c / attempts if attempts else 0.0
        mastered = c >= MASTERY_MIN_CORRECT and accuracy >= MASTERY_MIN_ACCURACY
        summary[topic] = TopicMastery(
            topic=topic,
            correct=c,
            incorrect=ic,
            attempts=attempts,
            accuracy=accuracy,
            mastered=mastered,
        )
    return summary


def is_topic_mastered(
    topic: str,
    ledger_events: Iterable[dict],
) -> bool:
    """Convenience predicate for a single topic."""
    summary = compute_topic_mastery(ledger_events)
    entry = summary.get((topic or "").strip().lower())
    return bool(entry and entry.mastered)


__all__ = [
    "MASTERY_MIN_ACCURACY",
    "MASTERY_MIN_CORRECT",
    "TopicMastery",
    "compute_topic_mastery",
    "is_topic_mastered",
]
