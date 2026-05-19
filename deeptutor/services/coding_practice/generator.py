"""LLM-generated coding problems for the Code lab (multi-language).

Uses the same structured-output defaults as Practice Center on Groq/OpenAI API
(see ``deeptutor.services.llm.feature_model_defaults``), unless
``LLM_MODEL_CODING_PRACTICE`` / ``LLM_MODEL_PRACTICE`` / ``HF_MODEL_PRACTICE_CODING`` apply.
"""

from __future__ import annotations

import asyncio
import hashlib
import logging
import os
import re
from typing import Any
import uuid

from deeptutor.services.llm.feature_model_defaults import default_structured_output_model
from deeptutor.services.model_router import Intent, get_model_router

logger = logging.getLogger(__name__)

_IDENT = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")

CODING_LANGUAGES: tuple[str, ...] = ("python", "javascript", "cpp", "c", "java")

_PROMPTS: dict[str, str] = {
    "python": """You are an expert Python interview coach. Create ONE coding exercise.

Topic: **{topic}**
Difficulty: **{difficulty}**

Return ONLY valid JSON (no markdown fences, no commentary) with this exact shape:
{{
  "title": "<short title>",
  "description": "<2-5 sentences: problem statement, constraints, return value>",
  "entrypoint": "<python function name, snake_case>",
  "starter_code": "<full Python source defining ONLY that function with a pass or placeholder body; include a short docstring>",
  "hints": ["<hint1>", "<hint2>"],
  "tests": [
    {{"args": [<positional args as JSON>], "expected": <JSON literal for expected return>}}
  ]
}}

Rules:
- `starter_code` MUST define a function whose name exactly matches `entrypoint`.
- Use only Python built-ins and the standard library (no numpy/pandas).
- Provide 4 to 6 tests including edge cases; `args` is a list of arguments to pass positionally to the function.
- `expected` must be JSON-serializable (numbers, strings, lists, dicts, booleans, null).
- Keep total starter_code under 120 lines.
""",
    "javascript": """You are an expert JavaScript (ES modules) interview coach. Create ONE coding exercise.

Topic: **{topic}**
Difficulty: **{difficulty}**

Return ONLY valid JSON (no markdown fences, no commentary) with this exact shape:
{{
  "title": "<short title>",
  "description": "<2-5 sentences>",
  "entrypoint": "<camelCase or snake_case export name>",
  "starter_code": "<full ESM module: export function entrypoint(...args) {{ ... }} only; no top-level side effects>",
  "hints": ["<hint1>", "<hint2>"],
  "tests": [
    {{"args": [<JSON array of positional args>], "expected": <JSON literal>}}
  ]
}}

Rules:
- `starter_code` MUST `export function <entrypoint>(...) {{ ... }}` with that exact name.
- Use only JS built-ins (no fetch, no require, no fs).
- 4–6 tests; `expected` JSON-serializable; `args` passed with spread to the function.
- Keep starter_code under 120 lines.
""",
    "c": """You are an expert C interview coach. Create ONE coding exercise solvable in ANSI C11.

Topic: **{topic}**
Difficulty: **{difficulty}**

Return ONLY valid JSON (no markdown fences, no commentary) with this exact shape:
{{
  "title": "<short title>",
  "description": "<2-5 sentences; state return type int>",
  "entrypoint": "<function name, snake_case>",
  "starter_code": "<C source defining ONLY: int entrypoint(int a, int b, ...) {{ ... }} — adjust arity to the problem; NO main; use only stdlib.h / stdio.h / string.h / stdbool.h if needed>",
  "hints": ["<hint1>", "<hint2>"],
  "tests": [
    {{"args": [<only integers or booleans as JSON — booleans become 0/1>], "expected": <int or boolean>}}
  ]
}}

Rules:
- The grader only supports **int** arguments and **int** return (booleans in tests must be true/false JSON and map to 0/1).
- Provide 4–6 tests; each `args` length must match the function arity.
- NO `main` function in starter_code.
- Keep starter_code under 120 lines.
""",
    "cpp": """You are an expert C++17 interview coach. Create ONE coding exercise.

Topic: **{topic}**
Difficulty: **{difficulty}**

Return ONLY valid JSON (no markdown fences, no commentary) with this exact shape:
{{
  "title": "<short title>",
  "description": "<2-5 sentences; prefer int return>",
  "entrypoint": "<function name, snake_case>",
  "starter_code": "<C++ source defining ONLY: int entrypoint(int a, ...) {{ ... }} — match arity; NO main; standard library only>",
  "hints": ["<hint1>", "<hint2>"],
  "tests": [
    {{"args": [<only integers or booleans JSON>], "expected": <int or boolean>}}
  ]
}}

Rules:
- The grader uses the same int/bool scalar harness as C: tests must use int-compatible values only.
- 4–6 tests; args length matches function.
- NO `main` in starter_code.
- Keep starter_code under 120 lines.
""",
    "java": """You are an expert Java interview coach. Create ONE coding exercise.

Topic: **{topic}**
Difficulty: **{difficulty}**

Return ONLY valid JSON (no markdown fences, no commentary) with this exact shape:
{{
  "title": "<short title>",
  "description": "<2-5 sentences>",
  "entrypoint": "<camelCase method name on Solution>",
  "starter_code": "<full Java file: public class Solution {{ public static <T> entrypoint(...) {{ ... }} }} — use static method only, no main>",
  "hints": ["<hint1>", "<hint2>"],
  "tests": [
    {{"args": [<JSON positional args>], "expected": <JSON literal>}}
  ]
}}

Rules:
- Class MUST be `public class Solution`.
- Method MUST be `public static` and named exactly `entrypoint`.
- Use only java.lang / java.util (List.of, etc.). No external libraries.
- 4–6 tests; `expected` and `args` must be JSON types mappable to Java (primitives, strings, lists of JSON values).
- Keep starter_code under 120 lines.
""",
}


