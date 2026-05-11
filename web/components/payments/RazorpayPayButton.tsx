"use client";

import { useCallback, useState } from "react";
import {
  createRazorpayOrder,
  verifyRazorpayPayment,
} from "@/lib/payments-api";

declare global {
  interface Window {
    Razorpay?: new (options: Record<string, unknown>) => { open: () => void };
  }
}

const CHECKOUT_SCRIPT = "https://checkout.razorpay.com/v1/checkout.js";

function loadRazorpayScript(): Promise<void> {
  if (typeof window === "undefined") {
    return Promise.reject(new Error("Razorpay must run in the browser"));
  }
  if (window.Razorpay) {
    return Promise.resolve();
  }
  return new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      `script[src="${CHECKOUT_SCRIPT}"]`,
    );
    if (existing) {
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener(
        "error",
        () => reject(new Error("Failed to load Razorpay")),
        { once: true },
      );
      return;
    }
    const s = document.createElement("script");
    s.src = CHECKOUT_SCRIPT;
    s.async = true;
    s.onload = () => resolve();
    s.onerror = () => reject(new Error("Failed to load Razorpay"));
    document.body.appendChild(s);
  });
}

type Props = {
  amountPaise: number;
  currency?: string;
  description: string;
  companyName?: string;
  disabled?: boolean;
  onPaid?: (info: { orderId: string; paymentId: string }) => void;
  onError?: (message: string) => void;
};

export function RazorpayPayButton({
  amountPaise,
  currency = "INR",
  description,
  companyName = "DeepTutor",
  disabled,
  onPaid,
  onError,
}: Props) {
  const [busy, setBusy] = useState(false);
  const keyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID?.trim();

  const pay = useCallback(async () => {
    if (!keyId) {
      onError?.("Missing NEXT_PUBLIC_RAZORPAY_KEY_ID (set in .env or web/.env.local)");
      return;
    }
    setBusy(true);
    try {
      await loadRazorpayScript();
      const order = await createRazorpayOrder(amountPaise, currency);
      const Razorpay = window.Razorpay;
      if (!Razorpay) {
        throw new Error("Razorpay SDK not available");
      }

      const options: Record<string, unknown> = {
        key: keyId,
        amount: order.amount,
        currency: order.currency,
        order_id: order.order_id,
        name: companyName,
        description,
        theme: { color: "#b0501e" },
        handler: async (response: {
          razorpay_payment_id: string;
          razorpay_order_id: string;
          razorpay_signature: string;
        }) => {
          try {
            const verified = await verifyRazorpayPayment({
              razorpay_order_id: response.razorpay_order_id,
              razorpay_payment_id: response.razorpay_payment_id,
              razorpay_signature: response.razorpay_signature,
            });
            if (verified.ok) {
              onPaid?.({
                orderId: verified.order_id,
                paymentId: verified.payment_id,
              });
            }
          } catch (e) {
            const msg = e instanceof Error ? e.message : "Verification failed";
            onError?.(msg);
          } finally {
            setBusy(false);
          }
        },
        modal: {
          ondismiss: () => {
            setBusy(false);
          },
        },
      };

      const rz = new Razorpay(options);
      rz.open();
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Payment could not start";
      onError?.(msg);
      setBusy(false);
    }
  }, [
    amountPaise,
    companyName,
    currency,
    description,
    keyId,
    onError,
    onPaid,
  ]);

  return (
    <button
      type="button"
      disabled={disabled || busy || !keyId}
      onClick={() => void pay()}
      className="rounded-lg bg-[var(--primary)] px-4 py-2 text-sm font-medium text-[var(--primary-foreground)] shadow-sm transition hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
    >
      {busy ? "Opening checkout…" : "Pay with Razorpay"}
    </button>
  );
}
