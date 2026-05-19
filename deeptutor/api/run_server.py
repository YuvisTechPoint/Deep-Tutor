#!/usr/bin/env python
"""
Uvicorn Server Startup Script
Uses Python API instead of command line to avoid Windows path parsing issues.
"""

import asyncio
import os
from pathlib import Path
import sys

# Windows: uvicorn defaults to SelectorEventLoop which does not support
# asyncio.create_subprocess_exec.  Switch to ProactorEventLoop so that
# child-process APIs (used by Math Animator renderer, etc.) work correctly.
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

import uvicorn

# Force unbuffered output
os.environ["PYTHONUNBUFFERED"] = "1"


def _uvicorn_reload_enabled() -> bool:
    """Whether to pass ``reload=True`` to uvicorn.

    On Windows, uvicorn's reloader stops workers with ``CTRL_C_EVENT`` (see
    ``uvicorn.supervisors.basereload``). That can propagate to other processes
    attached to the same console.

    Opt in with ``DEEPTUTOR_API_RELOAD=1`` (or ``true`` / ``yes`` / ``on``).
    Force off anytime with ``DEEPTUTOR_API_RELOAD=0`` (or ``false`` / ``no``).
    """
    raw = (os.environ.get("DEEPTUTOR_API_RELOAD") or "").strip().lower()
    if raw in ("1", "true", "yes", "on"):
        return True
    if raw in ("0", "false", "no", "off"):
        return False
    return False


if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(line_buffering=True, errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(line_buffering=True, errors="replace")


def main() -> None:
    # Get project root directory
    project_root = Path(__file__).parent.parent.parent

    # Change to project root to ensure correct module imports
    os.chdir(str(project_root))

    # Ensure project root is in Python path
    if str(project_root) not in sys.path:
        sys.path.insert(0, str(project_root))

    # Get port from configuration
    from deeptutor.logging import configure_logging
    from deeptutor.runtime.mode import RunMode, set_mode
    from deeptutor.services.setup import get_backend_port

    set_mode(RunMode.SERVER)
    configure_logging()
    backend_port = get_backend_port(project_root)

    # Configure reload to watch only source code directories
    # This prevents unnecessary reloads from cache/build artifacts
    reload_dirs = [
        str(project_root / "deeptutor"),  # Main package
    ]

    use_reload = _uvicorn_reload_enabled()
    uvicorn.run(
        "deeptutor.api.main:app",
        host="0.0.0.0",
        port=backend_port,
        reload=use_reload,
        reload_dirs=reload_dirs if use_reload else None,
        log_level="info",
        access_log=False,
    )


if __name__ == "__main__":
    main()
