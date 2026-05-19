from __future__ import annotations

import importlib

import pytest

pytest.importorskip("fastapi")

FastAPI = pytest.importorskip("fastapi").FastAPI
TestClient = pytest.importorskip("fastapi.testclient").TestClient
router = importlib.import_module("deeptutor.api.routers.learning_profile").router


def _build_app() -> FastAPI:
    app = FastAPI()
    app.include_router(router, prefix="/api/v1/learning-profile")
    return app


def test_learning_profile_get_defaults(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(
        "deeptutor.api.routers.learning_profile._profile_path",
        lambda: tmp_path / "learning_profile.json",
    )

    with TestClient(_build_app()) as client:
        response = client.get("/api/v1/learning-profile")

    assert response.status_code == 200
    body = response.json()
    assert body["goals"] == []
    assert body["preparing_for"] == []
    assert body["target_path"] == ""
    assert body["weekly_hours"] is None
    assert body["updated_at"] is None


def test_learning_profile_put_roundtrip(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(
        "deeptutor.api.routers.learning_profile._profile_path",
        lambda: tmp_path / "learning_profile.json",
    )

    payload = {
        "goals": ["Exam prep"],
        "preparing_for": ["Engineering"],
        "target_path": "Linear algebra → ML interviews",
        "weekly_hours": 6.5,
        "learning_styles": ["Hands-on practice"],
        "experience_level": "intermediate",
        "prior_summary": "Prefer concise hints.",
        "diagnostic_completed": True,
    }

    with TestClient(_build_app()) as client:
        put = client.put("/api/v1/learning-profile", json=payload)
        assert put.status_code == 200
        saved = put.json()
        assert saved["goals"] == ["Exam prep"]
        assert saved["preparing_for"] == ["Engineering"]
        assert saved["weekly_hours"] == 6.5
        assert saved["updated_at"]

        got = client.get("/api/v1/learning-profile")
        assert got.status_code == 200
        assert got.json()["target_path"] == payload["target_path"]
