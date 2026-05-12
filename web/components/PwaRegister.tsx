"use client";

import { useEffect } from "react";
import { flushOfflineQueue } from "@/lib/offline-queue";

export function PwaRegister() {
  useEffect(() => {
    if (typeof window === "undefined" || !("serviceWorker" in navigator)) return;

    const register = async () => {
      try {
        await navigator.serviceWorker.register("/sw.js", { scope: "/" });
      } catch {
        /* ignore */
      }
    };
    void register();

    const onOnline = () => {
      void flushOfflineQueue().then(({ sent }) => {
        if (sent > 0) {
          window.dispatchEvent(new CustomEvent("deeptutor-offline-flush", { detail: { sent } }));
        }
      });
    };
    window.addEventListener("online", onOnline);
    void flushOfflineQueue();

    return () => window.removeEventListener("online", onOnline);
  }, []);

  return null;
}
