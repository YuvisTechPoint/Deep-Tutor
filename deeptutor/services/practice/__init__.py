"""Practice service — realtime LLM-generated MCQ quizzes.

There is **no on-disk question bank**. Every quiz is generated on demand by
:func:`generate_quiz`; the resulting :class:`Question` list is held in an
ephemeral, process-local TTL cache (see :mod:`cache`) only long enough to score
the learner's submission, then discarded.

Public surface:

* :func:`generate_quiz`     — async LLM call → list[Question]
* :func:`store_quiz`        — cache for the round-trip between GET/POST
* :func:`get_quiz`          — retrieve cached questions during scoring
* :func:`drop_quiz`         — forget a quiz after scoring
* :func:`score_quiz_against` — compute the score from a question list
* :func:`list_topics`       — curriculum topic labels (not questions)
"""

from deeptutor.services.practice.bank import (
    CURRICULUM_TOPICS,
    Question,
    list_topics,
    score_quiz_against,
)
from deeptutor.services.practice.cache import (
    cache_stats,
    drop_quiz,
    get_quiz,
    store_quiz,
)
from deeptutor.services.practice.generator import generate_quiz

__all__ = [
    "CURRICULUM_TOPICS",
    "Question",
    "cache_stats",
    "drop_quiz",
    "generate_quiz",
    "get_quiz",
    "list_topics",
    "score_quiz_against",
    "store_quiz",
]
