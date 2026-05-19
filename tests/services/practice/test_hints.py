"""Practice hint parsing and cache."""

from __future__ import annotations

import pytest

from deeptutor.services.practice.bank import Question
from deeptutor.services.practice.cache import (
    drop_quiz,
    get_cached_hint,
    get_quiz,
    store_hint,
    store_quiz,
)
from deeptutor.services.practice.hints import (
    _fallback_hint,
    _parse_hint_json,
    generate_question_hint,
    get_question_hint,
)


def _sample_question() -> Question:
    return Question(
        id="gen_test123",
        topic="general",
        difficulty="medium",
        question="What is the primary function of a control group in an experiment?",
        options={
            "A": "Introduce the variable",
            "B": "Provide a baseline without the variable",
            "C": "Increase sample size",
            "D": "Reduce cost",
        },
        correct="B",
        explanation="Control groups are unchanged for comparison.",
        tags=("experimental design",),
        model_role="general",
    )


def test_parse_hint_json_accepts_object() -> None:
    raw = '{"hint": "Think about what stays constant so you can compare outcomes."}'
    assert _parse_hint_json(raw) == "Think about what stays constant so you can compare outcomes."


def test_parse_hint_json_rejects_answer_leak() -> None:
    raw = '{"hint": "The correct answer is B because it is right."}'
    assert _parse_hint_json(raw) is None


def test_fallback_hint_mentions_question_topic() -> None:
    q = _sample_question()
    hint = _fallback_hint(q)
    assert "control group" in hint.lower() or "experiment" in hint.lower()
    assert "data structure" not in hint.lower()


def test_hint_cache_roundtrip() -> None:
    q = _sample_question()
    quiz_id = store_quiz([q], topic="general", difficulty="medium")
    assert get_cached_hint(quiz_id, q.id) is None
    assert store_hint(quiz_id, q.id, "Compare unchanged vs treated groups.")
    assert get_cached_hint(quiz_id, q.id) == "Compare unchanged vs treated groups."
    drop_quiz(quiz_id)
    assert get_quiz(quiz_id) is None


@pytest.mark.asyncio
async def test_get_question_hint_uses_cache(monkeypatch: pytest.MonkeyPatch) -> None:
    q = _sample_question()
    quiz_id = store_quiz([q], topic="general", difficulty="medium")
    store_hint(quiz_id, q.id, "Cached hint text.")

    async def fail_llm(*_a, **_k):
        raise RuntimeError("should not call LLM")

    monkeypatch.setattr(
        "deeptutor.services.practice.hints.generate_question_hint",
        fail_llm,
    )
    hint = await get_question_hint(quiz_id, q)
    assert hint == "Cached hint text."
    drop_quiz(quiz_id)


@pytest.mark.asyncio
async def test_generate_question_hint_from_llm(monkeypatch: pytest.MonkeyPatch) -> None:
    async def fake_ask(*_a, **_k):
        return '{"hint": "Focus on what the control group does not receive."}'

    monkeypatch.setattr("deeptutor.services.practice.hints._ask_llm", fake_ask)
    hint = await generate_question_hint(_sample_question())
    assert "control group" in hint.lower()
