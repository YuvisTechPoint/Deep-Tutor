"""Normalize malformed function/tool invocations from LLM outputs.

Some models (e.g. Llama 3.3 on Groq) occasionally emit legacy pseudo-syntax such
as ``rag{'query': '...'}`` as the *function name* instead of name ``rag`` plus a
JSON ``arguments`` object. Strict OpenAI-compatible APIs reject that with
``tool_use_failed`` / "not in request.tools". We repair parsed tool calls before
execution and rely on streaming fallback when the provider rejects a turn.
"""

from __future__ import annotations

import ast
import re
from typing import Any


def normalize_tool_invocation(
    name: str,
    arguments: dict[str, Any] | None,
) -> tuple[str, dict[str, Any]]:
    """Return ``(canonical_name, merged_arguments)``."""
    args = dict(arguments) if isinstance(arguments, dict) else {}
    raw = (name or "").strip()
    if not raw:
        return raw, args

    n = raw
    # <function-rag{'kb_name': ...}> or <function-rag(...)>
    wrapped = re.match(r"^<\s*function\s*-(.+)>\s*$", n, re.IGNORECASE | re.DOTALL)
    if wrapped:
        n = wrapped.group(1).strip()

    # name{...python dict...}
    brace = n.find("{")
    if brace > 0:
        base = n[:brace].strip()
        tail = n[brace:]
        if _is_simple_tool_token(base) and tail.startswith("{") and tail.endswith("}"):
            parsed = _safe_literal_dict(tail)
            if parsed is not None:
                return base, {**args, **parsed}

    # name({...}) — outer parens only
    if "(" in n and n.endswith(")"):
        paren = n.index("(")
        base = n[:paren].strip()
        inner = n[paren + 1 : -1].strip()
        if _is_simple_tool_token(base) and inner.startswith("{") and inner.endswith("}"):
            parsed = _safe_literal_dict(inner)
            if parsed is not None:
                return base, {**args, **parsed}

    return raw, args


def _is_simple_tool_token(s: str) -> bool:
    return bool(s) and bool(re.fullmatch(r"[A-Za-z0-9_-]+", s))


def _safe_literal_dict(blob: str) -> dict[str, Any] | None:
    try:
        val = ast.literal_eval(blob)
    except (SyntaxError, ValueError, MemoryError):
        return None
    return val if isinstance(val, dict) else None
