from __future__ import annotations

from pathlib import Path

import pytest

from deeptutor.services.live_session_prep.store import LiveSessionPrepStore


@pytest.fixture()
def prep_store(tmp_path: Path) -> LiveSessionPrepStore:
    LiveSessionPrepStore.reset_instance()
    db = tmp_path / "t.sqlite"
    store = LiveSessionPrepStore(db_path=db)
    yield store
    LiveSessionPrepStore.reset_instance()


def test_draft_crud_and_submit(prep_store: LiveSessionPrepStore) -> None:
    d = prep_store.create_draft(
        user_id="u1",
        session_id="sess-a",
        topic="Topic",
        goals=["g1"],
        questions=["q1"],
        notes="n",
        attachments=[{"type": "link", "href": "https://a", "label": "a"}],
        status="draft",
    )
    assert d.status == "draft"
    got = prep_store.get_draft(d.id)
    assert got is not None
    assert got.goals == ["g1"]

    upd = prep_store.update_draft(d.id, user_id="u1", status="submitted")
    assert upd is not None and upd.status == "submitted"

    locked = prep_store.update_draft(d.id, user_id="u1", topic="Nope")
    assert locked is None


def test_pre_session_reorder(prep_store: LiveSessionPrepStore) -> None:
    a = prep_store.create_request(
        user_id="u1",
        session_id="s1",
        draft_id=None,
        title="A",
        description="da",
        intent_type="doubt",
        priority="high",
        anonymous=False,
        attachments=[],
        live_session_starts_at=None,
        student_username="alice",
    )
    b = prep_store.create_request(
        user_id="u2",
        session_id="s1",
        draft_id=None,
        title="B",
        description="db",
        intent_type="other",
        priority="low",
        anonymous=False,
        attachments=[],
        live_session_starts_at=None,
        student_username="bob",
    )
    assert a is not None and b is not None

    ok = prep_store.reorder_requests(session_id="s1", ordered_ids=[b.id, a.id])
    assert ok is True
    rows = prep_store.list_requests_mentor(session_id="s1")
    ids = [r.id for r in rows]
    assert ids == [b.id, a.id]


def test_mentor_filters_and_search(prep_store: LiveSessionPrepStore) -> None:
    prep_store.create_request(
        user_id="u9",
        session_id="sx",
        draft_id=None,
        title="Alpha",
        description="contains betaunique",
        intent_type="code_review",
        priority="medium",
        anonymous=False,
        attachments=[],
        live_session_starts_at=None,
        student_username="stu",
    )
    f1 = prep_store.list_requests_mentor(session_id="sx", intent_type="doubt")
    assert len(f1) == 0
    f2 = prep_store.list_requests_mentor(session_id="sx", search="betaunique")
    assert len(f2) == 1
