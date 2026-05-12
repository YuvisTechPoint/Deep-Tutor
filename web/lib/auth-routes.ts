/**
 * Post-login navigation and safe `?next=` handling (open-redirect hardening).
 * Keep defaults aligned with `middleware.ts` (authenticated `/` → workspace hub).
 */

export const DEFAULT_POST_LOGIN_PATH = "/dashboard";

/**
 * Returns a same-origin path safe to pass to `router.replace` / `location.assign`.
 * Rejects protocol-relative URLs, backslashes, and auth-loop targets.
 */
export function sanitizeInternalNextPath(
  raw: string | null | undefined,
  fallback: string = DEFAULT_POST_LOGIN_PATH,
): string {
  if (raw == null || typeof raw !== "string") return fallback;
  const t = raw.trim();
  if (t === "" || !t.startsWith("/") || t.startsWith("//")) return fallback;
  if (t.includes("://") || t.includes("\\")) return fallback;

  const pathOnly = (t.split("?")[0] ?? t).split("#")[0] ?? t;

  if (pathOnly === "/") return fallback;

  const authLoop = new Set([
    "/login",
    "/register",
    "/forgot-password",
    "/otp",
    "/institution",
    "/recruiter-login",
    "/auth/callback/google",
  ]);
  if (authLoop.has(pathOnly)) return fallback;
  if (pathOnly.startsWith("/recruiter/login")) return fallback;

  return t;
}
