"""Coding practice language normalization."""

from deeptutor.services.coding_practice.generator import (
    CODING_LANGUAGES,
    normalize_coding_language,
)


def test_normalize_aliases() -> None:
    assert normalize_coding_language("js") == "javascript"
    assert normalize_coding_language("c++") == "cpp"
    assert normalize_coding_language(None) == "python"


def test_normalize_unknown_falls_back() -> None:
    assert normalize_coding_language("rust") == "python"


def test_coding_languages_tuple() -> None:
    assert "java" in CODING_LANGUAGES
    assert "python" in CODING_LANGUAGES
