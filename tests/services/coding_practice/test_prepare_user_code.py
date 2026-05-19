"""User-code normalization before compile/run."""

from __future__ import annotations

from deeptutor.services.coding_practice.native_runner import (
    _ensure_java_solution,
    _ensure_js_export,
    _strip_c_family_main,
    prepare_user_code,
)


def test_ensure_js_export_function() -> None:
    src = "function add(a, b) { return a + b; }\n"
    out = _ensure_js_export(src, "add")
    assert "export function add" in out


def test_ensure_java_wraps_static_method() -> None:
    src = "public static int add(int a, int b) { return 0; }\n"
    out = _ensure_java_solution(src, "add")
    assert "class Solution" in out
    assert "add" in out


def test_strip_c_main() -> None:
    src = "int add(int a, int b) { return a + b; }\nint main(void) { return 0; }\n"
    out = _strip_c_family_main(src)
    assert "main" not in out
    assert "add" in out


def test_prepare_user_code_java() -> None:
    out = prepare_user_code(
        "public static int mul(int a, int b) { return a * b; }",
        language="java",
        entrypoint="mul",
    )
    assert "class Solution" in out