def normalize_coding_language(raw: str | None) -> str:
    s = (raw or "python").strip().lower()
    aliases = {
        "py": "python",
        "js": "javascript",
        "node": "javascript",
        "ts": "javascript",
        "c++": "cpp",
        "cxx": "cpp",
        "gcc": "c",
    }
    s = aliases.get(s, s)
    if s not in CODING_LANGUAGES:
        return "python"
    return s


def _parse_problem_payload(raw: str) -> dict[str, Any] | None:
    """Parse LLM JSON with repair (unescaped newlines, trailing commas, fences)."""
    from deeptutor.utils.json_parser import parse_json_response

    parsed = parse_json_response(raw, fallback=None)
    if isinstance(parsed, dict):
        return parsed
    return None


def _validate_tests_common(tests_raw: Any) -> list[dict[str, Any]] | None:
    if not isinstance(tests_raw, list) or len(tests_raw) < 3:
        return None
    tests: list[dict[str, Any]] = []
    for row in tests_raw[:8]:
        if not isinstance(row, dict):
            return None
        if "args" not in row or "expected" not in row:
            return None
        args = row["args"]
        if not isinstance(args, list) or len(args) > 8:
            return None
        tests.append({"args": args, "expected": row["expected"]})
    return tests


def _c_int_ok(v: Any) -> bool:
    return isinstance(v, (int, bool))


def _validate_python(payload: dict[str, Any]) -> dict[str, Any] | None:
    title = str(payload.get("title") or "").strip()
    desc = str(payload.get("description") or "").strip()
    entry = str(payload.get("entrypoint") or "").strip()
    starter = str(payload.get("starter_code") or "").strip()
    hints_raw = payload.get("hints") or []
    tests = _validate_tests_common(payload.get("tests"))
    if tests is None or not title or not desc or not entry or not starter:
        return None
    if not _IDENT.match(entry):
        return None
    if f"def {entry}" not in starter and f"def {entry}(" not in starter:
        return None
    if not isinstance(hints_raw, list):
        return None
    hints = [str(h).strip() for h in hints_raw if str(h).strip()][:4]
    return {
        "title": title,
        "description": desc,
        "entrypoint": entry,
        "starter_code": starter,
        "hints": hints,
        "tests": tests,
    }


def _validate_javascript(payload: dict[str, Any]) -> dict[str, Any] | None:
    title = str(payload.get("title") or "").strip()
    desc = str(payload.get("description") or "").strip()
    entry = str(payload.get("entrypoint") or "").strip()
    starter = str(payload.get("starter_code") or "").strip()
    hints_raw = payload.get("hints") or []
    tests = _validate_tests_common(payload.get("tests"))
    if tests is None or not title or not desc or not entry or not starter:
        return None
    if not _IDENT.match(entry):
        return None
    if not re.search(rf"export\s+function\s+{re.escape(entry)}\s*\(", starter):
        from deeptutor.services.coding_practice.native_runner import _ensure_js_export

        starter = _ensure_js_export(starter, entry)
    if not re.search(rf"export\s+function\s+{re.escape(entry)}\s*\(", starter):
        return None
    if not isinstance(hints_raw, list):
        return None
    hints = [str(h).strip() for h in hints_raw if str(h).strip()][:4]
    return {
        "title": title,
        "description": desc,
        "entrypoint": entry,
        "starter_code": starter,
        "hints": hints,
        "tests": tests,
    }


