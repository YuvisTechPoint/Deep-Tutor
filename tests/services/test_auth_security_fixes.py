"""Regression tests for auth security fixes."""

from __future__ import annotations

import pytest

from deeptutor.multi_user.identity import BootstrapRegisterError, bootstrap_register, load_users
from deeptutor.services.auth import create_token, decode_token, hash_password


@pytest.fixture(autouse=True)
def _auth_env(tmp_path, monkeypatch):
    secret = "test-secret-for-jwt-signing-32bytes!!"
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("AUTH_SECRET", secret)
    monkeypatch.setattr("deeptutor.services.auth.AUTH_ENABLED", True)
    monkeypatch.setattr("deeptutor.services.auth.AUTH_SECRET", secret)
    auth_dir = tmp_path / "multi-user" / "_system" / "auth"
    auth_dir.mkdir(parents=True)
    users_file = auth_dir / "users.json"
    users_file.write_text("{}", encoding="utf-8")
    monkeypatch.setattr("deeptutor.multi_user.identity.USERS_FILE", users_file)
    monkeypatch.setattr("deeptutor.multi_user.identity.LEGACY_USERS_FILE", tmp_path / "legacy.json")
    yield


def test_decode_token_rejects_disabled_user() -> None:
    from deeptutor.multi_user.identity import save_user

    save_user("alice", hash_password("pw"), role="student")
    users = load_users()
    users["alice"]["disabled"] = True
    from deeptutor.multi_user.identity import _write_users

    _write_users(users)

    token = create_token("alice", "student", users["alice"]["id"])
    assert decode_token(token) is None


def test_decode_token_uses_current_role_from_store() -> None:
    from deeptutor.multi_user.identity import save_user, set_role

    save_user("bob", hash_password("pw"), role="student")
    token = create_token("bob", "student")
    set_role("bob", "admin")
    payload = decode_token(token)
    assert payload is not None
    assert payload.role == "admin"


def test_bootstrap_register_is_atomic() -> None:
    bootstrap_register("first", hash_password("pw1"))
    with pytest.raises(BootstrapRegisterError, match="bootstrap_closed"):
        bootstrap_register("second", hash_password("pw2"))


def test_google_oauth_state_roundtrip() -> None:
    from deeptutor.api.routers.auth import issue_google_oauth_state, verify_google_oauth_state

    state = issue_google_oauth_state()
    assert verify_google_oauth_state(state)
    assert not verify_google_oauth_state("forged.state")
    assert not verify_google_oauth_state(None)


def test_login_lockout_applies_after_threshold(monkeypatch, tmp_path) -> None:
    from deeptutor.services.login_lockout import is_locked, record_failed_attempt

    monkeypatch.setattr(
        "deeptutor.services.login_lockout._lockout_path",
        lambda: tmp_path / "lockout.json",
    )
    monkeypatch.setattr("deeptutor.services.login_lockout.AUTH_LOCKOUT_FAILURES_BEFORE_LOCK", 3)

    user = "victim@example.com"
    for _ in range(2):
        record_failed_attempt(user)
    assert not is_locked(user)[0]
    record_failed_attempt(user)
    assert is_locked(user)[0]
