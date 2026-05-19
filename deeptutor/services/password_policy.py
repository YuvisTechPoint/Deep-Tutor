"""Password strength and optional Have I Been Pwned (k-anonymity) checks."""

from __future__ import annotations

import hashlib
import logging
import os
import re
import string
from typing import Final

logger = logging.getLogger(__name__)

AUTH_PASSWORD_MIN_LENGTH: Final[int] = int(os.getenv("AUTH_PASSWORD_MIN_LENGTH", "10"))
AUTH_HIBP_CHECK_ENABLED: Final[bool] = os.getenv("AUTH_HIBP_CHECK_ENABLED", "").strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}


def validate_password_strength(plain: str) -> None:
    """
    Enforce minimum length and character-class diversity.

    Raises ValueError with a user-facing message on failure.
    """
    if not isinstance(plain, str):
        raise ValueError("Password is required")
    pwd = plain
    if not pwd:
        raise ValueError("Password is required")
    if len(pwd) < AUTH_PASSWORD_MIN_LENGTH:
        raise ValueError(
            f"Password must be at least {AUTH_PASSWORD_MIN_LENGTH} characters",
        )
    has_lower = bool(re.search(r"[a-z]", pwd))
    has_upper = bool(re.search(r"[A-Z]", pwd))
    has_lower = bool(re.search(r"[a-z]", pwd))
    has_digit = bool(re.search(r"\d", pwd))
    punct = re.escape(string.punctuation)
    has_special = bool(re.search(f"[{punct}]", pwd))
    classes = sum([has_upper, has_lower, has_digit, has_special])
    if classes < 3:
        raise ValueError(
            "Password must include at least three of: uppercase, lowercase, "
            "digits, special characters",
        )


async def password_is_pwned(plain: str) -> bool:
    """
    Return True if the password appears in the HIBP Pwned Passwords corpus.

    Uses k-anonymity (SHA-1 prefix). When ``AUTH_HIBP_CHECK_ENABLED`` is false,
    always returns False. On network errors, logs a warning and returns False
    (fail open so a flaky network does not block sign-ups).
    """
    if not AUTH_HIBP_CHECK_ENABLED:
        return False
    try:
        import httpx
    except ImportError:
        logger.warning("httpx not available; skipping HIBP check")
        return False

    digest = hashlib.sha1(plain.encode("utf-8")).hexdigest().upper()
    prefix, suffix = digest[:5], digest[5:]
    url = f"https://api.pwnedpasswords.com/range/{prefix}"
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.get(url, headers={"Add-Padding": "true"})
        if res.status_code != 200:
            logger.warning("HIBP range request failed: HTTP %s", res.status_code)
            return False
        for line in res.text.splitlines():
            part, _, rest = line.partition(":")
            if part.upper() == suffix:
                # Format is SUFFIX:COUNT or SUFFIX:COUNT\r
                return True
        return False
    except Exception as exc:
        logger.warning("HIBP check failed (ignored): %s", exc)
        return False
