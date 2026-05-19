"""Compile-and-run harnesses for Code lab (Node, gcc, g++, javac).

Not a security sandbox: intended for local/dev use with toolchain on ``PATH``.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
from typing import Any

# Resource limits only available on Unix
try:
    import resource
    HAS_RESOURCE = True
except ImportError:
    HAS_RESOURCE = False

from deeptutor.services.coding_practice.expressions import (
    assert_c_int_json,
    c_int_literal,
    cpp_literal,
    java_literal,
)
from deeptutor.services.path_service import get_path_service

_IDENT = re.compile(r"^[a-zA-Z_][a-zA-Z0-9_]*$")

_JAVA_JSON_HELPERS = r"""
final class J {
  static String esc(String s) {
    StringBuilder b = new StringBuilder();
    for (int i = 0; i < s.length(); i++) {
      char c = s.charAt(i);
      switch (c) {
        case '\\': b.append("\\\\"); break;
        case '"': b.append("\\\""); break;
        case '\n': b.append("\\n"); break;
        case '\r': b.append("\\r"); break;
        case '\t': b.append("\\t"); break;
        default:
          if (c < 32) b.append(String.format("\\u%04x", (int) c));
          else b.append(c);
      }
    }
    return b.toString();
  }
  static String j(Object o) {
    if (o == null) return "null";
    if (o instanceof Boolean) return ((Boolean) o) ? "true" : "false";
    if (o instanceof Number) return o.toString();
    if (o instanceof String) return "\"" + esc((String) o) + "\"";
    if (o instanceof java.util.List) {
      java.util.List<?> l = (java.util.List<?>) o;
      StringBuilder b = new StringBuilder("[");
      for (int i = 0; i < l.size(); i++) {
        if (i > 0) b.append(',');
        b.append(j(l.get(i)));
      }
      return b.append(']').toString();
    }
    return "\"" + esc(String.valueOf(o)) + "\"";
  }
}
""".strip()


def _which(*names: str) -> str | None:
    for n in names:
        p = shutil.which(n)
        if p:
            return p
    return None


def _tool_from_env(*var_names: str) -> str | None:
    """Resolve a compiler/binary from env (full path or a name on ``PATH``)."""
    for var in var_names:
        raw = (os.environ.get(var) or "").strip().strip('"').strip("'")
        if not raw:
            continue
        candidate = Path(raw)
        if candidate.is_file():
            return str(candidate)
        found = shutil.which(raw)
        if found:
            return found
    return None


def _windows_compiler_search_dirs() -> list[Path]:
    roots: list[Path] = []
    for key in ("MINGW_PREFIX", "LLVM_HOME"):
        raw = (os.environ.get(key) or "").strip().strip('"').strip("'")
        if not raw:
            continue
        p = Path(raw)
        if p.is_dir():
            roots.append(p if p.name.lower() == "bin" else p / "bin")
    pf = os.environ.get("ProgramFiles")
    if pf:
        roots.append(Path(pf) / "LLVM" / "bin")
    pfx86 = os.environ.get("ProgramFiles(x86)")
    if pfx86:
        roots.append(Path(pfx86) / "LLVM" / "bin")
    # Typical MSYS2 / standalone MinGW layouts on Windows
    roots.extend(
        [
            Path(r"C:\msys64\mingw64\bin"),
            Path(r"C:\msys64\ucrt64\bin"),
            Path(r"C:\msys64\clang64\bin"),
            Path(r"C:\msys64\clangarm64\bin"),
            Path(r"C:\mingw64\bin"),
            Path(r"C:\TDM-GCC-64\bin"),
        ]
    )
    return roots


def resolve_c_compiler() -> str | None:
    """Find ``gcc`` or ``clang`` for Code lab (PATH, env overrides, common Windows installs)."""
    found = _tool_from_env("DEEPTUTOR_CC", "CP_CC", "CC")
    if found:
        return found
    w = _which("gcc", "clang")
    if w:
        return w
    if os.name == "nt":
        for d in _windows_compiler_search_dirs():
            for name in ("gcc.exe", "clang.exe"):
                p = d / name
                if p.is_file():
                    return str(p)
    return None


def resolve_cpp_compiler() -> str | None:
    """Find ``g++`` or ``clang++`` for Code lab."""
    found = _tool_from_env("DEEPTUTOR_CXX", "CP_CXX", "CXX")
    if found:
        return found
    w = _which("g++", "clang++")
    if w:
        return w
    if os.name == "nt":
        for d in _windows_compiler_search_dirs():
            for name in ("g++.exe", "clang++.exe"):
                p = d / name
                if p.is_file():
                    return str(p)
    return None


_C_COMPILER_ERR = (
    "C compiler (gcc or clang) not found. Add gcc/clang to PATH, install LLVM or "
    "MSYS2 MinGW-w64, or set DEEPTUTOR_CC to the full path of gcc.exe or clang.exe."
)
_CPP_COMPILER_ERR = (
    "C++ compiler (g++ or clang++) not found. Add g++/clang++ to PATH, install LLVM or "
    "MSYS2 MinGW-w64, or set DEEPTUTOR_CXX to the full path of g++.exe or clang++.exe."
)
_NODE_ERR = (
    "Node.js not found. Install Node.js 18+ or set DEEPTUTOR_NODE to the full path of node.exe."
)
_JAVA_ERR = (
    "JDK not found. Install JDK 17+, set JAVA_HOME, or set DEEPTUTOR_JAVAC / DEEPTUTOR_JAVA."
)


def resolve_node() -> str | None:
    found = _tool_from_env("DEEPTUTOR_NODE", "NODE")
    if found:
        return found
    w = _which("node")
    if w:
        return w
    if os.name == "nt":
        for base in (
            os.environ.get("ProgramFiles"),
            os.environ.get("ProgramFiles(x86)"),
            os.environ.get("LOCALAPPDATA"),
        ):
            if not base:
                continue
            for rel in (
                "nodejs/node.exe",
                "Programs/nodejs/node.exe",
            ):
                p = Path(base) / rel
                if p.is_file():
                    return str(p)
    return None


def _windows_jdk_bin_dirs() -> list[Path]:
    dirs: list[Path] = []
    for root_name in ("ProgramFiles", "ProgramFiles(x86)"):
        root = os.environ.get(root_name)
        if not root:
            continue
        java_root = Path(root) / "Java"
        if not java_root.is_dir():
            continue
        for jdk in sorted(java_root.glob("jdk*"), reverse=True):
            b = jdk / "bin"
            if b.is_dir():
                dirs.append(b)
    return dirs


def resolve_java_tools() -> tuple[str | None, str | None]:
    javac = _tool_from_env("DEEPTUTOR_JAVAC", "JAVAC")
    java = _tool_from_env("DEEPTUTOR_JAVA", "JAVA")
    java_home = (os.environ.get("JAVA_HOME") or "").strip().strip('"').strip("'")
    if java_home:
        bin_dir = Path(java_home) / "bin"
        if not javac:
            p = bin_dir / ("javac.exe" if os.name == "nt" else "javac")
            if p.is_file():
                javac = str(p)
        if not java:
            p = bin_dir / ("java.exe" if os.name == "nt" else "java")
            if p.is_file():
                java = str(p)
    if not javac:
        javac = _which("javac")
    if not java:
        java = _which("java")
    if os.name == "nt":
        for d in _windows_jdk_bin_dirs():
            if not javac:
                p = d / "javac.exe"
                if p.is_file():
                    javac = str(p)
            if not java:
                p = d / "java.exe"
                if p.is_file():
                    java = str(p)
    return javac, java


def _strip_c_family_main(code: str) -> str:
    """Remove learner ``main()`` so the test harness can supply its own driver."""
    m = re.search(r"\bint\s+main\s*\(", code)
    if not m:
        return code
    return code[: m.start()].rstrip() + "\n"


def _ensure_java_solution(code: str, entrypoint: str) -> str:
    """Wrap bare methods in ``public class Solution`` for the Java harness."""
    code = code.strip()
    if not code:
        return "public class Solution {\n}\n"
    if re.search(r"\bclass\s+Solution\b", code):
        return code + ("\n" if not code.endswith("\n") else "")
    if re.search(r"public\s+static", code):
        return f"public class Solution {{\n{code}\n}}\n"
    if _IDENT.match(entrypoint) and re.search(
        rf"\b{re.escape(entrypoint)}\s*\(",
        code,
    ):
        return f"public class Solution {{\n    public static {code}\n}}\n"
    return f"public class Solution {{\n{code}\n}}\n"


def prepare_user_code(code: str, *, language: str, entrypoint: str) -> str:
    """Normalize learner submissions before compile/run (per language)."""
    lang = (language or "python").strip().lower()
    ep = (entrypoint or "").strip()
    raw = code.strip()
    if lang == "javascript" and ep and _IDENT.match(ep):
        return _ensure_js_export(raw, ep)
    if lang == "java":
        return _ensure_java_solution(raw, ep) if ep else raw
    if lang in {"c", "cpp"}:
        return _strip_c_family_main(raw)
    return raw


def _ensure_js_export(code: str, entrypoint: str) -> str:
    """Ensure the learner module exports ``entrypoint`` for the Node ESM harness."""
    if not _IDENT.match(entrypoint):
        return code
    if re.search(rf"export\s+(?:async\s+)?function\s+{re.escape(entrypoint)}\b", code):
        return code
    if re.search(rf"export\s+const\s+{re.escape(entrypoint)}\b", code):
        return code
    if re.search(rf"export\s*\{{[^}}]*\b{re.escape(entrypoint)}\b", code):
        return code
    m_fn = re.search(rf"(^|\n)(\s*)(function\s+{re.escape(entrypoint)}\s*\()", code)
    if m_fn:
        return code[: m_fn.start(2)] + "export " + code[m_fn.start(2) :]
    m_const = re.search(
        rf"(^|\n)(\s*)(const\s+{re.escape(entrypoint)}\s*=)",
        code,
    )
    if m_const:
        return code[: m_const.start(2)] + "export " + code[m_const.start(2) :]
    return f"export function {entrypoint}() {{\n  throw new Error('Implement this function');\n}}\n\n{code}"


async def _run_cmd(
    cmd: list[str],
    *,
    cwd: Path,
    timeout: float,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    loop = asyncio.get_running_loop()
    def _sync() -> subprocess.CompletedProcess[str]:
        # Use sanitized environment unless explicitly overridden
        safe_env = env if env is not None else _safe_env()

        if os.name == "nt":
            # Windows: try to create a Job object so child processes are
            # killed when the job handle is closed. This is best-effort
            # and must not raise on failure.
            try:
                proc = subprocess.Popen(
                    cmd,
                    cwd=str(cwd),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    env=safe_env,
                )
                # Attempt to attach to a job object (best-effort)
                try:
                    _windows_assign_process_to_job(proc.pid)
                except Exception:
                    pass
                try:
                    out, err = proc.communicate(timeout=timeout)
                except subprocess.TimeoutExpired:
                    try:
                        proc.kill()
                    except Exception:
                        pass
                    out, err = proc.communicate()
                return subprocess.CompletedProcess(cmd, proc.returncode or 0, out, err)
            except Exception:
                # Fallback: use subprocess.run to get deterministic behavior
                return subprocess.run(
                    cmd,
                    cwd=str(cwd),
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=timeout,
                    env=safe_env,
                    check=False,
                )

        # Unix-like: apply resource limits via preexec_fn
        preexec = _set_resource_limits if HAS_RESOURCE else None
        return subprocess.run(
            cmd,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            env=safe_env,
            check=False,
            preexec_fn=preexec,
        )

    return await loop.run_in_executor(None, _sync)


def _parse_test_rows(stdout: str) -> list[dict[str, Any]]:
    stdout = (stdout or "").strip()
    if not stdout:
        return []
    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if line.startswith("["):
            try:
                parsed = json.loads(line)
            except json.JSONDecodeError:
                return []
            if isinstance(parsed, list):
                return [r for r in parsed if isinstance(r, dict)]
            return []
    return []


def _tests_payload(tests: list[dict[str, Any]]) -> str:
    return json.dumps(tests, ensure_ascii=False)


def _set_resource_limits() -> None:
    """Set resource limits for child processes (CPU time, memory, file descriptors).
    
    On Windows, this is a no-op. On Linux/macOS, restricts memory and CPU to prevent runaway processes.
    """
    if not HAS_RESOURCE:
        return
    try:
        # Limit memory to 512 MB
        resource.setrlimit(resource.RLIMIT_AS, (512 * 1024 * 1024, 512 * 1024 * 1024))
    except (OSError, ValueError, PermissionError):
        pass  # May fail in containerized environments
    try:
        # Limit CPU time to 30 seconds
        resource.setrlimit(resource.RLIMIT_CPU, (30, 30))
    except (OSError, ValueError, PermissionError):
        pass
    try:
        # Limit file size to 100 MB
        resource.setrlimit(resource.RLIMIT_FSIZE, (100 * 1024 * 1024, 100 * 1024 * 1024))
    except (OSError, ValueError, PermissionError):
        pass
    try:
        # Limit open files to 256
        resource.setrlimit(resource.RLIMIT_NOFILE, (256, 256))
    except (OSError, ValueError, PermissionError):
        pass


def _safe_env() -> dict[str, str]:
    """Return a sanitized environment for subprocess execution.
    
    Removes sensitive env vars and keeps only safe ones.
    """
    # Whitelist of safe env vars
    safe_keys = {
        "PATH", "JAVA_HOME", "DEEPTUTOR_JAVAC", "DEEPTUTOR_JAVA",
        "DEEPTUTOR_CC", "DEEPTUTOR_CXX", "DEEPTUTOR_NODE",
        "CC", "CXX", "NODE", "JAVA",
        "TERM", "LANG", "LC_ALL",
        "PYTHONPATH", "PYTHONHOME", "PYTHON_HOME",
    }
    env = os.environ.copy()
    # Remove potentially unsafe vars
    for key in list(env.keys()):
        if key not in safe_keys and not key.startswith("DEEPTUTOR_"):
            # Be conservative: only keep explicitly whitelisted keys
            if key not in {"PATH", "TERM", "LANG", "LC_ALL", "HOME", "USER", "SHELL", "PWD"}:
                try:
                    del env[key]
                except KeyError:
                    pass
    return env


# --- Windows Job object helpers (best-effort) -------------------------------
if os.name == "nt":
    try:
        import ctypes
        from ctypes import wintypes

        kernel32 = ctypes.windll.kernel32

        def _windows_assign_process_to_job(pid: int) -> None:
            # Create a job object with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000

            class JOBOBJECT_BASIC_LIMIT_INFORMATION(ctypes.Structure):
                _fields_ = [
                    ("PerProcessUserTimeLimit", wintypes.LARGE_INTEGER),
                    ("PerJobUserTimeLimit", wintypes.LARGE_INTEGER),
                    ("LimitFlags", wintypes.DWORD),
                    ("MinimumWorkingSetSize", ctypes.c_size_t),
                    ("MaximumWorkingSetSize", ctypes.c_size_t),
                    ("ActiveProcessLimit", wintypes.DWORD),
                    ("Affinity", ctypes.c_size_t),
                    ("PriorityClass", wintypes.DWORD),
                    ("SchedulingClass", wintypes.DWORD),
                ]

            class IO_COUNTERS(ctypes.Structure):
                _fields_ = [
                    ("ReadOperationCount", ctypes.c_ulonglong),
                    ("WriteOperationCount", ctypes.c_ulonglong),
                    ("OtherOperationCount", ctypes.c_ulonglong),
                    ("ReadTransferCount", ctypes.c_ulonglong),
                    ("WriteTransferCount", ctypes.c_ulonglong),
                    ("OtherTransferCount", ctypes.c_ulonglong),
                ]

            class JOBOBJECT_EXTENDED_LIMIT_INFORMATION(ctypes.Structure):
                _fields_ = [
                    ("BasicLimitInformation", JOBOBJECT_BASIC_LIMIT_INFORMATION),
                    ("IoInfo", IO_COUNTERS),
                    ("ProcessMemoryLimit", ctypes.c_size_t),
                    ("JobMemoryLimit", ctypes.c_size_t),
                    ("PeakProcessMemoryUsed", ctypes.c_size_t),
                    ("PeakJobMemoryUsed", ctypes.c_size_t),
                ]

            job = kernel32.CreateJobObjectW(None, None)
            if not job:
                return

            limits = JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
            limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE

            # SetInformationJobObject(JOBOBJECT_EXTENDED_LIMIT_INFORMATION)
            JobObjectExtendedLimitInformation = 9
            res = kernel32.SetInformationJobObject(
                job,
                JobObjectExtendedLimitInformation,
                ctypes.byref(limits),
                ctypes.sizeof(limits),
            )

            # Open process and assign
            PROCESS_ALL_ACCESS = 0x1F0FFF
            hproc = kernel32.OpenProcess(PROCESS_ALL_ACCESS, False, int(pid))
            if not hproc:
                try:
                    kernel32.CloseHandle(job)
                except Exception:
                    pass
                return
            try:
                kernel32.AssignProcessToJobObject(job, hproc)
            finally:
                try:
                    kernel32.CloseHandle(hproc)
                except Exception:
                    pass

    except Exception:
        def _windows_assign_process_to_job(pid: int) -> None:  # type: ignore[override]
            return
else:
    def _windows_assign_process_to_job(pid: int) -> None:  # pragma: no cover - noop on unix
        return


# --- JavaScript (Node, ESM) -------------------------------------------------


async def run_javascript_snippet(code: str, *, timeout: int) -> dict[str, Any]:
    node = resolve_node()
    if not node:
        return {
            "stdout": "",
            "stderr": _NODE_ERR,
            "exit_code": -1,
            "elapsed_ms": 0.0,
        }
    with tempfile.TemporaryDirectory(prefix="cpjs_") as td:
        root = Path(td)
        sol = root / "solution.mjs"
        sol.write_text(code, encoding="utf-8")
        t0 = time.perf_counter()
        chk = await _run_cmd([node, "--check", str(sol)], cwd=root, timeout=float(timeout))
        if chk.returncode != 0:
            elapsed = (time.perf_counter() - t0) * 1000
            return {
                "stdout": chk.stdout or "",
                "stderr": (chk.stderr or "") or "Syntax check failed.",
                "exit_code": int(chk.returncode),
                "elapsed_ms": elapsed,
            }
        proc = await _run_cmd([node, str(sol)], cwd=root, timeout=float(timeout))
        elapsed = (time.perf_counter() - t0) * 1000
        return {
            "stdout": proc.stdout or "",
            "stderr": proc.stderr or "",
            "exit_code": int(proc.returncode),
            "elapsed_ms": elapsed,
        }


async def run_javascript_tests(
    user_code: str,
    *,
    entrypoint: str,
    tests: list[dict[str, Any]],
    timeout: int,
) -> dict[str, Any]:
    node = resolve_node()
    if not node:
        return {
            "ok": False,
            "exit_code": -1,
            "stderr": _NODE_ERR,
            "stdout": "",
            "tests": [],
        }
    if not _IDENT.match(entrypoint):
        return {
            "ok": False,
            "exit_code": -1,
            "stderr": "Invalid entrypoint identifier.",
            "stdout": "",
            "tests": [],
        }
    user_code = prepare_user_code(user_code, language="javascript", entrypoint=entrypoint)
    with tempfile.TemporaryDirectory(prefix="cpjs_") as td:
        root = Path(td)
        (root / "solution.mjs").write_text(user_code, encoding="utf-8")
        (root / "specs.json").write_text(_tests_payload(tests), encoding="utf-8")
        harness = root / "harness.mjs"
        harness.write_text(
            f"""
