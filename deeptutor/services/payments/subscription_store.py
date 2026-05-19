"""File-backed subscription state and Razorpay order → plan mapping."""

from __future__ import annotations

from datetime import datetime, timezone
import json
import logging
from pathlib import Path
import threading
from typing import Any, Literal

logger = logging.getLogger(__name__)

def _billing_dir() -> Path:
    from deeptutor.services.path_service import get_path_service

    d = get_path_service().user_data_dir / "billing"
    d.mkdir(parents=True, exist_ok=True)
    return d


def _subscription_path() -> Path:
    return _billing_dir() / "subscription.json"


def _pending_path() -> Path:
    return _billing_dir() / "pending_orders.json"

_write_lock = threading.Lock()

BillingPeriod = Literal["monthly", "annual", "hourly"]
PaidPlan = Literal["pro", "team"]

# Amounts in paise — must match web/components/payments/PlansPricing.tsx
_CATALOG: dict[tuple[PaidPlan, BillingPeriod], int] = {
    ("pro", "monthly"): 499_00,
    ("pro", "annual"): 4_990_00,
    ("pro", "hourly"): 49_00,
    ("team", "monthly"): 1_499_00,
    ("team", "annual"): 14_990_00,
    ("team", "hourly"): 149_00,
}


def catalog_amount_paise(plan_id: str, billing_period: str) -> int | None:
    if plan_id not in ("pro", "team"):
        return None
    if billing_period not in ("monthly", "annual", "hourly"):
        return None
    return _CATALOG.get((plan_id, billing_period))  # type: ignore[arg-type]


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_json(path: Path) -> dict[str, Any]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        return raw if isinstance(raw, dict) else {}
    except Exception as exc:
        logger.debug("read %s: %s", path, exc)
        return {}


def _write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    tmp.replace(path)


def get_subscription() -> dict[str, Any]:
    """Return persisted subscription; defaults to starter when unset."""
    data = _read_json(_subscription_path())
    plan_id = str(data.get("plan_id") or "starter")
    if plan_id not in ("starter", "pro", "team"):
        plan_id = "starter"
    period = data.get("billing_period")
    if period not in (None, "monthly", "annual", "hourly"):
        period = None
    return {
        "plan_id": plan_id,
        "billing_period": period,
        "last_order_id": data.get("last_order_id"),
        "last_payment_id": data.get("last_payment_id"),
        "updated_at": data.get("updated_at"),
    }


def register_pending_order(
    order_id: str,
    *,
    plan_id: str,
    billing_period: str,
    amount_paise: int,
) -> None:
    with _write_lock:
        pending = _read_json(_pending_path())
        pending[order_id] = {
            "plan_id": plan_id,
            "billing_period": billing_period,
            "amount_paise": amount_paise,
            "created_at": _utc_now(),
        }
        _write_json(_pending_path(), pending)


def pop_pending_order(order_id: str) -> dict[str, Any] | None:
    with _write_lock:
        pending = _read_json(_pending_path())
        row = pending.pop(order_id, None)
        if row is not None:
            _write_json(_pending_path(), pending)
        return row if isinstance(row, dict) else None


def activate_from_verified_payment(
    *,
    order_id: str,
    payment_id: str,
    pending: dict[str, Any] | None,
) -> dict[str, Any] | None:
    """Persist subscription when pending metadata matches this order."""
    if not pending:
        logger.info("Razorpay verify: no pending order for %s", order_id)
        return None
    plan_id = str(pending.get("plan_id") or "")
    billing_period = str(pending.get("billing_period") or "")
    amount = int(pending.get("amount_paise") or 0)
    expected = catalog_amount_paise(plan_id, billing_period)
    if expected is None or amount != expected:
        logger.warning(
            "Razorpay verify: pending metadata invalid for %s plan=%r period=%r",
            order_id,
            plan_id,
            billing_period,
        )
        return None
    record = {
        "plan_id": plan_id,
        "billing_period": billing_period,
        "last_order_id": order_id,
        "last_payment_id": payment_id,
        "updated_at": _utc_now(),
    }
    with _write_lock:
        _write_json(_subscription_path(), record)
    logger.info("Subscription activated: %s (%s)", plan_id, billing_period)
    return record
