"use client";

import { useCallback, useEffect, useState } from "react";
import {
  getLearningProfile,
  type LearningProfile,
} from "@/lib/learning-profile-api";
import { LEARNING_PROFILE_UPDATED } from "@/lib/learning-profile-events";
import {
  fetchGamificationState,
  type GamificationState,
} from "@/lib/workspace-api";

const POLL_MS = 12_000;

/**
 * Keeps learning profile + gamification stats fresh: polling while the tab is
 * visible, refetch on focus/visibility, and instant refetch when
 * `notifyLearningProfileUpdated()` runs (e.g. after onboarding saves).
 */
export function useLiveLearningSnapshot(enabled = true) {
  const [profile, setProfile] = useState<LearningProfile | null>(null);
  const [game, setGame] = useState<GamificationState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastRefresh, setLastRefresh] = useState<number | null>(null);

  const refresh = useCallback(async () => {
    if (!enabled) return;
    try {
      const [p, g] = await Promise.all([
        getLearningProfile(),
        fetchGamificationState(),
      ]);
      setProfile(p);
      setGame(g);
      setError(null);
      setLastRefresh(Date.now());
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load");
    } finally {
      setLoading(false);
    }
  }, [enabled]);

  useEffect(() => {
    if (!enabled) return;
    void refresh();
  }, [enabled, refresh]);

  useEffect(() => {
    if (!enabled) return;

    const pullIfVisible = () => {
      if (document.visibilityState === "visible") void refresh();
    };

    document.addEventListener("visibilitychange", pullIfVisible);
    window.addEventListener("focus", pullIfVisible);

    const interval = window.setInterval(pullIfVisible, POLL_MS);

    const onProfileUpdated = () => void refresh();
    window.addEventListener(LEARNING_PROFILE_UPDATED, onProfileUpdated);

    return () => {
      document.removeEventListener("visibilitychange", pullIfVisible);
      window.removeEventListener("focus", pullIfVisible);
      window.clearInterval(interval);
      window.removeEventListener(LEARNING_PROFILE_UPDATED, onProfileUpdated);
    };
  }, [enabled, refresh]);

  return { profile, game, loading, error, refresh, lastRefresh };
}
