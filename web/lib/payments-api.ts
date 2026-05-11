import { apiFetch, apiUrl, summarizeHttpErrorBody } from "@/lib/api";

export type RazorpayOrderResponse = {
  order_id: string;
  amount: number;
  currency: string;
  receipt?: string | null;
};

export type RazorpayStatusResponse = {
  configured: boolean;
  key_id_set: boolean;
};

export async function fetchRazorpayStatus(): Promise<RazorpayStatusResponse> {
  const res = await apiFetch(apiUrl("/api/v1/payments/razorpay/status"));
  if (!res.ok) {
    const text = await res.text();
    throw new Error(summarizeHttpErrorBody(res.status, text));
  }
  return res.json() as Promise<RazorpayStatusResponse>;
}

export async function createRazorpayOrder(
  amountPaise: number,
  currency = "INR",
): Promise<RazorpayOrderResponse> {
  const res = await apiFetch(apiUrl("/api/v1/payments/razorpay/order"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ amount: amountPaise, currency }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(summarizeHttpErrorBody(res.status, text));
  }
  return res.json() as Promise<RazorpayOrderResponse>;
}

export async function verifyRazorpayPayment(payload: {
  razorpay_order_id: string;
  razorpay_payment_id: string;
  razorpay_signature: string;
}): Promise<{ ok: boolean; order_id: string; payment_id: string }> {
  const res = await apiFetch(apiUrl("/api/v1/payments/razorpay/verify"), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(summarizeHttpErrorBody(res.status, text));
  }
  return res.json() as Promise<{ ok: boolean; order_id: string; payment_id: string }>;
}
