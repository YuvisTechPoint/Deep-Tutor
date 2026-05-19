from __future__ import annotations

import importlib

import pytest

pytest.importorskip("fastapi")

FastAPI = pytest.importorskip("fastapi").FastAPI
TestClient = pytest.importorskip("fastapi.testclient").TestClient
router = importlib.import_module("deeptutor.api.routers.career").router


def _build_app() -> FastAPI:
    app = FastAPI()
    app.include_router(router, prefix="/api/v1/career")
    return app


def test_career_paths_defaults(tmp_path, monkeypatch) -> None:
    monkeypatch.setattr(
        "deeptutor.api.routers.learning_profile._profile_path",
        lambda: tmp_path / "profile.json",
    )
    monkeypatch.setattr(
        "deeptutor.api.routers.career.get_gamification_store",
        lambda: type(
            "S",
            (),
            {
                "get_recent_xp_events": lambda self, limit=1000: [],
                "get_state": lambda self: {
                    "streak_current": 0,
                    "streak_max": 0,
                    "total_xp": 0,
                },
            },
        )(),
    )

    with TestClient(_build_app()) as client:
        response = client.get("/api/v1/career/paths")

    assert response.status_code == 200
    body = response.json()
    assert body["preview"] is True
    assert body["live"] is False
    assert len(body["paths"]) >= 3
    assert "stats" in body
    assert body["stats"]["total_xp"] == 0


def test_career_paths_ranks_engineering_when_preparing(tmp_path, monkeypatch) -> None:
    profile_path = tmp_path / "profile.json"
    profile_path.write_text(
        '{"preparing_for": ["Engineering"], "goals": ["Exam prep"], "experience_level": "intermediate"}',
        encoding="utf-8",
    )
    monkeypatch.setattr(
        "deeptutor.api.routers.learning_profile._profile_path",
        lambda: profile_path,
    )
    monkeypatch.setattr(
        "deeptutor.api.routers.career.get_gamification_store",
        lambda: type(
            "S",
            (),
            {
                "get_recent_xp_events": lambda self, limit=1000: [],
                "get_state": lambda self: {
                    "streak_current": 2,
                    "streak_max": 5,
                    "total_xp": 120,
                },
            },
        )(),
    )

    with TestClient(_build_app()) as client:
        response = client.get("/api/v1/career/paths")

    body = response.json()
    assert body["live"] is True
    assert body["paths"][0]["id"] == "engineering-entrance"
    assert body["recommended_path_id"] == "engineering-entrance"
