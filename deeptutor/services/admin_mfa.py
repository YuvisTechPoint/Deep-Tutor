"""Optional TOTP MFA gate for admin API routes (local JSON auth mode)."""

from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any

from fastapi import HTTPException, Request, status

from deeptutor.services.auth import AUTH_ENABLED, POCKETBASE_ENABLED
from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)


def _truthy(name: str) -> bool:
    return os.getenv(name, "").strip().lower() in {"1", "true", "yes", "on"}


def _mfa_path() -> Path:
    ps = get_path_service()
    d = ps.user_data_dir / "auth"
    d.mkdir(parents=True, exist_ok=True)
    return d / "admin_mfa.json"


def _load_all() -> dict[str, Any]:
    p = _mfa_path()
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        logger.warning("Could not read admin MFA store")
        return {}


def _save_all(data: dict[str, Any]) -> None:
    _mfa_path().write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def get_mfa_state(username: str) -> dict[str, Any]:
    return dict(_load_all().get(username) or {})


def set_enrollment_secret(username: str, secret: str) -> None:
    data = _load_all()
    data[username] = {"secret": secret, "enabled": False}
    _save_all(data)


def activate(username: str) -> None:
    data = _load_all()
    if username not in data or not data[username].get("secret"):
        raise ValueError("No enrollment secret; call /auth/mfa/enroll first")
    data[username]["enabled"] = True
    _save_all(data)


def assert_admin_mfa(request: Request, username: str) -> None:
    if not AUTH_ENABLED or POCKETBASE_ENABLED:
        return
    if not _truthy("AUTH_ADMIN_MFA_REQUIRED"):
        return
    if username in {"local", "local-admin"}:
        return
    st = get_mfa_state(username)
    if not st.get("enabled"):
        return
    secret = str(st.get("secret") or "")
    if not secret:
        return
    try:
        import pyotp
    except ImportError:
        logger.warning("pyotp not installed; admin MFA check skipped")
        return
    code = (request.headers.get("X-Admin-MFA") or "").strip().replace(" ", "")
    if not code or not pyotp.TOTP(secret).verify(code, valid_window=1):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin MFA required: set X-Admin-MFA to the current 6-digit TOTP code.",
        )


__all__ = [
    "activate",
    "assert_admin_mfa",
    "get_mfa_state",
    "set_enrollment_secret",
]
