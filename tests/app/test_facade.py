"""Tests for the public DeepTutor application facade."""

from __future__ import annotations

from deeptutor.app import DeepTutorApp


def test_capability_contract_serializes_slotted_availability() -> None:
    app = DeepTutorApp()

    contract = app.get_capability_contract("study_plan")

    assert contract["name"] == "study_plan"
    assert contract["availability"] == {
        "name": "study_plan",
        "available": True,
        "install_hint": "",
    }
