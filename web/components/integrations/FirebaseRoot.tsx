"use client";

import { useEffect } from "react";
import { isFirebaseConfigured } from "@/lib/firebase-client";

/**
 * Optionally initializes Firebase Analytics.
 *
 * Analytics calls the Firebase Installations API. A browser API key that is
 * HTTP-referrer restricted without the right entries, or a mismatched web app
 * config, produces 403 PERMISSION_DENIED in the console. Analytics is therefore
 * **opt-in** via ``NEXT_PUBLIC_FIREBASE_ENABLE_ANALYTICS=true`` so Google Sign-In
 * (Auth only) still works without touching Installations on every page load.
 */
export function FirebaseRoot() {
  useEffect(() => {
    // Skip entirely if Firebase is not configured
    if (!isFirebaseConfigured()) {
      return;
    }

    if (process.env.NEXT_PUBLIC_FIREBASE_ENABLE_ANALYTICS !== "true") {
      return;
    }

    // Only proceed with Analytics if measurement id is present
    if (!process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID?.trim()) {
      return;
    }

    let cancelled = false;

    // Lazy-load Firebase modules only when Firebase is properly configured
    void (async () => {
      try {
        const { getFirebaseApp } = await import("@/lib/firebase-client");
        const app = getFirebaseApp();
        if (!app || cancelled) return;

        const { getAnalytics, isSupported } = await import("firebase/analytics");
        const supported = await isSupported();

        if (supported && !cancelled && app) {
          try {
            getAnalytics(app);
          } catch {
            // Silently ignore duplicate initialization or other errors
            // Firebase handles this internally
          }
        }
      } catch (error) {
        // Silently ignore Firebase initialization errors when not fully configured
        if (cancelled) return;
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  return null;
}
