/**
 * Optional integration with an external auth UI (e.g. Streamlit).
 *
 * Set in repo-root `.env` or `web/.env` / `web/.env.local` (see next.config.js).
 *
 * - NEXT_PUBLIC_STREAMLIT_APP_URL=http://127.0.0.1:8501
 *   → signup CTAs use `${APP_URL}?mode=signup` (+ optional query params)
 *   → sign-in CTAs use `${APP_URL}?mode=login`
 *
 * Or override with full URLs:
 *
 * - NEXT_PUBLIC_STREAMLIT_SIGNUP_URL
 * - NEXT_PUBLIC_STREAMLIT_LOGIN_URL
 *
 * Your Streamlit app can branch with `st.query_params.get("mode")`.
 * Extra params (e.g. plan=pro from pricing) are merged onto the URL.
 *
 * IMPORTANT: Read each NEXT_PUBLIC_* with a direct `process.env.NAME` reference.
 * Dynamic keys (`process.env[key]`) are not inlined by Next.js, so CTAs would
 * always fall back to `/login` and `/register` in the browser and middleware.
 */

function streamlitSignupUrlRaw(): string {
  return process.env.NEXT_PUBLIC_STREAMLIT_SIGNUP_URL?.trim() ?? "";
}

function streamlitLoginUrlRaw(): string {
  return process.env.NEXT_PUBLIC_STREAMLIT_LOGIN_URL?.trim() ?? "";
}

function streamlitAppUrlRaw(): string {
  return process.env.NEXT_PUBLIC_STREAMLIT_APP_URL?.trim() ?? "";
}

function applyParams(url: URL, params: Record<string, string>): void {
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== "") url.searchParams.set(k, v);
  }
}

/** Sign-up / Get started / Start Learning Free — defaults to `/register`. */
export function marketingSignupUrl(extraQuery: Record<string, string> = {}): string {
  const explicit = streamlitSignupUrlRaw();
  if (explicit) {
    try {
      const u = new URL(explicit);
      applyParams(u, extraQuery);
      return u.toString();
    } catch {
      return explicit;
    }
  }

  const base = streamlitAppUrlRaw();
  if (base) {
    try {
      const u = new URL(base);
      if (!u.searchParams.has("mode")) u.searchParams.set("mode", "signup");
      applyParams(u, extraQuery);
      return u.toString();
    } catch {
      return base;
    }
  }

  const sp = new URLSearchParams(extraQuery);
  const qs = sp.toString();
  return qs ? `/register?${qs}` : "/register";
}

/** Sign-in — defaults to `/login`. */
export function marketingLoginUrl(extraQuery: Record<string, string> = {}): string {
  const explicit = streamlitLoginUrlRaw();
  if (explicit) {
    try {
      const u = new URL(explicit);
      applyParams(u, extraQuery);
      return u.toString();
    } catch {
      return explicit;
    }
  }

  const base = streamlitAppUrlRaw();
  if (base) {
    try {
      const u = new URL(base);
      if (!u.searchParams.has("mode")) u.searchParams.set("mode", "login");
      applyParams(u, extraQuery);
      return u.toString();
    } catch {
      return base;
    }
  }

  const sp = new URLSearchParams(extraQuery);
  const qs = sp.toString();
  return qs ? `/login?${qs}` : "/login";
}

/** Full-page navigation to the configured signup URL (use when Next router cannot handle external URLs). */
export function assignMarketingSignup(): void {
  if (typeof window === "undefined") return;
  window.location.assign(marketingSignupUrl());
}

/** Full-page navigation to the configured sign-in URL (logout, 401 recovery, post-register). */
export function assignMarketingLogin(extraQuery: Record<string, string> = {}): void {
  if (typeof window === "undefined") return;
  window.location.assign(marketingLoginUrl(extraQuery));
}

/** Turn `/register` or `/register?plan=pro` into the correct destination. */
export function resolveSignupHref(internalHref: string): string {
  if (!internalHref.startsWith("/register")) return internalHref;
  const q = internalHref.includes("?") ? internalHref.split("?")[1] ?? "" : "";
  const params = Object.fromEntries(new URLSearchParams(q));
  return marketingSignupUrl(params);
}
