"""Co-Writer storage helpers (title derivation, list display)."""

from deeptutor.co_writer.storage import (
    _derive_title,
    _display_title,
    _word_count,
)


def test_derive_title_skips_hash_only_lines() -> None:
    assert _derive_title("#\n## Real title\nbody") == "Real title"
    assert _derive_title("###\nPlain first line") == "Plain first line"


def test_display_title_replaces_hash_only_stored() -> None:
    assert _display_title("#", "## Good\nmore") == "Good"
    assert _display_title("###", "Just body text") == "Just body text"


def test_word_count_basic() -> None:
    assert _word_count("") == 0
    assert _word_count("  \n  ") == 0
    assert _word_count("one two three") == 3
