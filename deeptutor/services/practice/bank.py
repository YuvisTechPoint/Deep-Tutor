"""Practice domain types + canonical topic catalogue.

This module deliberately holds **no question content**. The practice center
generates every quiz on demand via :mod:`deeptutor.services.practice.generator`
and never stores items on disk. The only static data here is the curriculum's
topic catalogue (the names of subjects a learner can pick), which mirrors the
roadmap and is not a question bank.

Scoring takes the questions that the live quiz was built from (looked up from
the ephemeral cache in :mod:`deeptutor.services.practice.cache`) so that the
:class:`Question` shape stays the single source of truth for correct answers.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

Difficulty = Literal["easy", "medium", "hard"]


@dataclass(frozen=True)
class Question:
    """Validated MCQ question — produced by the live generator only."""

    id: str
    topic: str
    difficulty: Difficulty
    question: str
    options: dict[str, str]
    correct: str
    explanation: str
    tags: tuple[str, ...]
    model_role: str = "general"

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "topic": self.topic,
            "difficulty": self.difficulty,
            "question": self.question,
            "options": [{"key": k, "text": v} for k, v in self.options.items()],
            "correct": self.correct,
            "explanation": self.explanation,
            "tags": list(self.tags),
            "model_role": self.model_role,
        }

    def to_public_dict(self) -> dict:
        """Like ``to_dict`` but redacts the answer key + explanation.

        Used by ``GET /practice/questions`` so the client receives a quiz it
        can render without leaking the answers via the network response. The
        server keeps the full :class:`Question` in the ephemeral cache and
        scores against it on ``POST /practice/submit``.
        """
        public = self.to_dict()
        public.pop("correct", None)
        public.pop("explanation", None)
        return public


# Canonical curriculum topics. These are *labels*, not questions — the LLM
# generates everything else on demand. Kept in sync with
# :data:`deeptutor.services.workflow.service._MILESTONE_TO_PRACTICE_TOPIC`.
CURRICULUM_TOPICS: tuple[str, ...] = (
    "algorithms",
    "db",
    "dp",
    "graphs",
    "math",
    "ml",
    "python",
    "react",
    "system_design",
)


def list_topics() -> list[str]:
    """Return the topic catalogue (curriculum labels, not questions)."""
    return list(CURRICULUM_TOPICS)


def score_quiz_against(
    questions: list[Question],
    answers: list[dict],
) -> dict:
    """Tally a quiz against the questions it was generated from.

    ``answers`` is a list of ``{"question_id": ..., "answer": ...}`` dicts as
    submitted by the client. Unknown ``question_id``s are silently ignored —
    they typically indicate a stale/expired quiz cache and the router surfaces
    that condition separately.
    """
    by_id = {q.id: q for q in questions}
    correct = 0
    incorrect = 0
    per_topic: dict[str, dict[str, int]] = {}
    for entry in answers:
        qid = entry.get("question_id")
        chosen = entry.get("answer")
        q = by_id.get(qid)
        if q is None:
            continue
        is_correct = q.correct == chosen
        if is_correct:
            correct += 1
        else:
            incorrect += 1
        bucket = per_topic.setdefault(q.topic, {"correct": 0, "incorrect": 0})
        bucket["correct" if is_correct else "incorrect"] += 1
    total = correct + incorrect
    pct = int(round((correct / total) * 100)) if total else 0
    return {
        "correct": correct,
        "incorrect": incorrect,
        "total": total,
        "percentage": pct,
        "per_topic": per_topic,
    }


__all__ = [
    "CURRICULUM_TOPICS",
    "Difficulty",
    "Question",
    "list_topics",
    "score_quiz_against",
]
