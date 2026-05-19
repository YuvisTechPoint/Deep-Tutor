"""XP reward redemptions (missions reward shop)."""

from __future__ import annotations

from pathlib import Path

import pytest

from deeptutor.services.gamification.store import GamificationStore


@pytest.fixture(autouse=True)
def _reset_gamification_singleton():
    yield
    GamificationStore.reset_instance()


def test_claim_reward_updates_balance(tmp_path: Path) -> None:
    GamificationStore.reset_instance()
    store = GamificationStore(tmp_path)
    store.award(action="test.seed", xp=1000, source="test")
    st = store.get_state()
    assert st["total_xp"] == 1000
    assert st["reward_xp_balance"] == 1000
    assert st["reward_xp_spent_total"] == 0

    out = store.claim_reward("goodies_bag")
    assert out["claim"]["reward_id"] == "goodies_bag"
    assert out["reward_xp_balance"] == 720
    assert out["reward_xp_spent_total"] == 280

    st2 = store.get_state()
    assert st2["reward_xp_balance"] == 720
    assert len(st2["reward_claims"]) == 1


def test_claim_reward_insufficient_xp(tmp_path: Path) -> None:
    GamificationStore.reset_instance()
    store = GamificationStore(tmp_path)
    store.award(action="test.seed", xp=100, source="test")
    with pytest.raises(ValueError, match="Not enough XP"):
        store.claim_reward("study_kit")
