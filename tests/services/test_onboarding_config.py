"""Tests for onboarding domain / career path helpers (shared with mobile onboarding)."""

from __future__ import annotations

# Stable path → domain keys for career path filtering
PATH_DOMAINS = {
    "ml-engineer": ["engineering"],
    "sde-backend": ["engineering"],
    "data-scientist": ["engineering", "school"],
    "engineering-entrance": ["engineering"],
    "medical-entrance": ["medical"],
    "school-academics": ["school"],
}


def _normalize_domain_keys(preparing_for: list[str]) -> list[str]:
    out: set[str] = set()
    for raw in preparing_for:
        low = raw.strip().lower()
        if low == "school" or "school" in low:
            out.add("school")
        if low == "engineering" or "engineer" in low:
            out.add("engineering")
        if low in ("medical",) or "medical" in low or "medicine" in low:
            out.add("medical")
    return sorted(out)


def _filter_paths(path_ids: list[str], domains: list[str]) -> list[str]:
    if not domains:
        return path_ids
    result = []
    for pid in path_ids:
        allowed = PATH_DOMAINS.get(pid)
        if not allowed:
            result.append(pid)
            continue
        if any(d in domains for d in allowed):
            result.append(pid)
    return result


def test_normalize_legacy_translated_labels():
    keys = _normalize_domain_keys(["Engineering", "Medical"])
    assert keys == ["engineering", "medical"]


def test_filter_engineering_paths():
    all_ids = list(PATH_DOMAINS.keys())
    eng = _filter_paths(all_ids, ["engineering"])
    assert "ml-engineer" in eng
    assert "medical-entrance" not in eng
    assert "school-academics" not in eng


def test_filter_school_includes_data_scientist():
    all_ids = list(PATH_DOMAINS.keys())
    school = _filter_paths(all_ids, ["school"])
    assert "school-academics" in school
    assert "data-scientist" in school
