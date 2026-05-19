"""Readable messages from OpenAI-compatible SDK / Groq / gateway errors."""

from __future__ import annotations

import ast
import json
from typing import Any


def user_message_from_openai_exception(exc: BaseException, body: Any | None = None) -> str:
    """Return a single human-readable line (or short paragraph) for display/logging.

    Avoids dumping raw ``str(dict)`` bodies that confuse learners in chat UIs.
    """
    if body is None:
        body = getattr(exc, "body", None)
        if body is None:
            resp = getattr(exc, "response", None)
            if resp is not None:
                jfn = getattr(resp, "json", None)
                if callable(jfn):
                    try:
                        body = jfn()
                    except Exception:
                        body = None
                if body is None:
                    body = getattr(resp, "text", None)

    if isinstance(body, dict):
        err = body.get("error")
        if isinstance(err, dict) and isinstance(err.get("message"), str):
            return err["message"].strip()
        if isinstance(body.get("message"), str):
            return body["message"].strip()

    if isinstance(body, str):
        raw = body.strip()
        if raw.startswith("{") or raw.startswith("["):
            try:
                parsed = json.loads(raw)
                if isinstance(parsed, dict):
                    err = parsed.get("error")
                    if isinstance(err, dict) and isinstance(err.get("message"), str):
                        return err["message"].strip()
                    if isinstance(parsed.get("message"), str):
                        return parsed["message"].strip()
            except json.JSONDecodeError:
                pass

    msg = getattr(exc, "message", None)
    if isinstance(msg, str) and msg.strip():
        return msg.strip()

    s = str(exc).strip()
    if s.startswith("{") and "message" in s:
        try:
            d = ast.literal_eval(s)
            if isinstance(d, dict) and isinstance(d.get("message"), str):
                return d["message"].strip()
        except (SyntaxError, ValueError, MemoryError):
            pass
    return s or "Unknown error"


__all__ = ["user_message_from_openai_exception"]
