"""Coding practice lab — generated problems, multi-language compile/run, XP hooks."""

from deeptutor.services.coding_practice.cache import (
    CodingProblemEntry,
    drop_problem,
    get_problem,
    store_problem,
)
from deeptutor.services.coding_practice.generator import (
    CODING_LANGUAGES,
    generate_problem,
    normalize_coding_language,
)
from deeptutor.services.coding_practice.proctoring import (
    BLACKLIST_CONSECUTIVE_THRESHOLD,
    get_exam_guard_store,
)
from deeptutor.services.coding_practice.runner import run_tests, run_user_snippet

__all__ = [
    "BLACKLIST_CONSECUTIVE_THRESHOLD",
    "CODING_LANGUAGES",
    "CodingProblemEntry",
    "drop_problem",
    "get_exam_guard_store",
    "generate_problem",
    "get_problem",
    "normalize_coding_language",
    "run_tests",
    "run_user_snippet",
    "store_problem",
]
