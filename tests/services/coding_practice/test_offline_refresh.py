"""Offline problem bank rotation and sample-test run harness."""

from __future__ import annotations

import pytest

from deeptutor.services.coding_practice import runner
from deeptutor.services.coding_practice.generator import _offline_problem


def test_offline_problem_rotates_with_refresh_token() -> None:
    a = _offline_problem("python", "algorithms", "medium", refresh_token="one")
    b = _offline_problem("python", "algorithms", "medium", refresh_token="two")
    assert a["title"] != b["title"] or a["problem_id"] != b["problem_id"]


@pytest.mark.asyncio
async def test_run_tests_max_subarray_solution() -> None:
    code = """
def max_subarray_sum(nums):
    current = max_sum = nums[0]
    for num in nums[1:]:
        current = max(num, current + num)
        max_sum = max(max_sum, current)
    return max_sum
""".strip()
    tests = [
        {"args": [[-2, 1, -3, 4, -1, 2, 1, -5, 4]], "expected": 6},
        {"args": [[1]], "expected": 1},
    ]
    r = await runner.run_tests(
        code,
        entrypoint="max_subarray_sum",
        tests=tests,
        language="python",
        timeout=8,
    )
    assert r["ok"] is True
    assert r["exit_code"] == 0
    assert len(r["tests"]) == 2
    assert all(row.get("ok") for row in r["tests"])
