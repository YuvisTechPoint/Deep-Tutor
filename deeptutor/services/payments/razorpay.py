"""Razorpay REST helpers — order creation and payment signature verification."""

from __future__ import annotations

import hashlib
import hmac
import os
from typing import Any

import httpx

RAZORPAY_API_BASE = "https://api.razorpay.com/v1"


def get_key_credentials() -> tuple[str, str]:
    key_id = (os.getenv("RAZORPAY_KEY_ID") or "").strip()
    key_secret = (os.getenv("RAZORPAY_KEY_SECRET") or "").strip()
    return key_id, key_secret


def is_configured() -> bool:
    kid, secret = get_key_credentials()
    return bool(kid and secret)


def verify_payment_signature(
    order_id: str,
    payment_id: str,
    signature: str,
    key_secret: str,
) -> bool:
    body = f"{order_id}|{payment_id}".encode("utf-8")
    expected = hmac.new(
        key_secret.encode("utf-8"),
        body,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, signature.strip())


def _error_detail(payload: dict[str, Any]) -> str:
    err = payload.get("error")
    if isinstance(err, dict):
        desc = err.get("description")
        if isinstance(desc, str) and desc.strip():
            return desc.strip()
        code = err.get("code")
        if isinstance(code, str) and code.strip():
            return code.strip()
    return "Razorpay request failed"


async def create_order(
    *,
    amount_paise: int,
    currency: str,
    receipt: str | None,
    notes: dict[str, str] | None,
) -> dict[str, Any]:
    key_id, key_secret = get_key_credentials()
    if not key_id or not key_secret:
        raise RuntimeError("Razorpay is not configured (missing RAZORPAY_KEY_ID or RAZORPAY_KEY_SECRET)")

    payload: dict[str, Any] = {
        "amount": amount_paise,
        "currency": currency.upper(),
    }
    if receipt:
        payload["receipt"] = receipt[:40]
    if notes:
        payload["notes"] = notes

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{RAZORPAY_API_BASE}/orders",
            json=payload,
            auth=(key_id, key_secret),
        )

    try:
        data = response.json()
    except Exception:
        response.raise_for_status()
        raise RuntimeError("Invalid JSON from Razorpay") from None

    if response.status_code >= 400:
        raise RuntimeError(_error_detail(data) if isinstance(data, dict) else response.text)

    return data