def _validate_c_family(payload: dict[str, Any], *, lang: str) -> dict[str, Any] | None:
    title = str(payload.get("title") or "").strip()
    desc = str(payload.get("description") or "").strip()
    entry = str(payload.get("entrypoint") or "").strip()
    starter = str(payload.get("starter_code") or "").strip()
    hints_raw = payload.get("hints") or []
    tests = _validate_tests_common(payload.get("tests"))
    if tests is None or not title or not desc or not entry or not starter:
        return None
    if not _IDENT.match(entry):
        return None
    if "main(" in starter.replace(" ", "").lower():
        return None
    if f"{entry}(" not in starter:
        return None
    for t in tests:
        if not _c_int_ok(t.get("expected")):
            return None
        for a in t.get("args") or []:
            if not _c_int_ok(a):
                return None
    if not isinstance(hints_raw, list):
        return None
    hints = [str(h).strip() for h in hints_raw if str(h).strip()][:4]
    return {
        "title": title,
        "description": desc,
        "entrypoint": entry,
        "starter_code": starter,
        "hints": hints,
        "tests": tests,
    }


def _validate_java(payload: dict[str, Any]) -> dict[str, Any] | None:
    title = str(payload.get("title") or "").strip()
    desc = str(payload.get("description") or "").strip()
    entry = str(payload.get("entrypoint") or "").strip()
    starter = str(payload.get("starter_code") or "").strip()
    hints_raw = payload.get("hints") or []
    tests = _validate_tests_common(payload.get("tests"))
    if tests is None or not title or not desc or not entry or not starter:
        return None
    if not _IDENT.match(entry):
        return None
    if "class Solution" not in starter:
        return None
    if not re.search(r"public\s+static", starter):
        return None
    if f"{entry}(" not in starter:
        return None
    if not isinstance(hints_raw, list):
        return None
    hints = [str(h).strip() for h in hints_raw if str(h).strip()][:4]
    return {
        "title": title,
        "description": desc,
        "entrypoint": entry,
        "starter_code": starter,
        "hints": hints,
        "tests": tests,
    }


def _validate_payload(payload: Any, *, language: str) -> dict[str, Any] | None:
    if not isinstance(payload, dict):
        return None
    if language == "python":
        return _validate_python(payload)
    if language == "javascript":
        return _validate_javascript(payload)
    if language in {"c", "cpp"}:
        return _validate_c_family(payload, lang=language)
    if language == "java":
        return _validate_java(payload)
    return None


# Set on problems served from _OFFLINE_BANKS when the LLM is unavailable.
OFFLINE_GENERATION_FLAG = "offline"


def _stable_index(seed: str, modulo: int) -> int:
    if modulo <= 0:
        return 0
    h = int(hashlib.sha256(seed.encode("utf-8")).hexdigest(), 16)
    return h % modulo


