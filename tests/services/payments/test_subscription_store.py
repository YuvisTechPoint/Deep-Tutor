"""Catalog amounts for Razorpay subscription orders."""

from deeptutor.services.payments.subscription_store import catalog_amount_paise


def test_catalog_matches_ui_pricing() -> None:
    assert catalog_amount_paise("pro", "monthly") == 499_00
    assert catalog_amount_paise("pro", "annual") == 4_990_00
    assert catalog_amount_paise("team", "monthly") == 1_499_00
    assert catalog_amount_paise("pro", "hourly") == 49_00
    assert catalog_amount_paise("team", "hourly") == 149_00
    assert catalog_amount_paise("starter", "monthly") is None
