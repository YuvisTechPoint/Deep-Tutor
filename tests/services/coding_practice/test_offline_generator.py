"""Offline Code lab problem bank."""

from deeptutor.services.coding_practice.generator import (
    _OFFLINE_BANKS,
    OFFLINE_GENERATION_FLAG,
    _offline_problem,
)


def test_offline_problem_sets_flag_and_clean_hints() -> None:
    row = _offline_problem("python", "algorithms", "medium")
    assert row[OFFLINE_GENERATION_FLAG] is True
    assert row["hints"]
    assert not any(h.startswith("[Offline]") for h in row["hints"])


def test_offline_bank_hints_never_include_system_notice() -> None:
    for bank in _OFFLINE_BANKS.values():
        for problem in bank:
            for hint in problem.get("hints") or []:
                assert not str(hint).startswith("[Offline]")
