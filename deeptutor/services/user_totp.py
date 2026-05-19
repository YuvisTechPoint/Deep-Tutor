"""Optional TOTP MFA enrollment for any authenticated user (local JWT mode)."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)


def _store_path() -> Path:
    ps = get_path_service()
    d = ps.user_data_dir / "auth"
    d.mkdir(parents=True, exist_ok=True)
    return d / "user_totp.json"


def _load_all() -> dict[str, Any]:
    p = _store_path()
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        logger.warning("Could not read user TOTP store")
        return {}


def _save_all(data: dict[str, Any]) -> None:
    _store_path().write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def get_user_totp_state(username: str) -> dict[str, Any]:
    return dict(_load_all().get(username) or {})


def set_user_enrollment_secret(username: str, secret: str) -> None:
    data = _load_all()
    data[username] = {"secret": secret, "enabled": False}
    _save_all(data)


def activate_user_totp(username: str) -> None:
    data = _load_all()
    if username not in data or not data[username].get("secret"):
        raise ValueError("No enrollment secret; call /auth/user/mfa/enroll first")
    data[username]["enabled"] = True
    _save_all(data)


def verify_user_totp(username: str, code: str) -> bool:
    st = get_user_totp_state(username)
    secret = str(st.get("secret") or "")
    if not secret or not st.get("enabled"):
        return False
    try:
        import pyotp
    except ImportError:
        return False
    return bool(pyotp.TOTP(secret).verify(code.strip().replace(" ", ""), valid_window=1))


__all__ = [
    "activate_user_totp",
    "get_user_totp_state",
    "set_user_enrollment_secret",
    "verify_user_totp",
]
