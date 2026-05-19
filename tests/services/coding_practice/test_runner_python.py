"""Tests for Python coding-lab harness preparation and result parsing."""

from __future__ import annotations

import pytest

from deeptutor.services.coding_practice import runner


def test_prepare_strips_module_print_and_name_main() -> None:
    src = """
def max_subarray_sum(nums):
    return 0

print(max_subarray_sum([-2]))
if __name__ == "__main__":
    print(1)
""".strip()
    out = runner._prepare_python_for_coding_lab(src)
    assert "print(" not in out
    assert "max_subarray_sum" in out


def test_prepare_preserves_function_body_print() -> None:
    src = """
def f():
    print("side")
    return 1
""".strip()
    assert runner._prepare_python_for_coding_lab(src) == src


def test_prepare_syntax_error_returns_raw() -> None:
    bad = "def oops("
    assert runner._prepare_python_for_coding_lab(bad) == bad


@pytest.mark.asyncio
async def test_run_tests_parses_when_subprocess_exit_nonzero(monkeypatch: pytest.MonkeyPatch) -> None:
    async def fake_run_code(_lang: str, _script: str, timeout: int = 10) -> dict:
        return {
            "stdout": 'hello\n[{"ok": true, "index": 0, "got": "1", "expected": "1"}]\n',
            "stderr": "",
            "exit_code": 1,
            "elapsed_ms": 12.0,
        }

    monkeypatch.setattr(runner, "run_code", fake_run_code)
    r = await runner.run_tests(
        "def f():\n    return 1\n",
        entrypoint="f",
        tests=[{"args": [], "expected": 1}],
        language="python",
        timeout=5,
    )
    assert r["ok"] is True
    assert r["exit_code"] == 0
    assert len(r["tests"]) == 1
    assert r["tests"][0].get("ok") is True


@pytest.mark.asyncio
async def test_run_tests_fails_when_no_json_rows(monkeypatch: pytest.MonkeyPatch) -> None:
    async def fake_run_code(_lang: str, _script: str, timeout: int = 10) -> dict:
        return {"stdout": "no json here", "stderr": "err", "exit_code": 2, "elapsed_ms": 1.0}

    monkeypatch.setattr(runner, "run_code", fake_run_code)
    r = await runner.run_tests("def f():\n    return 1\n", entrypoint="f", tests=[], language="python")
    assert r["ok"] is False
    assert r["tests"] == []
