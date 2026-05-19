"""Code lab exam proctoring store."""

from __future__ import annotations

import pytest

from deeptutor.services.coding_practice.proctoring import (
    BLACKLIST_CONSECUTIVE_THRESHOLD,
    CodingExamGuardStore,
)


@pytest.fixture
def store(tmp_path):
    CodingExamGuardStore.reset_instance()
    return CodingExamGuardStore(base_dir=tmp_path / "learning")


def test_start_and_end_session_resets_violations_on_submit(store: CodingExamGuardStore) -> None:
    out = store.start_session(problem_id="p1")
    sid = out["session_id"]
    store.record_violation(sid, "tab_hidden")
    assert store.get_status().consecutive_violations == 1
    store.end_session(sid, submitted=True)
    assert store.get_status().consecutive_violations == 0


def test_three_violations_blacklists(store: CodingExamGuardStore) -> None:
    out = store.start_session()
    sid = out["session_id"]
    for reason in ("tab_hidden", "fullscreen_exit", "window_blur"):
        store.record_violation(sid, reason)  # type: ignore[arg-type]
    assert store.get_status().blacklisted is True
    with pytest.raises(PermissionError):
        store.assert_not_blacklisted()


def test_clear_blacklist_for_testing(store: CodingExamGuardStore) -> None:
    out = store.start_session()
    sid = out["session_id"]
    for reason in ("tab_hidden", "fullscreen_exit", "window_blur"):
        store.record_violation(sid, reason)  # type: ignore[arg-type]
    assert store.get_status().blacklisted is True
    cleared = store.clear_blacklist_for_testing()
    assert cleared["blacklisted"] is False
    assert store.get_status().consecutive_violations == 0
    store.assert_not_blacklisted()


def test_dedupes_rapid_duplicate_violations(store: CodingExamGuardStore) -> None:
    out = store.start_session()
    sid = out["session_id"]
    r1 = store.record_violation(sid, "fullscreen_exit")
    r2 = store.record_violation(sid, "fullscreen_exit")
    assert r1.get("new_violation") is True
    assert r2.get("new_violation") is False
    assert store.get_status().consecutive_violations == 1
