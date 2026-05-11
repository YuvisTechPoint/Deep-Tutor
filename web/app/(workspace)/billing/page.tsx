"use client";

import { useCallback, useEffect, useState } from "react";
import { RazorpayPayButton } from "@/components/payments/RazorpayPayButton";
import { fetchRazorpayStatus } from "@/lib/payments-api";

/** Demo: ₹499.00 — adjust amount or wire to your catalog. */
const DEMO_AMOUNT_PAISE = 499_00;

export default function BillingPage() {
  const [status, setStatus] = useState<{
    configured: boolean;
    key_id_set: boolean;
  } | null>(null);
  const [statusError, setStatusError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const publicKey = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID?.trim();

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const s = await fetchRazorpayStatus();
        if (!cancelled) {
          setStatus(s);
          setStatusError(null);
        }
      } catch (e) {
        if (!cancelled) {
          setStatus(null);
          setStatusError(e instanceof Error ? e.message : "Could not reach payments API");
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const onPaid = useCallback((info: { orderId: string; paymentId: string }) => {
    setToast(`Payment verified. Order ${info.orderId}, payment ${info.paymentId}`);
  }, []);

  const onError = useCallback((message: string) => {
    setToast(message);
  }, []);

  return (
    <div className="h-full overflow-auto p-6 sm:p-8">
      <h1 className="text-xl font-semibold tracking-tight">Billing & payments</h1>
      <p className="mt-2 max-w-2xl text-sm text-[var(--muted-foreground)]">
        Test Razorpay Standard Checkout. The backend creates an order and verifies the
        payment signature; the key secret never leaves the server.
      </p>

      <div className="mt-6 max-w-xl rounded-xl border border-[var(--border)] bg-[var(--card)] p-5 shadow-sm">
        <h2 className="text-sm font-semibold">Configuration</h2>
        <ul className="mt-2 space-y-1 text-sm text-[var(--muted-foreground)]">
          <li>
            Backend Razorpay:{" "}
            {status === null && !statusError ? (
              <span>checking…</span>
            ) : statusError ? (
              <span className="text-amber-600 dark:text-amber-400">{statusError}</span>
            ) : status?.configured ? (
              <span className="text-emerald-600 dark:text-emerald-400">ready</span>
            ) : (
              <span className="text-amber-600 dark:text-amber-400">
                set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in project `.env`
              </span>
            )}
          </li>
          <li>
            Public key for checkout:{" "}
            {publicKey ? (
              <span className="text-emerald-600 dark:text-emerald-400">NEXT_PUBLIC_RAZORPAY_KEY_ID set</span>
            ) : (
              <span className="text-amber-600 dark:text-amber-400">
                set NEXT_PUBLIC_RAZORPAY_KEY_ID (or rely on start_web.py mirroring from `.env`)
              </span>
            )}
          </li>
        </ul>

        <div className="mt-6 border-t border-[var(--border)] pt-5">
          <p className="text-sm text-[var(--muted-foreground)]">
            Demo charge: ₹{(DEMO_AMOUNT_PAISE / 100).toFixed(2)} ({DEMO_AMOUNT_PAISE} paise)
          </p>
          <div className="mt-3">
            <RazorpayPayButton
              amountPaise={DEMO_AMOUNT_PAISE}
              description="DeepTutor — demo subscription"
              onPaid={onPaid}
              onError={onError}
            />
          </div>
        </div>
      </div>

      {toast ? (
        <p
          className="mt-4 max-w-xl rounded-lg border border-[var(--border)] bg-[var(--muted)]/30 px-3 py-2 text-sm"
          role="status"
        >
          {toast}
        </p>
      ) : null}
    </div>
  );
}
