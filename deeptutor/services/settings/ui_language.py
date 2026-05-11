"""Normalize persisted web UI language codes (interface.json, settings API)."""

from __future__ import annotations

from typing import Any, Literal

UiLanguage = Literal["en", "hi", "bn"]


def normalize_ui_language(value: Any, default: str = "en") -> UiLanguage:
    """Return ``en`` | ``hi`` | ``bn``. Legacy Chinese UI codes map to ``en``."""
    if value is None or value == "":
        value = default or "en"

    if not isinstance(value, str):
        return normalize_ui_language(default or "en", "en")

    s = value.lower().strip()
    if s in {"hi", "hindi"}:
        return "hi"
    if s in {"bn", "bengali", "bangla"}:
        return "bn"
    if s in {"zh", "chinese", "cn"} or s.startswith("zh-") or s.startswith("zh_"):
        return "en"
    if s in {"en", "english"} or s.startswith("en-") or s.startswith("en_"):
        return "en"
    return "en"


__all__ = ["UiLanguage", "normalize_ui_language"]
