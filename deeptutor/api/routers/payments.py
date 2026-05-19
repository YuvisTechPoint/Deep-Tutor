"""Razorpay — create orders server-side and verify payment signatures."""

from __future__ import annotations

import logging
import os
import re
import uuid

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field, field_validator

from deeptutor.services.payments import subscription_store
from deeptutor.services.payments.razorpay import (
    create_order as razorpay_create_order,
)
from deeptutor.services.payments.razorpay import (
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
    plan_id: str | None = Field(
        default=None,
        description="When set with billing_period, amount must match the catalog (pro/team).",
    )
    billing_period: str | None = Field(
        default=None,
        description="monthly, annual, or hourly — paired with plan_id for catalog validation.",
    )

    @field_validator("currency")
    @classmethod
    def upper_currency(cls, v: str) -> str:
        return v.strip().upper()

    @field_validator("plan_id")
    @classmethod
    def plan_ok(cls, v: str | None) -> str | None:
        if v is None or v == "":
            return None
        v2 = v.strip().lower()
        if v2 not in ("pro", "team"):
            raise ValueError("plan_id must be pro or team when set")
        return v2

    @field_validator("billing_period")
    @classmethod
    def period_ok(cls, v: str | None) -> str | None:
        if v is None or v == "":
            return None
        v2 = v.strip().lower()
        if v2 not in ("monthly", "annual", "hourly"):
            raise ValueError(
                "billing_period must be monthly, annual, or hourly when set"
            )
        return v2


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
    plan_activated: bool = False
    plan_id: str | None = None
    billing_period: str | None = None


class SubscriptionResponse(BaseModel):
    plan_id: str
    billing_period: str | None = None
    last_order_id: str | None = None
    last_payment_id: str | None = None
    updated_at: str | None = None


@router.get("/razorpay/status")
async def razorpay_status():
    """Whether server-side credentials are present (never returns secrets)."""
    key_id, _ = get_key_credentials()
    return {
        "configured": is_configured(),
        "key_id_set": bool(key_id),
    }


@router.get("/subscription", response_model=SubscriptionResponse)
async def get_subscription():
    """Current paid plan from server (used for realtime billing UI sync)."""
    raw = subscription_store.get_subscription()
    return SubscriptionResponse(**raw)


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

    plan_id = body.plan_id
    billing_period = body.billing_period
    if (plan_id is None) ^ (billing_period is None):
        raise HTTPException(
            status_code=400,
            detail="plan_id and billing_period must both be set or both omitted",
        )
    if plan_id and billing_period:
        expected = subscription_store.catalog_amount_paise(plan_id, billing_period)
        if expected is None or expected != body.amount:
            raise HTTPException(
                status_code=400,
                detail="Amount does not match catalog for plan and billing period",
            )

    notes: dict[str, str] = {}
    mid = (os.getenv("RAZORPAY_MERCHANT_ID") or "").strip()
    if mid:
        notes["merchant_id"] = mid
    if plan_id:
        notes["plan_id"] = plan_id
    if billing_period:
        notes["billing_period"] = billing_period

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

    if plan_id and billing_period:
        subscription_store.register_pending_order(
            order_id,
            plan_id=plan_id,
            billing_period=billing_period,
            amount_paise=body.amount,
        )

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

    pending = subscription_store.pop_pending_order(body.razorpay_order_id)
    activated = subscription_store.activate_from_verified_payment(
        order_id=body.razorpay_order_id,
        payment_id=body.razorpay_payment_id,
        pending=pending,
    )
    return RazorpayVerifyResponse(
        ok=True,
        order_id=body.razorpay_order_id,
        payment_id=body.razorpay_payment_id,
        plan_activated=activated is not None,
        plan_id=str(activated["plan_id"]) if activated else None,
        billing_period=str(activated["billing_period"]) if activated else None,
    )
