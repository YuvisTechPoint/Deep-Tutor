"""Diagnostic quiz topic selection from learning profile."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from deeptutor.api.routers import diagnostic as diag_mod


@pytest.fixture()
def profile_file(tmp_path, monkeypatch):
    learning = tmp_path / "learning"
    learning.mkdir()
    path = learning / "profile.json"

    class _PathSvc:
        user_data_dir = tmp_path

    monkeypatch.setattr(diag_mod, "get_path_service", lambda: _PathSvc())
    monkeypatch.setattr(diag_mod, "_profile_path", lambda: path)
    return path


def test_diagnostic_topic_medical_path(profile_file: Path):
    profile_file.write_text(
        json.dumps(
            {
                "career_path_id": "medical-entrance",
                "preparing_for": ["medical"],
            }
        ),
        encoding="utf-8",
    )
    topic, difficulty = diag_mod._diagnostic_topic_from_profile()
    assert topic == "biology"
    assert difficulty == "medium"


def test_diagnostic_topic_engineering_slug(profile_file: Path):
    profile_file.write_text(
        json.dumps({"preparing_for": ["engineering"]}),
        encoding="utf-8",
    )
    topic, _ = diag_mod._diagnostic_topic_from_profile()
    assert topic == "physics"


def test_diagnostic_topic_defaults_general(profile_file: Path):
    profile_file.write_text("{}", encoding="utf-8")
    topic, _ = diag_mod._diagnostic_topic_from_profile()
    assert topic == "general"