# Curated problems used when the LLM is unavailable (rate limits, outages, invalid JSON).
_OFFLINE_BANKS: dict[str, list[dict[str, Any]]] = {
    "python": [
        {
            "title": "Find Missing Number",
            "description": (
                "Given a list of **n − 1** distinct integers from **1** through **n**, "
                "find and return the single missing integer."
            ),
            "entrypoint": "find_missing_number",
            "starter_code": (
                "def find_missing_number(nums):\n"
                '    """Return the missing integer in 1..n."""\n'
                "    pass\n"
            ),
            "hints": [
                "Compare the sum 1 + 2 + … + n to the sum of nums.",
            ],
            "tests": [
                {"args": [[1, 2, 4, 5]], "expected": 3},
                {"args": [[1, 3]], "expected": 2},
                {"args": [[2]], "expected": 1},
                {"args": [[1, 2, 3, 5]], "expected": 4},
            ],
        },
        {
            "title": "Two Sum Indices",
            "description": (
                "Given a list of integers `nums` and an integer `target`, return **two distinct "
                "indices** `i` and `j` (with `i < j`) such that `nums[i] + nums[j] == target`. "
                "Assume exactly one solution exists."
            ),
            "entrypoint": "two_sum",
            "starter_code": (
                "def two_sum(nums, target):\n"
                '    """Return [i, j] with i < j and nums[i] + nums[j] == target."""\n'
                "    pass\n"
            ),
            "hints": [
                "A hash map from value to index avoids an O(n²) scan.",
            ],
            "tests": [
                {"args": [[2, 7, 11, 15], 9], "expected": [0, 1]},
                {"args": [[3, 2, 4], 6], "expected": [1, 2]},
                {"args": [[3, 3], 6], "expected": [0, 1]},
                {"args": [[0, 4, 3, 0], 0], "expected": [0, 3]},
            ],
        },
        {
            "title": "Maximum Subarray Sum",
            "description": (
                "Given a non-empty list of integers (positive and negative), return the **largest** "
                "possible sum of a contiguous subarray."
            ),
            "entrypoint": "max_subarray_sum",
            "starter_code": (
                "def max_subarray_sum(nums):\n"
                '    """Kadane-style: maximum sum of a contiguous subarray."""\n'
                "    pass\n"
            ),
            "hints": [
                "Track the best sum ending at the current position.",
            ],
            "tests": [
                {"args": [[-2, 1, -3, 4, -1, 2, 1, -5, 4]], "expected": 6},
                {"args": [[1]], "expected": 1},
                {"args": [[5, 4, -1, 7, 8]], "expected": 23},
                {"args": [[-1, -2]], "expected": -1},
            ],
        },
        {
            "title": "Fibonacci Number",
            "description": (
                "Given a non-negative integer `n`, return the **n-th Fibonacci number** `F(n)` "
                "with `F(0) = 0`, `F(1) = 1`."
            ),
            "entrypoint": "fib",
            "starter_code": (
                "def fib(n):\n"
                '    """Return F(n) for F(0)=0, F(1)=1."""\n'
                "    pass\n"
            ),
            "hints": [
                "Iterative O(n) avoids exponential recursion.",
            ],
            "tests": [
                {"args": [0], "expected": 0},
                {"args": [1], "expected": 1},
                {"args": [10], "expected": 55},
                {"args": [20], "expected": 6765},
            ],
        },
        {
            "title": "Contains Duplicate",
            "description": (
                "Given a list of integers `nums`, return **True** if any value appears **at least twice**, "
                "otherwise **False**."
            ),
            "entrypoint": "contains_duplicate",
            "starter_code": (
                "def contains_duplicate(nums):\n"
                '    """Return True if nums has a duplicate."""\n'
                "    pass\n"
            ),
            "hints": [
                "A set of seen values answers this in linear time.",
            ],
            "tests": [
                {"args": [[1, 2, 3, 1]], "expected": True},
                {"args": [[1, 2, 3, 4]], "expected": False},
                {"args": [[1, 1]], "expected": True},
                {"args": [[]], "expected": False},
            ],
        },
        {
            "title": "Reverse Words",
            "description": (
                "Given a string `s` with words separated by single spaces, return a string with the "
                "**same words in reverse order** (words themselves are not reversed)."
            ),
            "entrypoint": "reverse_words",
            "starter_code": (
                "def reverse_words(s):\n"
                '    """Reverse order of whitespace-separated words in s."""\n'
                "    pass\n"
            ),
            "hints": [
                "Split on spaces, reverse the list, join with a single space.",
            ],
            "tests": [
                {"args": ["the sky is blue"], "expected": "blue is sky the"},
                {"args": ["hello"], "expected": "hello"},
                {"args": ["a b c"], "expected": "c b a"},
                {"args": ["alpha beta gamma"], "expected": "gamma beta alpha"},
            ],
        },
        {
            "title": "Is Anagram",
            "description": (
                "Given two strings `s` and `t`, return **True** if `t` is an anagram of `s`, "
                "otherwise **False**."
            ),
            "entrypoint": "is_anagram",
            "starter_code": (
                "def is_anagram(s, t):\n"
                '    """Return True if t is an anagram of s."""\n'
                "    pass\n"
            ),
            "hints": [
                "Count character frequencies in both strings.",
            ],
            "tests": [
                {"args": ["listen", "silent"], "expected": True},
                {"args": ["rat", "car"], "expected": False},
                {"args": ["a", "a"], "expected": True},
                {"args": ["ab", "ba"], "expected": True},
            ],
        },
        {
            "title": "Palindrome Check",
            "description": (
                "Given a string `s`, return **True** if it is a palindrome, otherwise **False**."
            ),
            "entrypoint": "is_palindrome",
            "starter_code": (
                "def is_palindrome(s):\n"
                '    """Return True if s reads the same forwards and backwards."""\n'
                "    pass\n"
            ),
            "hints": [
                "Compare the string to its reverse.",
            ],
            "tests": [
                {"args": ["racecar"], "expected": True},
                {"args": ["hello"], "expected": False},
                {"args": ["a"], "expected": True},
                {"args": ["ab"], "expected": False},
            ],
        },
        {
            "title": "Factorial",
            "description": (
                "Given a non-negative integer `n`, return the factorial of `n`."
            ),
            "entrypoint": "factorial",
            "starter_code": (
                "def factorial(n):\n"
                '    """Return n! (factorial of n)."""\n'
                "    pass\n"
            ),
            "hints": [
                "Iterative approach: multiply from 1 to n.",
            ],
            "tests": [
                {"args": [0], "expected": 1},
                {"args": [5], "expected": 120},
                {"args": [3], "expected": 6},
                {"args": [7], "expected": 5040},
            ],
        },
        {
            "title": "Count Vowels",
            "description": (
                "Given a string `s`, return the number of vowels (a, e, i, o, u) in it."
            ),
            "entrypoint": "count_vowels",
            "starter_code": (
                "def count_vowels(s):\n"
                '    """Return the count of vowels in s."""\n'
                "    pass\n"
            ),
            "hints": [
                "Iterate through the string and check each character.",
            ],
            "tests": [
                {"args": ["hello"], "expected": 2},
                {"args": ["world"], "expected": 1},
                {"args": ["aeiou"], "expected": 5},
                {"args": ["xyz"], "expected": 0},
            ],
        },
    ],
    "javascript": [
        {
            "title": "Sum of Array",
            "description": (
                "Given an array of numbers `nums`, return the **sum** of all elements. "
                "An empty array should sum to **0**."
            ),
            "entrypoint": "arraySum",
            "starter_code": (
                "export function arraySum(nums) {\n"
                "  // Return the sum of nums (empty → 0)\n"
                "  return 0;\n"
                "}\n"
            ),
            "hints": [
                "Use a simple loop or reduce.",
            ],
            "tests": [
                {"args": [[1, 2, 3]], "expected": 6},
                {"args": [[]], "expected": 0},
                {"args": [[-1, 1]], "expected": 0},
                {"args": [[10, 20, 30]], "expected": 60},
            ],
        },
        {
            "title": "Max Value in Array",
            "description": "Given a non-empty array of numbers, return the **maximum** element.",
            "entrypoint": "arrayMax",
            "starter_code": (
                "export function arrayMax(nums) {\n"
                "  // Return the largest number in nums\n"
                "  return nums[0];\n"
                "}\n"
            ),
            "hints": ["Track the best value while scanning the array."],
            "tests": [
                {"args": [[3, 1, 4, 1, 5]], "expected": 5},
                {"args": [[-2, -1]], "expected": -1},
                {"args": [[7]], "expected": 7},
                {"args": [[0, 0, 0]], "expected": 0},
            ],
        },
        {
            "title": "Reverse String",
            "description": "Given a string `s`, return the string reversed.",
            "entrypoint": "reverseString",
            "starter_code": (
                "export function reverseString(s) {\n"
                "  // Return the reversed string\n"
                "  return s;\n"
                "}\n"
            ),
            "hints": ["Split into array, reverse, then join."],
            "tests": [
                {"args": ["hello"], "expected": "olleh"},
                {"args": ["world"], "expected": "dlrow"},
                {"args": ["a"], "expected": "a"},
                {"args": [""], "expected": ""},
            ],
        },
        {
            "title": "Count Even Numbers",
            "description": "Given an array of numbers, return the count of even numbers.",
            "entrypoint": "countEven",
            "starter_code": (
                "export function countEven(nums) {\n"
                "  // Return count of even numbers\n"
                "  return 0;\n"
                "}\n"
            ),
            "hints": ["Use modulo operator to check if number is even."],
            "tests": [
                {"args": [[1, 2, 3, 4, 5]], "expected": 2},
                {"args": [[2, 4, 6, 8]], "expected": 4},
                {"args": [[1, 3, 5]], "expected": 0},
                {"args": [[]], "expected": 0},
            ],
        },
    ],
    "c": [
        {
            "title": "Add Two Integers",
            "description": "Implement `add` so it returns the sum of integers `a` and `b`.",
            "entrypoint": "add",
            "starter_code": (
                "#include <stddef.h>\n"
                "int add(int a, int b) {\n"
                "    return 0;\n"
                "}\n"
            ),
            "hints": ["Return a + b."],
            "tests": [
                {"args": [1, 2], "expected": 3},
                {"args": [-1, 1], "expected": 0},
                {"args": [100, 200], "expected": 300},
                {"args": [0, 0], "expected": 0},
            ],
        },
        {
            "title": "Absolute Difference",
            "description": "Return the absolute difference `|a - b|` for two integers.",
            "entrypoint": "abs_diff",
            "starter_code": (
                "#include <stdlib.h>\n"
                "int abs_diff(int a, int b) {\n"
                "    return 0;\n"
                "}\n"
            ),
            "hints": ["Use conditional or stdlib abs if available."],
            "tests": [
                {"args": [5, 2], "expected": 3},
                {"args": [2, 5], "expected": 3},
                {"args": [-1, -4], "expected": 3},
                {"args": [0, 0], "expected": 0},
            ],
        },
        {
            "title": "Multiply Two Integers",
            "description": "Return the product of integers `a` and `b`.",
            "entrypoint": "multiply",
            "starter_code": (
                "int multiply(int a, int b) {\n"
                "    return 0;\n"
                "}\n"
            ),
            "hints": ["Return a * b."],
            "tests": [
                {"args": [3, 4], "expected": 12},
                {"args": [-2, 5], "expected": -10},
                {"args": [0, 99], "expected": 0},
                {"args": [7, 7], "expected": 49},
            ],
        },
        {
            "title": "Maximum of Two",
            "description": "Return the larger of two integers.",
            "entrypoint": "max_of_two",
            "starter_code": (
                "int max_of_two(int a, int b) {\n"
                "    return 0;\n"
                "}\n"
            ),
            "hints": ["Use conditional to compare a and b."],
            "tests": [
                {"args": [5, 3], "expected": 5},
                {"args": [2, 8], "expected": 8},
                {"args": [-1, -4], "expected": -1},
                {"args": [7, 7], "expected": 7},
            ],
        },
    ],
    "cpp": [
        {
            "title": "Add Two Integers",
            "description": "Implement `add` so it returns the sum of integers `a` and `b`.",
            "entrypoint": "add",
            "starter_code": "int add(int a, int b) {\n    return 0;\n}\n",
            "hints": ["Return a + b."],
            "tests": [
                {"args": [1, 2], "expected": 3},
                {"args": [-1, 1], "expected": 0},
                {"args": [100, 200], "expected": 300},
                {"args": [0, 0], "expected": 0},
            ],
        },
        {
            "title": "Multiply Two Integers",
            "description": "Return the product of integers `a` and `b`.",
            "entrypoint": "multiply",
            "starter_code": (
                "int multiply(int a, int b) {\n"
                "    return 0;\n"
                "}\n"
            ),
            "hints": ["Return a * b."],
            "tests": [
                {"args": [3, 4], "expected": 12},
                {"args": [-2, 5], "expected": -10},
                {"args": [0, 99], "expected": 0},
                {"args": [7, 7], "expected": 49},
            ],
        },
        {
            "title": "Subtract Two Integers",
            "description": "Return `a - b` for two integers.",
            "entrypoint": "subtract",
            "starter_code": (
                "int subtract(int a, int b) {\n"
                "    return 0;\n"
                "}\n"
            ),
            "hints": ["Return a minus b."],
            "tests": [
                {"args": [5, 3], "expected": 2},
                {"args": [3, 5], "expected": -2},
                {"args": [-1, -1], "expected": 0},
                {"args": [0, 7], "expected": -7},
            ],
        },
        {
            "title": "Maximum of Two",
            "description": "Return the larger of two integers.",
            "entrypoint": "max_of_two",
            "starter_code": (
                "int max_of_two(int a, int b) {\n"
                "    return 0;\n"
                "}\n"
            ),
            "hints": ["Use conditional to compare a and b."],
            "tests": [
                {"args": [5, 3], "expected": 5},
                {"args": [2, 8], "expected": 8},
                {"args": [-1, -4], "expected": -1},
                {"args": [7, 7], "expected": 7},
            ],
        },
    ],
    "java": [
        {
            "title": "Add Two Integers",
            "description": "Implement `add` so it returns the sum of integers `a` and `b`.",
            "entrypoint": "add",
            "starter_code": (
                "public class Solution {\n"
                "    public static int add(int a, int b) {\n"
                "        return 0;\n"
                "    }\n"
                "}\n"
            ),
            "hints": ["Return a + b."],
            "tests": [
                {"args": [1, 2], "expected": 3},
                {"args": [-1, 1], "expected": 0},
                {"args": [100, 200], "expected": 300},
                {"args": [0, 0], "expected": 0},
            ],
        },
        {
            "title": "Subtract Two Integers",
            "description": "Return `a - b` for two integers.",
            "entrypoint": "subtract",
            "starter_code": (
                "public class Solution {\n"
                "    public static int subtract(int a, int b) {\n"
                "        return 0;\n"
                "    }\n"
                "}\n"
            ),
            "hints": ["Return a minus b."],
            "tests": [
                {"args": [5, 3], "expected": 2},
                {"args": [3, 5], "expected": -2},
                {"args": [-1, -1], "expected": 0},
                {"args": [0, 7], "expected": -7},
            ],
        },
        {
            "title": "Multiply Two Integers",
            "description": "Return the product of integers `a` and `b`.",
            "entrypoint": "multiply",
            "starter_code": (
                "public class Solution {\n"
                "    public static int multiply(int a, int b) {\n"
                "        return 0;\n"
                "    }\n"
                "}\n"
            ),
            "hints": ["Return a * b."],
            "tests": [
                {"args": [3, 4], "expected": 12},
                {"args": [-2, 5], "expected": -10},
                {"args": [0, 99], "expected": 0},
                {"args": [7, 7], "expected": 49},
            ],
        },
        {
            "title": "Maximum of Two",
            "description": "Return the larger of two integers.",
            "entrypoint": "maxOfTwo",
            "starter_code": (
                "public class Solution {\n"
                "    public static int maxOfTwo(int a, int b) {\n"
                "        return 0;\n"
                "    }\n"
                "}\n"
            ),
            "hints": ["Use conditional to compare a and b."],
            "tests": [
                {"args": [5, 3], "expected": 5},
                {"args": [2, 8], "expected": 8},
                {"args": [-1, -4], "expected": -1},
                {"args": [7, 7], "expected": 7},
            ],
        },
    ],
}


