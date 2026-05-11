"""Learner workflow layer.

This package stitches the individual feature surfaces (Practice, Assessments,
Missions, Roadmap, Chat, TutorBot, …) into a single coherent journey:

* :mod:`mastery` derives per-topic mastery from the gamification ledger.
* :mod:`signals` projects the raw ledger + mastery into the virtual action
  strings the learning-plan templates expect
  (e.g. ``practice.topic_master:python``).
* :mod:`service` answers the two product-shaped questions a learner has:

    - "Where am I in my journey?"      ─ :func:`get_learner_journey`
    - "What should I do right now?"    ─ :func:`get_next_action`

The HTTP surface for these lives in :mod:`deeptutor.api.routers.workflow`.
"""

from deeptutor.services.workflow.mastery import (
    TopicMastery,
    compute_topic_mastery,
    is_topic_mastered,
)
from deeptutor.services.workflow.service import (
    JourneySnapshot,
    NextAction,
    get_learner_journey,
    get_next_action,
)
from deeptutor.services.workflow.signals import (
    derived_action_signals,
    has_signal,
)

__all__ = [
    "JourneySnapshot",
    "NextAction",
    "TopicMastery",
    "compute_topic_mastery",
    "derived_action_signals",
    "get_learner_journey",
    "get_next_action",
    "has_signal",
    "is_topic_mastered",
]
