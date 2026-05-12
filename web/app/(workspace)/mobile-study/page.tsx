"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import {
  fetchGamificationState,
  fetchMissionsToday,
  type GamificationState,
  type MissionsToday,
} from "@/lib/workspace-api";

const ACCENT = "#D4734B";

const TILE_DEFS = [
  { href: "/chat", labelKey: "mobileStudy.tile_chat_label", subKey: "mobileStudy.tile_chat_sub" },
  {
    href: "/dashboard",
    labelKey: "mobileStudy.tile_dashboard_label",
    subKey: "mobileStudy.tile_dashboard_sub",
  },
  {
    href: "/roadmap",
    labelKey: "mobileStudy.tile_roadmap_label",
    subKey: "mobileStudy.tile_roadmap_sub",
  },
  {
    href: "/practice",
    labelKey: "mobileStudy.tile_practice_label",
    subKey: "mobileStudy.tile_practice_sub",
  },
  {
    href: "/revision",
    labelKey: "mobileStudy.tile_revision_label",
    subKey: "mobileStudy.tile_revision_sub",
  },
  {
    href: "/mock-test",
    labelKey: "mobileStudy.tile_mock_label",
    subKey: "mobileStudy.tile_mock_sub",
  },
  {
    href: "/missions",
    labelKey: "mobileStudy.tile_missions_label",
    subKey: "mobileStudy.tile_missions_sub",
  },
  {
    href: "/notifications",
    labelKey: "mobileStudy.tile_notifications_label",
    subKey: "mobileStudy.tile_notifications_sub",
  },
] as const;

export default function MobileStudyPage() {
  const { t } = useTranslation();
  const [gamification, setGamification] = useState<GamificationState | null>(null);
  const [missions, setMissions] = useState<MissionsToday | null>(null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const [g, m] = await Promise.all([
          fetchGamificationState(),
          fetchMissionsToday(),
        ]);
        if (!cancelled) {
          setGamification(g);
          setMissions(m);
        }
      } catch {
        if (!cancelled) {
          setGamification(null);
          setMissions(null);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const nextMission = useMemo(() => {
    if (!missions?.missions?.length) return null;
    return (
      missions.missions.find((x) => x.status === "available") ?? missions.missions[0]
    );
  }, [missions]);

  const level = gamification?.level?.level ?? 1;
  const totalXp = gamification?.level?.total_xp ?? gamification?.total_xp ?? 0;
  const streak = gamification?.streak_current ?? 0;
  const mDone = missions?.totals?.completed ?? 0;
  const mTotal = missions?.totals?.total ?? 0;

  return (
    <div className="flex h-full flex-col overflow-auto bg-[var(--background)] px-3 py-4 sm:px-4">
      <header className="mb-4 shrink-0">
        <p
          className="text-[10px] font-semibold uppercase tracking-[0.18em]"
          style={{ color: ACCENT }}
        >
          {t("mobileStudy.badge")}
        </p>
        <h1 className="mt-1 text-xl font-semibold tracking-tight text-[var(--foreground)]">
          {t("mobileStudy.title")}
        </h1>
        <p className="mt-1 text-sm text-[var(--muted-foreground)]">
          {t("mobileStudy.subtitle")}
        </p>
      </header>

      <section
        className="mb-4 shrink-0 rounded-2xl border border-[var(--border)]/70 bg-[var(--card)]/40 p-4 shadow-sm"
        style={{ borderColor: `${ACCENT}33` }}
      >
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
          {t("mobileStudy.stats_title")}
        </h2>
        <div className="mt-3 grid grid-cols-3 gap-2">
          <div className="rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/50 px-3 py-2">
            <div className="text-[10px] font-medium uppercase text-[var(--muted-foreground)]">
              {t("mobileStudy.metric_streak")}
            </div>
            <div className="mt-1 text-lg font-semibold tabular-nums text-[var(--foreground)]">
              {t("mobileStudy.metric_streak_value", { n: streak })}
            </div>
          </div>
          <div className="rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/50 px-3 py-2">
            <div className="text-[10px] font-medium uppercase text-[var(--muted-foreground)]">
              {t("mobileStudy.metric_level")}
            </div>
            <div className="mt-1 text-lg font-semibold tabular-nums text-[var(--foreground)]">
              {t("mobileStudy.metric_level_value", { level })}
            </div>
          </div>
          <div className="rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/50 px-3 py-2">
            <div className="text-[10px] font-medium uppercase text-[var(--muted-foreground)]">
              {t("mobileStudy.metric_xp")}
            </div>
            <div className="mt-1 text-lg font-semibold tabular-nums text-[var(--foreground)]">
              {t("mobileStudy.metric_xp_value", { xp: totalXp })}
            </div>
          </div>
        </div>
        <div className="mt-3 rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/50 px-3 py-2">
          <div className="text-[10px] font-medium uppercase text-[var(--muted-foreground)]">
            {t("mobileStudy.missions")}
          </div>
          <div className="mt-1 flex flex-wrap items-baseline justify-between gap-2">
            <span className="text-sm font-semibold tabular-nums text-[var(--foreground)]">
              {t("mobileStudy.missions_progress", {
                completed: mDone,
                total: Math.max(mTotal, 0) || 0,
              })}
            </span>
          </div>
          {nextMission ? (
            <Link
              href={nextMission.cta_href}
              className="mt-2 block truncate text-xs font-medium text-[var(--primary)] underline-offset-2 hover:underline"
            >
              <span className="text-[var(--muted-foreground)]">
                {t("mobileStudy.next_up")}:{" "}
              </span>
              {nextMission.title}
            </Link>
          ) : (
            <p className="mt-2 text-xs text-[var(--muted-foreground)]">
              {t("mobileStudy.no_missions")}
            </p>
          )}
        </div>
      </section>

      <ul className="grid grid-cols-1 gap-2 pb-safe sm:grid-cols-2">
        {TILE_DEFS.map((tile) => (
          <li key={tile.href}>
            <Link
              href={tile.href}
              className="flex min-h-[4.5rem] flex-col justify-center rounded-xl border border-[var(--border)] bg-[var(--card)] px-4 py-3 shadow-sm transition active:scale-[0.99] hover:border-[var(--primary)]"
            >
              <span className="text-base font-medium text-[var(--foreground)]">
                {t(tile.labelKey)}
              </span>
              <span className="text-xs text-[var(--muted-foreground)]">{t(tile.subKey)}</span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
