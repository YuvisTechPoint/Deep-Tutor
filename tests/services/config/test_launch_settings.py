from __future__ import annotations

import json
from pathlib import Path

from deeptutor.services.config.launch_settings import load_launch_settings


def _settings_dir(root: Path) -> Path:
    path = root / "data" / "user" / "settings"
    path.mkdir(parents=True, exist_ok=True)
    return path


def test_launch_settings_reads_ports_from_env_and_ignores_legacy_env_json(
    monkeypatch, tmp_path: Path
) -> None:
    for key in ("BACKEND_PORT", "UI_LANGUAGE", "LANGUAGE"):
        monkeypatch.delenv(key, raising=False)

    (tmp_path / ".env").write_text(
        "BACKEND_PORT=9001\nUI_LANGUAGE=en\n",
        encoding="utf-8",
    )
    settings_dir = _settings_dir(tmp_path)
    (settings_dir / "env.json").write_text(
        json.dumps({"ports": {"backend": 8101, "frontend": 4100}}),
        encoding="utf-8",
    )
    (settings_dir / "interface.json").write_text(
        json.dumps({"language": "zh"}),
        encoding="utf-8",
    )

    settings = load_launch_settings(tmp_path)

    assert settings.backend_port == 9001
    assert settings.language == "en"
    assert ".env" in settings.source
    assert "env.json" not in settings.source
    assert "interface.json" in settings.source


def test_launch_settings_fall_back_to_env_when_interface_settings_missing(
    monkeypatch, tmp_path: Path
) -> None:
    for key in ("BACKEND_PORT", "UI_LANGUAGE", "LANGUAGE"):
        monkeypatch.delenv(key, raising=False)

    (tmp_path / ".env").write_text(
        "BACKEND_PORT=9101\nUI_LANGUAGE=zh\n",
        encoding="utf-8",
    )

    settings = load_launch_settings(tmp_path)

    assert settings.backend_port == 9101
    assert settings.source == ".env"
    assert settings.language == "en"


def test_launch_settings_fall_back_per_invalid_env_port(monkeypatch, tmp_path: Path) -> None:
    for key in ("BACKEND_PORT", "UI_LANGUAGE", "LANGUAGE"):
        monkeypatch.delenv(key, raising=False)
    monkeypatch.setenv("BACKEND_PORT", "9201")

    (tmp_path / ".env").write_text(
        "BACKEND_PORT=not-a-port\n",
        encoding="utf-8",
    )

    settings = load_launch_settings(tmp_path)

    assert settings.backend_port == 9201
    assert settings.source == "environment"
