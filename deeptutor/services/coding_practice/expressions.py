"""JSON values → language literals for generated compile harnesses (C++, Java)."""

from __future__ import annotations

import json
from typing import Any

_MAX_DEPTH = 14


def cpp_literal(value: Any, *, depth: int = 0) -> str:
    if depth > _MAX_DEPTH:
        raise ValueError("nesting too deep for C++ literal")
    if value is None:
        raise TypeError("null is not supported for C++ literals in Code lab")
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        r = repr(float(value))
        if r.lower() in {"inf", "-inf", "nan"}:
            return "0.0"
        return r if "e" in r.lower() or "." in r else f"{r}.0"
    if isinstance(value, str):
        esc = json.dumps(value, ensure_ascii=False)
        return f"std::string({esc})"
    if isinstance(value, (list, tuple)):
        if not value:
            return "std::vector<int>{}"
        if all(isinstance(x, int) for x in value):
            inner = ", ".join(str(int(x)) for x in value)
            return f"std::vector<int>{{{inner}}}"
        if all(isinstance(x, str) for x in value):
            inner = ", ".join(cpp_literal(x, depth=depth + 1) for x in value)
            return f"std::vector<std::string>{{{inner}}}"
        parts = [cpp_literal(x, depth=depth + 1) for x in value]
        inner = ", ".join(parts)
        return f"std::vector<decltype({parts[0]})>{{{inner}}}"
    raise TypeError(f"unsupported JSON type for C++ literal: {type(value).__name__}")


def java_literal(value: Any, *, depth: int = 0) -> str:
    if depth > _MAX_DEPTH:
        raise ValueError("nesting too deep for Java literal")
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        if abs(value) > 2_147_483_647:
            return f"{int(value)}L"
        return str(int(value))
    if isinstance(value, float):
        r = float(value)
        if str(r).lower() in {"inf", "-inf", "nan"}:
            return "0.0d"
        return repr(r) + "d"
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, (list, tuple)):
        if not value:
            return "java.util.List.of()"
        parts = [java_literal(x, depth=depth + 1) for x in value]
        return "java.util.List.of(" + ", ".join(parts) + ")"
    raise TypeError(f"unsupported JSON type for Java literal: {type(value).__name__}")


def c_int_literal(value: Any) -> str:
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, int):
        return str(int(value))
    raise TypeError("C harness supports int/bool arguments and int expected values only")


def assert_c_int_json(v: Any) -> None:
    if isinstance(v, bool):
        return
    if isinstance(v, int):
        return
    raise TypeError("C harness requires int/bool scalars only")


__all__ = ["assert_c_int_json", "c_int_literal", "cpp_literal", "java_literal"]
