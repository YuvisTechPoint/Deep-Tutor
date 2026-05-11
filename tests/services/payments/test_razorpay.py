import hashlib
import hmac

from deeptutor.services.payments.razorpay import verify_payment_signature


def test_verify_payment_signature_accepts_valid_hmac():
    secret = "wubba_lubba"
    order_id = "order_abc"
    payment_id = "pay_xyz"
    expected = hmac.new(
        secret.encode("utf-8"),
        f"{order_id}|{payment_id}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    assert verify_payment_signature(order_id, payment_id, expected, secret)


def test_verify_payment_signature_rejects_tampered_signature():
    secret = "wubba_lubba"
    order_id = "order_abc"
    payment_id = "pay_xyz"
    expected = hmac.new(
        secret.encode("utf-8"),
        f"{order_id}|{payment_id}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    assert not verify_payment_signature(order_id, payment_id, expected + "0", secret)
