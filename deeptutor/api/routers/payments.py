"""Razorpay — create orders server-side and verify payment signatures."""

from __future__ import annotations

import logging
import os
import re
import uuid

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field, field_validator

from deeptutor.services.payments.razorpay import (
    create_order as razorpay_create_order,
    get_key_credentials,
    is_configured,
    verify_payment_signature,
)

logger = logging.getLogger(__name__)

router = APIRouter()

_RECEIPT_SAFE = re.compile(r"^[A-Za-z0-9_-]{0,40}$")


class RazorpayOrderRequest(BaseModel):
    """Amount in smallest currency unit (e.g. paise for INR)."""

    amount: int = Field(..., ge=100, description="Amount in paise (min 100 = ₹1)")
    currency: str = Field(default="INR", min_length=3, max_length=3)
    receipt: str | None = None

    @field_validator("currency")
    @classmethod
    def upper_currency(cls, v: str) -> str:
        return v.strip().upper()


class RazorpayOrderResponse(BaseModel):
    order_id: str
    amount: int
    currency: str
    receipt: str | None = None


class RazorpayVerifyRequest(BaseModel):
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


class RazorpayVerifyResponse(BaseModel):
    ok: bool
    order_id: str
    payment_id: str


@router.get("/razorpay/status")
async def razorpay_status():
    """Whether server-side credentials are present (never returns secrets)."""
    key_id, _ = get_key_credentials()
    return {
        "configured": is_configured(),
        "key_id_set": bool(key_id),
    }


@router.post("/razorpay/order", response_model=RazorpayOrderResponse)
async def razorpay_order(body: RazorpayOrderRequest):
    if not is_configured():
        raise HTTPException(
            status_code=503,
            detail="Razorpay is not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET.",
        )

    receipt = body.receipt
    if receipt and not _RECEIPT_SAFE.match(receipt):
        raise HTTPException(
            status_code=400,
            detail="receipt must be empty or up to 40 chars [A-Za-z0-9_-]",
        )
    if not receipt:
        receipt = f"dt_{uuid.uuid4().hex[:24]}"

    notes: dict[str, str] = {}
    mid = (os.getenv("RAZORPAY_MERCHANT_ID") or "").strip()
    if mid:
        notes["merchant_id"] = mid

    try:
        data = await razorpay_create_order(
            amount_paise=body.amount,
            currency=body.currency,
            receipt=receipt,
            notes=notes or None,
        )
    except RuntimeError as e:
        logger.warning("Razorpay order failed: %s", e)
        raise HTTPException(status_code=502, detail=str(e)) from e
    except Exception as e:
        logger.exception("Razorpay order unexpected error")
        raise HTTPException(status_code=502, detail="Could not create order") from e

    order_id = data.get("id")
    if not isinstance(order_id, str):
        raise HTTPException(status_code=502, detail="Invalid Razorpay response")

    return RazorpayOrderResponse(
        order_id=order_id,
        amount=int(data.get("amount", body.amount)),
        currency=str(data.get("currency", body.currency)),
        receipt=data.get("receipt") if isinstance(data.get("receipt"), str) else receipt,
    )


@router.post("/razorpay/verify", response_model=RazorpayVerifyResponse)
async def razorpay_verify(body: RazorpayVerifyRequest):
    _, key_secret = get_key_credentials()
    if not key_secret:
        raise HTTPException(status_code=503, detail="Razorpay is not configured.")

    ok = verify_payment_signature(
        body.razorpay_order_id,
        body.razorpay_payment_id,
        body.razorpay_signature,
        key_secret,
    )
    if not ok:
        raise HTTPException(status_code=400, detail="Invalid payment signature")
    return RazorpayVerifyResponse(
        ok=True,
        order_id=body.razorpay_order_id,
        payment_id=body.razorpay_payment_id,
    )
