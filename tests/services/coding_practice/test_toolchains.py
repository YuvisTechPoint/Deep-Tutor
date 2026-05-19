"""Toolchain gating for Code lab."""

from __future__ import annotations

import pytest
from fastapi import HTTPException

from deeptutor.services.coding_practice import toolchains as tc


def test_require_toolchain_python_always_ok():
    tc.require_toolchain("python")


def test_require_toolchain_missing_raises(monkeypatch):
    monkeypatch.setattr(
        tc,
        "get_toolchain_status",
        lambda: {
            "languages": {
                "javascript": {
                    "available": False,
                    "message": "Install Node.js",
                }
            }
        },
    )
    with pytest.raises(HTTPException) as exc:
        tc.require_toolchain("javascript")
    assert exc.value.status_code == 503
    assert "Node" in str(exc.value.detail)