def _finalize_starter(row: dict[str, Any], lang: str) -> dict[str, Any]:
    """Normalize starter source so run/submit harnesses accept learner edits."""
    from deeptutor.services.coding_practice.native_runner import prepare_user_code

    ep = str(row.get("entrypoint") or "").strip()
    row = dict(row)
    row["starter_code"] = prepare_user_code(
        str(row.get("starter_code") or ""),
        language=lang,
        entrypoint=ep,
    )
    return row


def _offline_problem(
    lang: str,
    topic: str,
    difficulty: str,
    *,
    refresh_token: str | None = None,
) -> dict[str, Any]:
    bank = _OFFLINE_BANKS.get(lang) or _OFFLINE_BANKS["python"]
    if not bank:
        logger.warning("No offline bank available for language %s, falling back to python", lang)
        bank = _OFFLINE_BANKS["python"]
    seed = f"{lang}:{topic}:{difficulty}"
    if refresh_token:
        seed = f"{seed}:{refresh_token}"
    idx = _stable_index(seed, len(bank))
    row = dict(bank[idx])
    row["topic"] = topic
    row["difficulty"] = difficulty
    row["language"] = lang
    row["problem_id"] = f"cp_off_{uuid.uuid4().hex[:14]}"
    row[OFFLINE_GENERATION_FLAG] = True
    logger.info("Code lab: serving offline problem %s (lang=%s, topic=%s, diff=%s)", row["title"], lang, topic, difficulty)
    return _finalize_starter(row, lang)


