"""Tests for Code lab native compiler resolution."""

from __future__ import annotations

import shutil

import pytest

from deeptutor.services.coding_practice import native_runner as nr


def test_resolve_c_compiler_env_full_path(tmp_path: object, monkeypatch: pytest.MonkeyPatch) -> None:
    fake = tmp_path / "fake-gcc"
    fake.write_text("#", encoding="utf-8")
    monkeypatch.setenv("DEEPTUTOR_CC", str(fake))
    monkeypatch.setattr(shutil, "which", lambda *_a, **_k: None)
    assert nr.resolve_c_compiler() == str(fake)


def test_resolve_c_compiler_cp_cc_uses_which(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DEEPTUTOR_CC", raising=False)
    monkeypatch.delenv("CC", raising=False)
    monkeypatch.setenv("CP_CC", "gcc")

    def _which(cmd: str, path: str | None = None) -> str | None:
        if cmd == "gcc":
            return "/mock/gcc"
        return None

    monkeypatch.setattr(shutil, "which", _which)
    assert nr.resolve_c_compiler() == "/mock/gcc"


def test_resolve_cpp_compiler_cxx_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DEEPTUTOR_CXX", raising=False)
    monkeypatch.delenv("CP_CXX", raising=False)
    monkeypatch.setenv("CXX", "g++")

    def _which(cmd: str, path: str | None = None) -> str | None:
        if cmd == "g++":
            return "/mock/g++"
        return None

    monkeypatch.setattr(shutil, "which", _which)
    assert nr.resolve_cpp_compiler() == "/mock/g++"
