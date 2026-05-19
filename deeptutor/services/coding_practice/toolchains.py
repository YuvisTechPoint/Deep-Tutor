"""Detect compilers/interpreters available for Code lab."""

from __future__ import annotations

from typing import Any

from fastapi import HTTPException

from deeptutor.services.coding_practice.generator import normalize_coding_language
from deeptutor.services.coding_practice.native_runner import (
    resolve_c_compiler,
    resolve_cpp_compiler,
    resolve_java_tools,
    resolve_node,
)


def _python_info() -> dict[str, Any]:
    import sys

    exe = sys.executable
    return {
        "available": bool(exe),
        "path": exe,
        "message": "Python runs in the sandboxed executor." if exe else "Python not found.",
    }


def get_toolchain_status() -> dict[str, Any]:
    """Per-language toolchain availability for the Code lab UI."""
    node = resolve_node()
    javac, java = resolve_java_tools()
    cc = resolve_c_compiler()
    cxx = resolve_cpp_compiler()

    langs: dict[str, dict[str, Any]] = {
        "python": _python_info(),
        "javascript": {
            "available": bool(node),
            "path": node,
            "message": (
                "Node.js is ready."
                if node
                else "Install Node.js 18+ and ensure `node` is on PATH (or set DEEPTUTOR_NODE)."
            ),
        },
        "c": {
            "available": bool(cc),
            "path": cc,
            "message": (
                "C compiler is ready (gcc/clang)."
                if cc
                else (
                    "Install gcc or LLVM/Clang (MSYS2 MinGW-w64 on Windows) or set DEEPTUTOR_CC "
                    "to the full path of gcc.exe / clang.exe."
                )
            ),
        },
        "cpp": {
            "available": bool(cxx),
            "path": cxx,
            "message": (
                "C++ compiler is ready (g++/clang++)."
                if cxx
                else (
                    "Install g++ or LLVM (MSYS2 MinGW-w64 on Windows) or set DEEPTUTOR_CXX "
                    "to the full path of g++.exe / clang++.exe."
                )
            ),
        },
        "java": {
            "available": bool(javac and java),
            "path": javac,
            "java_path": java,
            "message": (
                "JDK is ready (javac/java)."
                if javac and java
                else (
                    "Install JDK 17+ and add `javac` and `java` to PATH, or set JAVA_HOME "
                    "(or DEEPTUTOR_JAVAC / DEEPTUTOR_JAVA)."
                )
            ),
        },
    }
    return {"languages": langs}


def require_toolchain(language: str) -> None:
    """Raise HTTP 503 when the language runtime/compiler is missing."""
    lang = normalize_coding_language(language)
    if lang == "python":
        return
    info = get_toolchain_status()["languages"].get(lang) or {}
    if info.get("available"):
        return
    detail = str(info.get("message") or f"{lang} toolchain is not available on this server.")
    raise HTTPException(status_code=503, detail=detail)


__all__ = ["get_toolchain_status", "require_toolchain"]