def _resolve_coding_practice_model() -> str:
    """Model id for Code lab generation (same structured defaults as Practice on Groq/OpenAI)."""
    from deeptutor.services.llm.config import get_llm_config

    pin = (os.getenv("LLM_MODEL_CODING_PRACTICE") or os.getenv("LLM_MODEL_PRACTICE") or "").strip()
    if pin:
        return pin

    # Default to a more capable model for coding practice
    # Using llama-3.1-70b-versatile for better code generation
    default_model = "llama-3.1-70b-versatile"
    
    router = get_model_router()
    routed = router.route_feature("practice_coding", intent=Intent.CODING)
    llm_cfg = get_llm_config()

    if routed.api_key:
        return routed.model

    if router.model_for_feature("practice_coding"):
        return routed.model

    d = default_structured_output_model(llm_cfg.base_url, llm_cfg.effective_url)
    if d:
        return d

    # Use the default model if nothing else is configured
    return default_model


async def _ask_llm(
    prompt: str,
    *,
    max_tokens: int,
    language: str,
    force_model: str | None = None,
) -> str:
    from deeptutor.services.llm import complete as llm_complete
    from deeptutor.services.llm.config import get_llm_config

    router = get_model_router()
    routed = router.route_feature("practice_coding", intent=Intent.CODING)
    llm_cfg = get_llm_config()
    api_key = routed.api_key or llm_cfg.api_key
    base_url = routed.api_base if routed.api_key else (llm_cfg.base_url or routed.api_base)
    model = force_model if force_model is not None else _resolve_coding_practice_model()
    sys = (
        "You are an expert coding interviewer. Respond with a single valid JSON object — "
        "no markdown fences, no prose outside JSON."
    )
    if language != "python":
        sys += f" Target language: {language}."
    return await llm_complete(
        prompt=prompt,
        system_prompt=sys,
        model=model,
        api_key=api_key,
        base_url=base_url,
        temperature=0.42,
        max_tokens=max_tokens,
    )


