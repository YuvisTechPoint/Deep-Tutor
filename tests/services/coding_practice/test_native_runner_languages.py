"""Language runner helpers (JS export, C++ harness selection)."""

from __future__ import annotations

from deeptutor.services.coding_practice import native_runner as nr


def test_ensure_js_export_adds_export_to_function() -> None:
    src = "function arraySum(nums) {\n  return 0;\n}\n"
    out = nr._ensure_js_export(src, "arraySum")
    assert "export function arraySum" in out


def test_ensure_js_export_keeps_existing_export() -> None:
    src = "export function arraySum(nums) { return 0; }\n"
    assert nr._ensure_js_export(src, "arraySum") == src


def test_tests_scalar_only_detects_arrays() -> None:
    assert nr._tests_scalar_only([{"args": [1, 2], "expected": 3}]) is True
    assert (
        nr._tests_scalar_only([{"args": [[1, 2, 3]], "expected": 6}]) is False
    )


def test_cpp_family_json_main_compiles_shape() -> None:
    src = nr._cpp_family_json_main(
        "arraySum",
        [{"args": [[1, 2, 3]], "expected": 6}],
    )
    assert "std::vector<int>" in src
    assert "arraySum" in src
    assert "json_repr" in src
