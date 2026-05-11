"use client";

import { Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { apiUrl, summarizeHttpErrorBody } from "@/lib/api";

/**
 * OAuth redirect URI handler for Google (OIDC/OAuth2).
 * Wire `POST /auth/oauth/google` (or your IdP exchange) on the API side;
 * this page reads ?code= & ?state= and can exchange via credentials include.
 */
function GoogleOAuthCallbackContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [asyncDetail, setAsyncDetail] = useState<string | null>(null);

  const code = searchParams.get("code");
  const state = searchParams.get("state");
  const oauthError = searchParams.get("error");

  const syncDetail =
    oauthError != null && oauthError !== ""
      ? `Provider error: ${oauthError}`
      : code == null || code === ""
        ? "Missing authorization code. Close this tab and try signing in again."
        : null;

  useEffect(() => {
    if (syncDetail != null || !code) return;

    /** Planned backend route — implement in `deeptutor/api/routers/auth.py`. */
    const exchangeUrl = apiUrl("/api/v1/auth/oauth/google/callback");

    let cancelled = false;
    void (async () => {
      try {
        const res = await fetch(exchangeUrl, {
          method: "POST",
          credentials: "include",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ code, state }),
        });
        if (!res.ok) {
          const text = await res.text();
          if (!cancelled) setAsyncDetail(summarizeHttpErrorBody(res.status, text));
          return;
        }
        if (!cancelled) setAsyncDetail("Signed in. Redirecting…");
        router.replace(state && state.startsWith("/") ? state : "/dashboard");
      } catch (e) {
        if (!cancelled)
          setAsyncDetail(
            e instanceof Error ? e.message : "Network error during OAuth exchange.",
          );
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [syncDetail, code, state, router]);

  const message =
    syncDetail ?? asyncDetail ?? "Completing Google sign-in…";

  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-[var(--background)] px-4">
      <div className="w-full max-w-md rounded-xl border border-[var(--border)] bg-[var(--card)] p-6 shadow-sm">
        <h1 className="text-lg font-semibold text-[var(--foreground)]">Google sign-in</h1>
        <p className="mt-3 text-sm text-[var(--muted-foreground)]">{message}</p>
        <div className="mt-6 flex flex-wrap gap-2">
          <Link
            href="/login"
            className="text-sm font-medium text-[var(--primary)] underline-offset-4 hover:underline"
          >
            Back to login
          </Link>
          <Link href="/" className="text-sm text-[var(--muted-foreground)] hover:text-[var(--foreground)]">
            Home
          </Link>
        </div>
      </div>
    </div>
  );
}

export default function GoogleOAuthCallbackPage() {
  return (
    <Suspense
      fallback={
        <div className="flex min-h-screen items-center justify-center bg-[var(--background)] text-sm text-[var(--muted-foreground)]">
          Loading…
        </div>
      }
    >
      <GoogleOAuthCallbackContent />
    </Suspense>
  );
}