async def generate_problem(
    *,
    topic: str | None,
    difficulty: str | None,
    language: str | None = None,
    refresh_nonce: str | None = None,
) -> dict[str, Any]:
    """Return a validated problem dict (not yet cached).

    On LLM failure (rate limits, invalid JSON, validation errors), returns a
    deterministic **offline** problem from a small curated bank so the Code lab
    stays usable.
    """
    lang = normalize_coding_language(language)
    t = (topic or "algorithms").strip().lower()
    if not t:
        t = "algorithms"
    diff = (difficulty or "medium").strip().lower()
    if diff not in {"easy", "medium", "hard"}:
        diff = "medium"
    
    # Check if LLM is disabled via environment variable
    use_llm = os.getenv("CODE_LAB_DISABLE_LLM", "").strip().lower() != "1"
    
    if not use_llm:
        logger.info("Code lab: LLM generation disabled, using offline fallback")
        return _offline_problem(lang, t, diff, refresh_token=refresh_nonce)
    
    prompt_template = _PROMPTS.get(lang) or _PROMPTS["python"]
    prompt = prompt_template.format(topic=t, difficulty=diff)
    from deeptutor.services.llm.rate_limit_fallback import (
        looks_like_rate_or_quota_error,
        rate_limit_fallback_model,
    )

    primary = _resolve_coding_practice_model()
    fb = rate_limit_fallback_model(primary)
    candidates = [primary]
    if fb and fb != primary:
        candidates.append(fb)

    last_err: str | None = None
    for model_id in candidates:
        for attempt in (1, 2):
            try:
                raw = await _ask_llm(
                    prompt,
                    max_tokens=4200 if lang != "python" else 3600,
                    language=lang,
                    force_model=model_id,
                )
            except Exception as exc:
                last_err = str(exc)
                logger.warning(
                    "coding practice LLM fail model=%r attempt=%s: %s",
                    model_id,
                    attempt,
                    exc,
                )
                if attempt < 2:
                    await asyncio.sleep(0.2)
                continue

            parsed = _parse_problem_payload(raw)
            if parsed is None:
                last_err = "Model returned invalid JSON"
                logger.warning(
                    "coding practice parse fail model=%r attempt=%s",
                    model_id,
                    attempt,
                )
                if attempt < 2:
                    await asyncio.sleep(0.2)
                continue

            ok = _validate_payload(parsed, language=lang)
            if ok is None:
                last_err = "Model output failed validation"
                logger.warning(
                    "coding practice validation fail model=%r attempt=%s",
                    model_id,
                    attempt,
                )
                if attempt < 2:
                    await asyncio.sleep(0.2)
                continue

            ok["topic"] = t
            ok["difficulty"] = diff
            ok["language"] = lang
            ok["problem_id"] = f"cp_{uuid.uuid4().hex[:16]}"
            return _finalize_starter(ok, lang)

        if (
            model_id == primary
            and fb
            and fb != primary
            and looks_like_rate_or_quota_error(last_err or "")
        ):
            logger.info(
                "Code lab: retrying with fallback model %r after limit on %r",
                fb,
                primary,
            )
            continue
        break

    logger.warning(
        "coding practice: LLM generation failed (%s); serving offline fallback",
        last_err,
    )
    return _offline_problem(lang, t, diff, refresh_token=refresh_nonce)


__all__ = [
    "CODING_LANGUAGES",
    "OFFLINE_GENERATION_FLAG",
    "generate_problem",
    "normalize_coding_language",
]