import {{ isDeepStrictEqual }} from 'node:util';
import {{ readFileSync }} from 'node:fs';
import * as user from './solution.mjs';

const entry = {json.dumps(entrypoint)};
const fn = user[entry];
if (typeof fn !== 'function') {{
  console.error('No export named ' + entry);
  process.exit(2);
}}
const specs = JSON.parse(readFileSync(new URL('./specs.json', import.meta.url), 'utf8'));
const out = [];
for (let i = 0; i < specs.length; i++) {{
  const s = specs[i];
  try {{
    const got = fn(...s.args);
    const exp = s.expected;
    const ok = isDeepStrictEqual(got, exp);
    out.push({{
      ok,
      index: i,
      got: JSON.stringify(got),
      expected: JSON.stringify(exp),
    }});
  }} catch (e) {{
    out.push({{ ok: false, index: i, error: String(e) }});
  }}
}}
console.log(JSON.stringify(out));
""".strip(),
            encoding="utf-8",
        )
        proc = await _run_cmd([node, str(harness)], cwd=root, timeout=float(timeout))
        stdout = proc.stdout or ""
        stderr = proc.stderr or ""
        rows = _parse_test_rows(stdout)
        if not rows:
            return {
                "ok": False,
                "exit_code": int(proc.returncode),
                "stderr": stderr or "Harness failed.",
                "stdout": stdout,
                "tests": [],
            }
        all_ok = all(bool(r.get("ok")) for r in rows)
        out_exit = 0 if all_ok else (int(proc.returncode) if proc.returncode != 0 else 1)
        return {
            "ok": all_ok,
            "exit_code": out_exit,
            "stderr": stderr,
            "stdout": stdout,
            "tests": rows,
        }


# --- C / C++ (int/bool scalar harness — same JSON shape as Python lab) -----


def _c_family_json_main(entrypoint: str, tests: list[dict[str, Any]]) -> str:
    blocks: list[str] = []
    for i, t in enumerate(tests):
        args = t.get("args")
        exp = t.get("expected")
        if not isinstance(args, list):
            raise ValueError("invalid test args")
        assert_c_int_json(exp)
        for a in args:
            assert_c_int_json(a)
        arg_list = ", ".join(c_int_literal(a) for a in args)
        blocks.append(
            "{ int g = "
            + entrypoint
            + "("
            + arg_list
            + "); int e = "
            + c_int_literal(exp)
            + "; int pass_ = (g==e); "
            + 'char buf[768]; snprintf(buf, sizeof(buf), "{\\"ok\\":%s,\\"index\\":%d,\\"got\\":%d,\\"expected\\":%d}", '
            + 'pass_ ? "true" : "false", '
            + str(i)
            + ", g, e); fputs(buf, stdout); }"
        )
    sep = "\n  fputs(\",\", stdout);\n  "
    inner = sep.join(blocks)
    return (
        "#include <stdio.h>\n"
        "int main(void) {\n"
        '  fputs("[", stdout);\n'
        f"  {inner}\n"
        '  fputs("]\\n", stdout);\n'
        "  return 0;\n"
        "}\n"
    )


def _tests_scalar_only(tests: list[dict[str, Any]]) -> bool:
    for t in tests:
        try:
            assert_c_int_json(t.get("expected"))
            for a in t.get("args") or []:
                assert_c_int_json(a)
        except TypeError:
            return False
    return True


_CPP_JSON_PREAMBLE = r"""
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

