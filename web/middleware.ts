import { NextRequest, NextResponse } from "next/server";

const AUTH_ENABLED = process.env.NEXT_PUBLIC_AUTH_ENABLED === "true";

/**
 * Edge middleware must read explicit `process.env.NEXT_PUBLIC_*` names here so values
 * are inlined (same pattern as `external-auth.ts`). Do not import shared helpers if the
 * bundler fails to inline indirect references.
 */
function middlewareMarketingLoginUrl(extra: Record<string, string>): string {
  const explicit = (process.env.NEXT_PUBLIC_STREAMLIT_LOGIN_URL ?? "").trim();
  if (explicit) {
    try {
      const u = new URL(explicit);
      for (const [k, v] of Object.entries(extra)) {
        if (v !== undefined && v !== "") u.searchParams.set(k, v);
      }
      return u.toString();
    } catch {
      return explicit;
    }
  }

  const base = (process.env.NEXT_PUBLIC_STREAMLIT_APP_URL ?? "").trim();
  if (base) {
    try {
      const u = new URL(base);
      if (!u.searchParams.has("mode")) u.searchParams.set("mode", "login");
      for (const [k, v] of Object.entries(extra)) {
        if (v !== undefined && v !== "") u.searchParams.set(k, v);
      }
      return u.toString();
    } catch {
      return base;
    }
  }

  const sp = new URLSearchParams(extra);
  const qs = sp.toString();
  return qs ? `/login?${qs}` : "/login";
}
const LOGIN_PATH = "/login";
const COOKIE_NAME = "dt_token";

/** Public routes when auth is enabled (marketing + account flows). */
const PUBLIC_EXACT = new Set([
  "/",
  LOGIN_PATH,
  "/register",
  "/forgot-password",
  "/otp",
  "/institution",
  /** Google OAuth redirect handler (must be reachable before session cookie exists). */
  "/auth/callback/google",
  /** Alias route kept for bookmarks / older links (canonical UI lives under `/recruiter/login`). */
  "/recruiter-login",
]);

const PUBLIC_PREFIXES = ["/recruiter/login"];

function isPublicPath(pathname: string): boolean {
  if (PUBLIC_EXACT.has(pathname)) return true;
  return PUBLIC_PREFIXES.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`),
  );
}

export function middleware(req: NextRequest) {
  // Auth is disabled (default) — let everything through
  if (!AUTH_ENABLED) return NextResponse.next();

  const { pathname } = req.nextUrl;

  if (isPublicPath(pathname)) {
    return NextResponse.next();
  }

  if (pathname.startsWith("/_next") || pathname.startsWith("/favicon")) {
    return NextResponse.next();
  }

  const token = req.cookies.get(COOKIE_NAME)?.value;

  // No token — redirect to login (Next or external Streamlit), preserving destination
  if (!token) {
    const dest = middlewareMarketingLoginUrl({ next: pathname });
    if (dest.startsWith("http://") || dest.startsWith("https://")) {
      return NextResponse.redirect(dest);
    }
    return NextResponse.redirect(new URL(dest, req.nextUrl.origin));
  }

  return NextResponse.next();
}

export const config = {
  // Run on all page routes, skip API and static assets
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico).*)"],
};
