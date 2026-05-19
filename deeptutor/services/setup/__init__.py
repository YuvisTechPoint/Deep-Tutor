"""
Setup Service
=============

System setup and initialization for DeepTutor.

Port configuration is done via .env file:
    BACKEND_PORT=8001   (default: 8001)

Usage:
    from deeptutor.services.setup import init_user_directories, get_backend_port

    # Initialize user directories
    init_user_directories()

    # Get API port (from .env)
    backend_port = get_backend_port()
"""

from .init import (
    get_backend_port,
    init_user_directories,
)

__all__ = [
    "init_user_directories",
    "get_backend_port",
]