template<typename T>
std::string json_repr(const T& v);

template<>
inline std::string json_repr<int>(const int& v) { return std::to_string(v); }

template<>
inline std::string json_repr<bool>(const bool& v) { return v ? "true" : "false"; }

template<>
inline std::string json_repr<std::string>(const std::string& v) {
  std::ostringstream os;
  os << '"';
  for (char c : v) {
    if (c == '\\' || c == '"') os << '\\' << c;
    else if (c == '\n') os << "\\n";
    else os << c;
  }
  os << '"';
  return os.str();
}

template<>
inline std::string json_repr<std::vector<int>>(const std::vector<int>& v) {
  std::ostringstream os;
  os << '[';
  for (size_t i = 0; i < v.size(); ++i) {
    if (i) os << ',';
    os << v[i];
  }
  os << ']';
  return os.str();
}
""".strip()


def _cpp_family_json_main(entrypoint: str, tests: list[dict[str, Any]]) -> str:
    blocks: list[str] = []
    for i, t in enumerate(tests):
        args = t.get("args")
        exp = t.get("expected")
        if not isinstance(args, list):
            raise ValueError("invalid test args")
        arg_list = ", ".join(cpp_literal(a) for a in args)
        exp_lit = cpp_literal(exp)
        blocks.append(
            "  try {\n"
            f"    auto got = {entrypoint}({arg_list});\n"
            f"    auto exp = {exp_lit};\n"
            "    bool ok = got == exp;\n"
            '    std::cout << "{\\"ok\\":" << (ok ? "true" : "false")'
            f' << ",\\"index\\":{i}"'
            ' << ",\\"got\\":" << json_repr(got)'
            ' << ",\\"expected\\":" << json_repr(exp) << "}";\n'
            "  } catch (const std::exception& e) {\n"
            f'    std::cout << "{{\\"ok\\":false,\\"index\\":{i},\\"error\\":\\"" << e.what() << "\\"}}";\n'
            "  } catch (...) {\n"
            f'    std::cout << "{{\\"ok\\":false,\\"index\\":{i},\\"error\\":\\"unknown error\\"}}";\n'
            "  }"
        )
    sep = '\n  std::cout << ",";\n  '
    inner = sep.join(blocks)
    return (
        _CPP_JSON_PREAMBLE
        + "\n\nint main() {\n"
        '  std::cout << "[";\n'
        f"{inner}\n"
        '  std::cout << "]\\n";\n'
        "  return 0;\n"
        "}\n"
    )


async def run_c_snippet(user_code: str, *, timeout: int) -> dict[str, Any]:
    gcc = resolve_c_compiler()
    if not gcc:
        return {
            "stdout": "",
            "stderr": _C_COMPILER_ERR,
            "exit_code": -1,
            "elapsed_ms": 0.0,
        }
    user_code = prepare_user_code(user_code, language="c", entrypoint="main")
    with tempfile.TemporaryDirectory(prefix="cpc_") as td:
        root = Path(td)
        src = root / "all.c"
        src.write_text(user_code + "\n\nint main(void){return 0;}\n", encoding="utf-8")
        out = root / "a.exe" if os.name == "nt" else root / "a.out"
        t0 = time.perf_counter()
        proc = await _run_cmd(
            [gcc, "-std=c11", "-O2", "-pipe", str(src), "-o", str(out)],
            cwd=root,
            timeout=float(timeout),
        )
        elapsed = (time.perf_counter() - t0) * 1000
        return {
            "stdout": proc.stdout or "",
            "stderr": proc.stderr or "",
            "exit_code": int(proc.returncode),
            "elapsed_ms": elapsed,
        }


async def run_c_tests(
    user_code: str,
    *,
    entrypoint: str,
    tests: list[dict[str, Any]],
    timeout: int,
) -> dict[str, Any]:
    return await _run_c_family_tests(
        user_code,
        entrypoint=entrypoint,
        tests=tests,
        timeout=timeout,
        compiler_key="c",
    )


async def run_cpp_snippet(user_code: str, *, timeout: int) -> dict[str, Any]:
    gxx = resolve_cpp_compiler()
    if not gxx:
        return {
            "stdout": "",
            "stderr": _CPP_COMPILER_ERR,
            "exit_code": -1,
            "elapsed_ms": 0.0,
        }
    user_code = prepare_user_code(user_code, language="cpp", entrypoint="main")
    with tempfile.TemporaryDirectory(prefix="cpcpp_") as td:
        root = Path(td)
        src = root / "all.cpp"
        src.write_text(
            user_code + "\n\nint main(){return 0;}\n",
            encoding="utf-8",
        )
        out = root / "a.exe" if os.name == "nt" else root / "a.out"
        t0 = time.perf_counter()
        proc = await _run_cmd(
            [gxx, "-std=c++17", "-O2", "-pipe", str(src), "-o", str(out)],
            cwd=root,
            timeout=float(timeout),
        )
        elapsed = (time.perf_counter() - t0) * 1000
        return {
            "stdout": proc.stdout or "",
            "stderr": proc.stderr or "",
            "exit_code": int(proc.returncode),
            "elapsed_ms": elapsed,
        }


async def run_cpp_tests(
    user_code: str,
    *,
    entrypoint: str,
    tests: list[dict[str, Any]],
    timeout: int,
) -> dict[str, Any]:
    return await _run_c_family_tests(
        user_code,
        entrypoint=entrypoint,
        tests=tests,
        timeout=timeout,
        compiler_key="cpp",
    )


async def _run_c_family_tests(
    user_code: str,
    *,
    entrypoint: str,
    tests: list[dict[str, Any]],
    timeout: int,
    compiler_key: str,
) -> dict[str, Any]:
    if compiler_key == "c":
        cc = resolve_c_compiler()
        cflags = ["-std=c11", "-O2", "-pipe"]
        ext = ".c"
        err_msg = _C_COMPILER_ERR
    else:
        cc = resolve_cpp_compiler()
        cflags = ["-std=c++17", "-O2", "-pipe"]
        ext = ".cpp"
        err_msg = _CPP_COMPILER_ERR
    if not cc:
        return {
            "ok": False,
            "exit_code": -1,
            "stderr": err_msg,
            "stdout": "",
            "tests": [],
        }
    if not _IDENT.match(entrypoint):
        return {
            "ok": False,
            "exit_code": -1,
            "stderr": "Invalid entrypoint.",
            "stdout": "",
            "tests": [],
        }
    scalar_only = compiler_key == "c" or _tests_scalar_only(tests)
    if not scalar_only and compiler_key == "c":
        return {
            "ok": False,
            "exit_code": -1,
            "stderr": "C harness supports int/bool scalars only; use C++ for arrays/strings.",
            "stdout": "",
            "tests": [],
        }
    user_code = prepare_user_code(
        user_code,
        language=compiler_key,
        entrypoint=entrypoint,
    )
    try:
        driver = (
            _c_family_json_main(entrypoint, tests)
            if scalar_only
            else _cpp_family_json_main(entrypoint, tests)
        )
    except (TypeError, ValueError) as exc:
        return {
            "ok": False,
            "exit_code": -1,
            "stderr": str(exc),
            "stdout": "",
            "tests": [],
            "elapsed_ms": 0.0,
        }
    # Attempt to reuse a cached compiled binary to speed up repeated runs.
    ps = get_path_service()
    cache_root = ps.get_user_root() / "coding_cache"
    try:
        key_src = json.dumps({
            "code": user_code,
            "tests": tests,
            "entrypoint": entrypoint,
            "cc": cc,
            "cflags": cflags,
        }, sort_keys=True)
    except Exception:
        key_src = user_code + str(tests) + entrypoint + cc
    key = hashlib.sha256(key_src.encode("utf-8")).hexdigest()
    cache_dir = cache_root / key
    cache_bin = cache_dir / ("a.exe" if os.name == "nt" else "a.out")

    if cache_bin.exists() and os.access(cache_bin, os.X_OK):
        # Reuse cached binary by copying it into an isolated temp dir for execution.
        with tempfile.TemporaryDirectory(prefix="cpcf_run_") as td_run:
            run_root = Path(td_run)
            run_bin = run_root / cache_bin.name
            shutil.copy2(cache_bin, run_bin)
            t0 = time.perf_counter()
            run = await _run_cmd([str(run_bin)], cwd=run_root, timeout=max(3.0, float(timeout) / 3))
            rows = _parse_test_rows(run.stdout or "")
            all_ok = bool(rows) and all(bool(r.get("ok")) for r in rows)
            out_exit = 0 if all_ok else (int(run.returncode) if run.returncode != 0 else 1)
            elapsed = (time.perf_counter() - t0) * 1000
            return {
                "ok": all_ok,
                "exit_code": out_exit,
                "stderr": run.stderr or "",
                "stdout": run.stdout or "",
                "tests": rows,
                "elapsed_ms": elapsed,
            }

    # No cached binary — compile into a temporary build dir, then cache the artifact.
    with tempfile.TemporaryDirectory(prefix="cpcf_build_") as td_build:
        build_root = Path(td_build)
        src = build_root / ("all" + ext)
        src.write_text(user_code.rstrip() + "\n\n" + driver, encoding="utf-8")
        out_path = build_root / ("a.exe" if os.name == "nt" else "a.out")
        t0 = time.perf_counter()
        comp = await _run_cmd([cc, *cflags, str(src), "-o", str(out_path)], cwd=build_root, timeout=float(timeout))
        if comp.returncode != 0:
            elapsed = (time.perf_counter() - t0) * 1000
            return {
                "ok": False,
                "exit_code": int(comp.returncode),
                "stderr": comp.stderr or comp.stdout or "Compile failed.",
                "stdout": comp.stdout or "",
                "tests": [],
                "elapsed_ms": elapsed,
            }
        # Ensure cache directory exists and move compiled binary there atomically.
        cache_dir.mkdir(parents=True, exist_ok=True)
        try:
            shutil.move(str(out_path), str(cache_bin))
        except Exception:
            # Fallback to copy if move fails across filesystems
            shutil.copy2(str(out_path), str(cache_bin))
        # Execute from a fresh temp dir to avoid accidental state leak.
        with tempfile.TemporaryDirectory(prefix="cpcf_run_") as td_run2:
            run_root = Path(td_run2)
            run_bin = run_root / cache_bin.name
            shutil.copy2(cache_bin, run_bin)
            run = await _run_cmd([str(run_bin)], cwd=run_root, timeout=max(3.0, float(timeout) / 3))
            rows = _parse_test_rows(run.stdout or "")
            all_ok = bool(rows) and all(bool(r.get("ok")) for r in rows)
            out_exit = 0 if all_ok else (int(run.returncode) if run.returncode != 0 else 1)
            elapsed = (time.perf_counter() - t0) * 1000
            return {
                "ok": all_ok,
                "exit_code": out_exit,
                "stderr": (comp.stderr or "") + (run.stderr or ""),
                "stdout": run.stdout or "",
                "tests": rows,
                "elapsed_ms": elapsed,
            }


# --- Java -------------------------------------------------------------------


def _java_main_source(entrypoint: str, tests: list[dict[str, Any]]) -> str:
    lines: list[str] = [
        _JAVA_JSON_HELPERS,
        "public class Main {",
        "  public static void main(String[] args) throws Exception {",
        '    System.out.print("[");',
    ]
    for i, t in enumerate(tests):
        args = t.get("args")
        exp = t.get("expected")
        if not isinstance(args, list):
            raise ValueError("invalid test args")
        arg_list = ", ".join(java_literal(a) for a in args)
        exp_lit = java_literal(exp)
        if i > 0:
            lines.append('    System.out.print(",");')
        lines.append("    {")
        lines.append(
            f"      try {{ Object got = Solution.{entrypoint}({arg_list}); "
            f"Object exp = {exp_lit}; boolean ok = java.util.Objects.deepEquals(got, exp);"
        )
        lines.append(
            '        System.out.print("{\\"ok\\":" + (ok ? "true" : "false") + ",\\"index\\":" + '
            + str(i)
            + ' + ",\\"got\\":" + J.j(got) + ",\\"expected\\":" + J.j(exp) + "}");'
        )
        lines.append("      } catch (Exception e) {")
        lines.append(
            f'        System.out.print("{{\\"ok\\":false,\\"index\\":{i},\\"error\\":" + '
            "J.j(java.util.Objects.toString(e.getMessage(), \"\")) + \"}\");"
        )
        lines.append("      }")
        lines.append("    }")
    lines.extend(['    System.out.println("]");', "  }", "}"])
    return "\n".join(lines) + "\n"


async def run_java_snippet(user_code: str, *, timeout: int) -> dict[str, Any]:
    javac, _java = resolve_java_tools()
    if not javac:
        return {
            "stdout": "",
            "stderr": _JAVA_ERR,
            "exit_code": -1,
            "elapsed_ms": 0.0,
        }
    user_code = prepare_user_code(user_code, language="java", entrypoint="run")
    with tempfile.TemporaryDirectory(prefix="cpj_") as td:
        root = Path(td)
        (root / "Solution.java").write_text(user_code, encoding="utf-8")
        t0 = time.perf_counter()
        proc = await _run_cmd([javac, str(root / "Solution.java")], cwd=root, timeout=float(timeout))
        elapsed = (time.perf_counter() - t0) * 1000
        return {
            "stdout": proc.stdout or "",
            "stderr": proc.stderr or "",
            "exit_code": int(proc.returncode),
            "elapsed_ms": elapsed,
        }


async def run_java_tests(
    user_code: str,
    *,
    entrypoint: str,
    tests: list[dict[str, Any]],
    timeout: int,
) -> dict[str, Any]:
    javac, java = resolve_java_tools()
    if not javac or not java:
        return {
            "ok": False,
            "exit_code": -1,
            "stderr": _JAVA_ERR,
            "stdout": "",
            "tests": [],
        }
    if not _IDENT.match(entrypoint):
        return {
            "ok": False,
            "exit_code": -1,
            "stderr": "Invalid entrypoint.",
            "stdout": "",
            "tests": [],
        }
    user_code = prepare_user_code(user_code, language="java", entrypoint=entrypoint)
    try:
        main_src = _java_main_source(entrypoint, tests)
    except (TypeError, ValueError) as exc:
        return {
            "ok": False,
            "exit_code": -1,
            "stderr": str(exc),
            "stdout": "",
            "tests": [],
        }
    # Persistent compile cache for Java: hash source + tests + tools
    ps = get_path_service()
    cache_root = ps.get_user_root() / "coding_cache"
    try:
        key_src = json.dumps({
            "code": user_code,
            "tests": tests,
            "entrypoint": entrypoint,
            "javac": javac,
            "java": java,
        }, sort_keys=True)
    except Exception:
        key_src = user_code + str(tests) + entrypoint + str(javac) + str(java)
    key = hashlib.sha256(key_src.encode("utf-8")).hexdigest()
    cache_dir = cache_root / key
    # If compiled classes already present, run directly from cache_dir
    main_class = cache_dir / "Main.class"
    sol_class = cache_dir / "Solution.class"
    if main_class.exists() and sol_class.exists():
        t0 = time.perf_counter()
        run = await _run_cmd([java, "-cp", str(cache_dir), "Main"], cwd=cache_dir, timeout=max(3.0, float(timeout) / 3))
        rows = _parse_test_rows(run.stdout or "")
        all_ok = bool(rows) and all(bool(r.get("ok")) for r in rows)
        out_exit = 0 if all_ok else (int(run.returncode) if run.returncode != 0 else 1)
        elapsed = (time.perf_counter() - t0) * 1000
        return {
            "ok": all_ok,
            "exit_code": out_exit,
            "stderr": run.stderr or "",
            "stdout": run.stdout or "",
            "tests": rows,
            "elapsed_ms": elapsed,
        }

    # Otherwise compile into a temporary build dir, then cache the .class files.
    with tempfile.TemporaryDirectory(prefix="cpj_build_") as td_build:
        build_root = Path(td_build)
        (build_root / "Solution.java").write_text(user_code, encoding="utf-8")
        (build_root / "Main.java").write_text(main_src, encoding="utf-8")
        t0 = time.perf_counter()
        # Compile with output dir set to cache_dir to store classes persistently
        cache_dir.mkdir(parents=True, exist_ok=True)
        comp = await _run_cmd(
            [javac, "-d", str(cache_dir), str(build_root / "Solution.java"), str(build_root / "Main.java")],
            cwd=build_root,
            timeout=float(timeout),
        )
        if comp.returncode != 0:
            elapsed = (time.perf_counter() - t0) * 1000
            return {
                "ok": False,
                "exit_code": int(comp.returncode),
                "stderr": comp.stderr or comp.stdout or "Compile failed.",
                "stdout": comp.stdout or "",
                "tests": [],
                "elapsed_ms": elapsed,
            }
        # Run from cached classes
        run = await _run_cmd([java, "-cp", str(cache_dir), "Main"], cwd=cache_dir, timeout=max(3.0, float(timeout) / 3))
        rows = _parse_test_rows(run.stdout or "")
        all_ok = bool(rows) and all(bool(r.get("ok")) for r in rows)
        out_exit = 0 if all_ok else (int(run.returncode) if run.returncode != 0 else 1)
        elapsed = (time.perf_counter() - t0) * 1000
        return {
            "ok": all_ok,
            "exit_code": out_exit,
            "stderr": (comp.stderr or "") + (run.stderr or ""),
            "stdout": run.stdout or "",
            "tests": rows,
            "elapsed_ms": elapsed,
        }


__all__ = [
    "prepare_user_code",
    "resolve_c_compiler",
    "resolve_cpp_compiler",
    "resolve_java_tools",
    "resolve_node",
    "run_c_snippet",
    "run_c_tests",
    "run_cpp_snippet",
    "run_cpp_tests",
    "run_java_snippet",
    "run_java_tests",
    "run_javascript_snippet",
    "run_javascript_tests",
]
