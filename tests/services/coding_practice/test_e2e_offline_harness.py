"""End-to-end harness runs for offline problems (skip if toolchain missing)."""

from __future__ import annotations

import pytest

from deeptutor.services.coding_practice.generator import _OFFLINE_BANKS
from deeptutor.services.coding_practice.native_runner import (
    resolve_c_compiler,
    resolve_cpp_compiler,
    resolve_java_tools,
    resolve_node,
)
from deeptutor.services.coding_practice.runner import run_tests

_SOLUTIONS: dict[str, dict[str, str]] = {
    "python": {
        "find_missing_number": (
            "def find_missing_number(nums):\n"
            "    n = len(nums) + 1\n"
            "    return n * (n + 1) // 2 - sum(nums)\n"
        ),
    },
    "javascript": {
        "arraySum": (
            "export function arraySum(nums) {\n"
            "  return nums.reduce((a, b) => a + b, 0);\n"
            "}\n"
        ),
    },
    "c": {
        "add": "int add(int a, int b) { return a + b; }\n",
    },
    "cpp": {
        "add": "int add(int a, int b) { return a + b; }\n",
    },
    "java": {
        "add": (
            "public class Solution {\n"
            "    public static int add(int a, int b) { return a + b; }\n"
            "}\n"
        ),
    },
}


def _offline_row(lang: str) -> dict:
    bank = _OFFLINE_BANKS[lang]
    return bank[0]


@pytest.mark.asyncio
@pytest.mark.parametrize("lang", ["python", "javascript", "c", "cpp", "java"])
async def test_offline_add_passes(lang: str) -> None:
    if lang == "python":
        pass
    elif lang == "javascript" and not resolve_node():
        pytest.skip("node not installed")
    elif lang == "c" and not resolve_c_compiler():
        pytest.skip("C compiler not installed")
    elif lang == "cpp" and not resolve_cpp_compiler():
        pytest.skip("C++ compiler not installed")
    elif lang == "java":
        javac, java = resolve_java_tools()
        if not javac or not java:
            pytest.skip("JDK not installed")

    row = _offline_row(lang)
    entry = row["entrypoint"]
    code = _SOLUTIONS[lang].get(entry)
    if not code:
        pytest.skip(f"no canned solution for {lang}/{entry}")

    outcome = await run_tests(
        code,
        entrypoint=entry,
        tests=row["tests"],
        language=lang,
        timeout=20,
    )
    assert outcome.get("tests"), outcome.get("stderr") or outcome.get("stdout")
    assert outcome["ok"] is True, outcome
