"""Run learner code + tests (Python sandbox or native compile harness)."""

from __future__ import annotations

import ast
import json
import logging
from typing import Any

from deeptutor.services.coding_practice.generator import normalize_coding_language
from deeptutor.services.coding_practice.native_runner import (
    run_c_snippet,
    run_cpp_snippet,
    run_java_snippet,
    run_javascript_snippet,
    run_javascript_tests,
)
from deeptutor.services.coding_practice.native_runner import (
    run_c_tests as native_run_c_tests,
)
from deeptutor.services.coding_practice.native_runner import (
    run_cpp_tests as native_run_cpp_tests,
)
from deeptutor.services.coding_practice.native_runner import (
    run_java_tests as native_run_java_tests,
)
from deeptutor.tools.code_executor import run_code

logger = logging.getLogger(__name__)


def _is_name_main_guard(test: ast.AST) -> bool:
    """True for ``__name__ == "__main__"`` / ``"__main__" == __name__`` (module-level only)."""
    if not isinstance(test, ast.Compare) or len(test.ops) != 1 or not isinstance(test.ops[0], ast.Eq):
        return False
    if len(test.comparators) != 1:
        return False
    left, right = test.left, test.comparators[0]
    if isinstance(left, ast.Name) and left.id == "__name__":
        other = right
    elif isinstance(right, ast.Name) and right.id == "__name__":
        other = left
    else:
        return False
    return isinstance(other, ast.Constant) and other.value == "__main__"


def _prepare_python_for_coding_lab(code: str) -> str:
    """Strip scratch ``print`` / ``if __name__ == "__main__"`` so harness stdout stays parseable.

    Learners often paste LeetCode-style drivers; those run before the appended harness and can
    leave a misleading subprocess exit code even when the solution is correct.
    """
    raw = code.strip()
    if not raw:
        return raw
    try:
        tree = ast.parse(raw)
    except SyntaxError:
        return raw

    new_body: list[ast.stmt] = []
    for node in tree.body:
        if isinstance(node, ast.If) and _is_name_main_guard(node.test):
            continue
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
            fn = node.value.func
            if isinstance(fn, ast.Name) and fn.id == "print":
                continue
        new_body.append(node)

    if len(new_body) == len(tree.body):
        return raw
    if not new_body:
        return raw

    new_mod = ast.Module(body=new_body, type_ignores=getattr(tree, "type_ignores", []) or [])
    ast.fix_missing_locations(new_mod)
    return ast.unparse(new_mod).strip() + "\n"


def build_harness_script(user_code: str, entrypoint: str, tests: list[dict[str, Any]]) -> str:
    """Append a __main__ test driver that prints a JSON array of per-test results."""
    user_code = _prepare_python_for_coding_lab(user_code)
    specs = json.dumps(tests, ensure_ascii=False)
    tail = f'''

if __name__ == "__main__":
    import json
    _fn = globals()[{json.dumps(entrypoint)}]
    _specs = json.loads({json.dumps(specs)})
    _out = []
    for _i, _s in enumerate(_specs):
        try:
            _args = _s["args"]
            _exp = _s["expected"]
            _got = _fn(*_args)
            _ok = _got == _exp
            _out.append({{
                "ok": bool(_ok),
                "index": _i,
                "got": repr(_got),
                "expected": repr(_exp),
            }})
        except Exception as _e:
            _out.append({{"ok": False, "index": _i, "error": str(_e)}})
    print(json.dumps(_out))
'''
    return user_code.strip() + tail


async def run_user_snippet(code: str, *, language: str = "python", timeout: int = 8) -> dict[str, Any]:
    """Execute learner code only (syntax / quick feedback)."""
    lang = normalize_coding_language(language)
    if lang == "python":
        code = _prepare_python_for_coding_lab(code)
        return await run_code("python", code, timeout=timeout)
    if lang == "javascript":
        return await run_javascript_snippet(code, timeout=timeout)
    if lang == "c":
        return await run_c_snippet(code, timeout=timeout)
    if lang == "cpp":
        return await run_cpp_snippet(code, timeout=timeout)
    if lang == "java":
        return await run_java_snippet(code, timeout=timeout)
    return await run_code("python", code, timeout=timeout)


async def run_tests(
    user_code: str,
    *,
    entrypoint: str,
    tests: list[dict[str, Any]],
    language: str = "python",
    timeout: int = 12,
) -> dict[str, Any]:
    """Run full harness; parse printed JSON from stdout."""
    lang = normalize_coding_language(language)
    if lang == "javascript":
        return await run_javascript_tests(
            user_code, entrypoint=entrypoint, tests=tests, timeout=timeout
        )
    if lang == "c":
        return await native_run_c_tests(
            user_code, entrypoint=entrypoint, tests=tests, timeout=timeout
        )
    if lang == "cpp":
        return await native_run_cpp_tests(
            user_code, entrypoint=entrypoint, tests=tests, timeout=timeout
        )
    if lang == "java":
        return await native_run_java_tests(
            user_code, entrypoint=entrypoint, tests=tests, timeout=timeout
        )

    script = build_harness_script(user_code, entrypoint, tests)
    result = await run_code("python", script, timeout=timeout)
    elapsed_ms = float(result.get("elapsed_ms") or 0.0)
    stdout = (result.get("stdout") or "").strip()
    stderr = result.get("stderr") or ""
    exit_code = int(result.get("exit_code") or -1)
    rows: list[dict[str, Any]] = []
    try:
        for line in reversed(stdout.splitlines()):
            line = line.strip()
            if line.startswith("["):
                parsed = json.loads(line)
                if isinstance(parsed, list):
                    rows = parsed
                break
    except Exception as exc:
        logger.warning("harness parse: %s stdout=%r", exc, stdout[:500])
        rows = []

    if not rows:
        return {
            "ok": False,
            "exit_code": exit_code,
            "stderr": stderr or "Could not parse test results from harness output.",
            "stdout": stdout,
            "tests": [],
            "elapsed_ms": elapsed_ms,
        }

    dict_rows = [r for r in rows if isinstance(r, dict)]
    if not dict_rows:
        return {
            "ok": False,
            "exit_code": exit_code,
            "stderr": stderr or "Harness returned no structured test rows.",
            "stdout": stdout,
            "tests": rows,
            "elapsed_ms": elapsed_ms,
        }

    all_ok = all(bool(r.get("ok")) for r in dict_rows)
    out_exit = 0 if all_ok else (exit_code if exit_code != 0 else 1)
    return {
        "ok": all_ok,
        "exit_code": out_exit,
        "stderr": stderr,
        "stdout": stdout,
        "tests": rows,
        "elapsed_ms": elapsed_ms,
    }


__all__ = ["build_harness_script", "run_tests", "run_user_snippet"]
