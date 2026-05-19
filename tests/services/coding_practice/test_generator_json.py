"""Code lab LLM JSON parsing."""

from deeptutor.services.coding_practice.generator import (
    _parse_problem_payload,
    _validate_python,
)


def test_parse_repaired_starter_code_with_literal_newlines() -> None:
    # Models often emit unescaped newlines inside starter_code strings.
    raw = """{
  "title": "Sum List",
  "description": "Return the sum of nums.",
  "entrypoint": "sum_list",
  "starter_code": "def sum_list(nums):
    pass",
  "hints": ["Use a loop."],
  "tests": [
    {"args": [[1, 2]], "expected": 3},
    {"args": [[0]], "expected": 0},
    {"args": [[-1, 1]], "expected": 0}
  ]
}"""
    parsed = _parse_problem_payload(raw)
    assert parsed is not None
    ok = _validate_python(parsed)
    assert ok is not None
    assert ok["entrypoint"] == "sum_list"
