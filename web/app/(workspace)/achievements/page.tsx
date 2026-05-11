"use client";

import { useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import {
  Award,
  Crown,
  Flame,
  Loader2,
  Lock,
  Star,
  Trophy,
  Users,
  Zap,
} from "lucide-react";

import {
  fetchAchievements,
  fetchGamificationState,
  fetchLeaderboard,
  fetchXPHistory,
  type AchievementsBundle,
  type BadgeStatus,
  type GamificationState,
  type XPHistoryItem,
} from "@/lib/workspace-api";

type FilterTab = "all" | "unlocked" | "in-progress" | "locked";

const ACCENT = "#D4734B";

function utcTodayYmd(): string {
  const n = new Date();
  return `${n.getUTCFullYear()}-${String(n.getUTCMonth() + 1).padStart(2, "0")}-${String(
    n.getUTCDate(),
  ).padStart(2, "0")}`;
}

function last7UtcYmd(): string[] {
  const n = new Date();
  const y = n.getUTCFullYear();
  const mo = n.getUTCMonth();
  const d = n.getUTCDate();
  const out: string[] = [];
  for (let i = 6; i >= 0; i -= 1) {
    const t = new Date(Date.UTC(y, mo, d - i));
    out.push(
      `${t.getUTCFullYear()}-${String(t.getUTCMonth() + 1).padStart(2, "0")}-${String(
        t.getUTCDate(),
      ).padStart(2, "0")}`,
    );
  }
  return out;
}

function weekdayNarrowUtc(iso: string, locale: string): string {
  const [yy, mm, dd] = iso.split("-").map(Number);
  const dt = new Date(Date.UTC(yy, mm - 1, dd));
  return dt.toLocaleDateString(locale || "en", {
    weekday: "narrow",
    timeZone: "UTC",
  });
}

function StreakStudySection({ state }: { state: GamificationState }) {
  const { t, i18n } = useTranslation();
  const locale = i18n.resolvedLanguage || i18n.language || "en";
  const activeSet = useMemo(() => new Set(state.active_days), [state.active_days]);
  const weekDays = useMemo(() => last7UtcYmd(), [state.last_synced_at]);
  const weekXp = useMemo(() => {
    let sum = 0;
    for (const iso of weekDays) {
      sum += state.xp_per_day[iso] ?? 0;
    }
    return sum;
  }, [state.xp_per_day, weekDays]);

  const todayIso = utcTodayYmd();
  const studiedToday = activeSet.has(todayIso);
  const hintKey = studiedToday
    ? "achievements.streak_hint_today"
    : state.streak_current > 0
      ? "achievements.streak_hint_grace"
      : "achievements.streak_hint_start";

  return (
    <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-start gap-3">
          <div
            className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl border border-[#D4734B]/35 bg-gradient-to-br from-[#D4734B]/25 to-[#5c3018]/15 shadow-inner"
            style={{ color: ACCENT }}
          >
            <Flame className="h-6 w-6" strokeWidth={2} />
          </div>
          <div>
            <h2 className="text-sm font-semibold text-[var(--foreground)]">
              {t("achievements.streak_title")}
            </h2>
            <p className="mt-0.5 max-w-xl text-xs leading-relaxed text-[var(--muted-foreground)]">
              {t("achievements.streak_subtitle")}
            </p>
          </div>
        </div>
        <div className="flex flex-wrap gap-3 sm:justify-end">
          <div className="rounded-xl border border-[#D4734B]/25 bg-[#D4734B]/10 px-4 py-2.5 text-center sm:text-left">
            <p className="text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
              {t("achievements.streak_current_label")}
            </p>
            <p className="text-xl font-bold tabular-nums text-[#D4734B]">
              {t("achievements.streak_days", { n: state.streak_current })}
            </p>
          </div>
          <div className="rounded-xl border border-white/10 bg-white/5 px-4 py-2.5 text-center sm:text-left">
            <p className="text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
              {t("achievements.streak_best_label")}
            </p>
            <p className="text-xl font-bold tabular-nums text-[var(--foreground)]">
              {t("achievements.streak_days", { n: state.streak_max })}
            </p>
          </div>
        </div>
      </div>

      <p className="mb-4 text-xs leading-relaxed text-[var(--muted-foreground)]">{t(hintKey)}</p>

      <div className="mb-2 flex items-center justify-between gap-2">
        <p className="text-[11px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
          {t("achievements.streak_week_heading")}
        </p>
        <p className="text-[11px] text-[var(--muted-foreground)]">
          <span className="font-medium text-[var(--foreground)]">
            {t("achievements.streak_week_xp")}
          </span>
          {": "}
          <span className="font-mono tabular-nums text-[#D4734B]">
            {t("achievements.streak_week_xp_value", { xp: weekXp.toLocaleString() })}
          </span>
        </p>
      </div>

      <div className="flex justify-between gap-1.5 sm:gap-2">
        {weekDays.map((iso) => {
          const active = activeSet.has(iso);
          const label = weekdayNarrowUtc(iso, locale);
          return (
            <div
              key={iso}
              className="flex min-w-0 flex-1 flex-col items-center gap-1.5"
              title={`${iso}${active ? ` — ${t("achievements.streak_day_active")}` : ` — ${t("achievements.streak_day_rest")}`}`}
            >
              <div
                className={`flex h-9 w-9 items-center justify-center rounded-full border text-[11px] font-semibold sm:h-10 sm:w-10 ${
                  active
                    ? "border-[#D4734B]/50 bg-gradient-to-br from-[#D4734B] to-[#b85a3a] text-white shadow-md shadow-[#D4734B]/20"
                    : "border-white/10 bg-white/5 text-[var(--muted-foreground)]"
                }`}
              >
                {active ? <Zap className="h-4 w-4" /> : <span className="opacity-50">·</span>}
              </div>
              <span className="w-full truncate text-center text-[9px] font-medium uppercase text-[var(--muted-foreground)] sm:text-[10px]">
                {label}
              </span>
              <span className="hidden text-[8px] text-[var(--muted-foreground)]/80 sm:block">
                {iso.slice(8)}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

export default function AchievementsPage() {
  const { t } = useTranslation();
  const [filter, setFilter] = useState<FilterTab>("all");
  const [bundle, setBundle] = useState<AchievementsBundle | null>(null);
  const [gamification, setGamification] = useState<GamificationState | null>(null);
  const [leaderboard, setLeaderboard] = useState<
    { rank: number; name: string; level: number; xp: number; you: boolean }[]
  >([]);
  const [isPreview, setIsPreview] = useState(false);
  const [xpHistory, setXpHistory] = useState<XPHistoryItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const [b, l, h, g] = await Promise.all([
          fetchAchievements(),
          fetchLeaderboard(),
          fetchXPHistory(5),
          fetchGamificationState(),
        ]);
        if (cancelled) return;
        setBundle(b);
        setGamification(g);
        setLeaderboard(l.rows);
        setIsPreview(l.preview);
        setXpHistory(h.items);
      } catch (e) {
        if (!cancelled) {
          setError(
            e instanceof Error
              ? e.message
              : t("achievements.load_error", {
                  defaultValue: "Failed to load achievements",
                }),
          );
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center gap-2 text-[var(--muted-foreground)]">
        <Loader2 className="h-5 w-5 animate-spin" />
        <span>{t("achievements.loading", { defaultValue: "Loading achievements…" })}</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex h-screen items-center justify-center px-6">
        <div className="max-w-md rounded-2xl border border-[#D4734B]/30 bg-[#D4734B]/10 px-6 py-4 text-sm text-[#f0c4b8]">
          {error}
        </div>
      </div>
    );
  }

  if (!bundle) return null;
  const achievements = bundle.achievements;
  const filtered =
    filter === "all" ? achievements : achievements.filter((a) => a.status === filter);
  const unlockedCount = achievements.filter((a) => a.status === "unlocked").length;
  const inProgressCount = achievements.filter((a) => a.status === "in-progress").length;
  const lockedCount = achievements.length - unlockedCount - inProgressCount;
  const specialBadges = achievements
    .filter((a) => a.status === "unlocked" && a.rare)
    .slice(0, 3);

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-lg font-semibold text-[var(--foreground)]">
              Achievements & XP
            </h1>
            <p className="text-sm text-[var(--muted-foreground)]">
              Your journey, badges and gamification progress
            </p>
          </div>
          <div className="flex items-center gap-2 rounded-xl border border-[#D4734B]/25 bg-[#D4734B]/10 px-3 py-1.5">
            <Crown size={15} className="text-[#D4734B]" />
            <span className="text-sm font-bold text-[#D4734B]">
              Level {bundle.level.level}
            </span>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto p-6 space-y-6">
        <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-[#D4734B] to-[#b85a3a] text-lg font-bold text-white shadow-md shadow-[#D4734B]/25">
                {bundle.level.level}
              </div>
              <div>
                <p className="text-sm font-semibold text-[var(--foreground)]">
                  Level {bundle.level.level} — Scholar
                </p>
                <p className="text-xs text-[var(--muted-foreground)]">
                  {bundle.level.xp_into_level.toLocaleString()} /
                  {" "}
                  {bundle.level.xp_for_next_level.toLocaleString()} XP into level
                </p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-xs text-[var(--muted-foreground)]">Next Level</p>
              <p className="text-sm font-semibold text-[#D4734B]">
                {(
                  bundle.level.xp_for_next_level - bundle.level.xp_into_level
                ).toLocaleString()}{" "}
                XP away
              </p>
            </div>
          </div>
          <div className="h-3 bg-white/5 rounded-full overflow-hidden">
            <div
              className="h-full rounded-full bg-gradient-to-r from-[#D4734B] to-[#b85a3a]"
              style={{ width: `${bundle.level.progress_pct}%` }}
            />
          </div>
          <div className="flex justify-between text-xs text-[var(--muted-foreground)] mt-1.5">
            <span>Level {bundle.level.level}</span>
            <span>{bundle.level.progress_pct}%</span>
            <span>Level {bundle.level.level + 1}</span>
          </div>
        </div>

        {gamification ? <StreakStudySection state={gamification} /> : null}

        {specialBadges.length > 0 && (
          <div>
            <div className="flex items-center gap-2 mb-3">
              <Star size={15} className="text-[#D4734B]" />
              <h2 className="text-sm font-medium text-[var(--foreground)]">
                Special Badges
              </h2>
            </div>
            <div className="flex flex-wrap gap-3">
              {specialBadges.map((b) => (
                <div
                  key={b.badge_id}
                  className="flex items-center gap-3 rounded-xl border border-[#D4734B]/30 bg-[#D4734B]/10 px-4 py-3"
                >
                  <span className="text-2xl">{b.icon}</span>
                  <span className="text-sm font-medium text-[var(--foreground)]">
                    {b.title}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex items-center gap-1 border-b border-white/5">
          {(
            [
              { key: "all", label: `All (${achievements.length})` },
              { key: "unlocked", label: `Unlocked (${unlockedCount})` },
              { key: "in-progress", label: `In Progress (${inProgressCount})` },
              { key: "locked", label: `Locked (${lockedCount})` },
            ] as { key: FilterTab; label: string }[]
          ).map(({ key, label }) => (
            <button
              key={key}
              type="button"
              onClick={() => setFilter(key)}
              className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors ${
                filter === key
                  ? "border-[#D4734B] text-[#D4734B]"
                  : "border-transparent text-[var(--muted-foreground)] hover:text-[var(--foreground)]"
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.length === 0 && (
            <p className="text-xs text-[var(--muted-foreground)]">
              No achievements in this category yet.
            </p>
          )}
          {filtered.map((ach: BadgeStatus) => (
            <div
              key={ach.badge_id}
              className={`rounded-2xl border p-4 transition-all ${
                ach.status === "locked"
                  ? "border-white/3 bg-white/2 opacity-60"
                  : ach.status === "unlocked"
                    ? ach.rare
                      ? "border-[#D4734B]/25 bg-gradient-to-br from-[#D4734B]/12 to-[#5c3018]/6"
                      : "border-white/5 bg-[var(--secondary)]"
                    : "border-white/5 bg-[var(--secondary)]"
              }`}
            >
              <div className="flex items-start justify-between mb-2">
                <div className="flex items-center gap-2">
                  <span className="text-2xl">{ach.icon}</span>
                  {ach.status === "locked" && (
                    <Lock size={12} className="text-[var(--muted-foreground)]" />
                  )}
                  {ach.status === "unlocked" && (
                    <Trophy size={12} className="text-[#D4734B]" />
                  )}
                </div>
                <span className="flex items-center gap-1 text-xs font-medium text-[#D4734B]">
                  <Zap size={10} />
                  {ach.xp_reward}
                </span>
              </div>
              <p className="text-sm font-semibold text-[var(--foreground)] mb-0.5">
                {ach.title}
              </p>
              <p className="text-xs text-[var(--muted-foreground)] mb-2 leading-relaxed">
                {ach.description}
              </p>
              {ach.status === "in-progress" &&
                ach.progress !== null &&
                ach.progress_max != null && (
                  <div>
                    <div className="flex justify-between text-[10px] text-[var(--muted-foreground)] mb-1">
                      <span>
                        {ach.progress} / {ach.progress_max}
                      </span>
                      <span>
                        {Math.round(((ach.progress ?? 0) / (ach.progress_max ?? 1)) * 100)}%
                      </span>
                    </div>
                    <div className="h-1.5 bg-white/5 rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full bg-[#D4734B]"
                        style={{
                          width: `${Math.round(((ach.progress ?? 0) / (ach.progress_max ?? 1)) * 100)}%`,
                        }}
                      />
                    </div>
                  </div>
                )}
              {ach.status === "unlocked" && ach.unlocked_at && (
                <p className="text-[10px] text-emerald-400 mt-1">
                  Unlocked {new Date(ach.unlocked_at).toLocaleDateString()}
                </p>
              )}
              {ach.status === "locked" && (
                <p className="text-[10px] text-[var(--muted-foreground)] mt-1">
                  {ach.condition}
                </p>
              )}
            </div>
          ))}
        </div>

        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
            <div className="flex items-center gap-2 mb-4">
              <Zap size={15} className="text-[#D4734B]" />
              <h3 className="text-sm font-medium text-[var(--foreground)]">Recent XP</h3>
            </div>
            {xpHistory.length === 0 ? (
              <p className="text-xs text-[var(--muted-foreground)]">
                No XP awarded yet — start a practice quiz to earn XP.
              </p>
            ) : (
              <div className="space-y-3">
                {xpHistory.map((h) => (
                  <div key={h.event_id} className="flex items-center justify-between">
                    <div>
                      <p className="text-xs text-[var(--foreground)] capitalize">
                        {h.action.replace(/[._]/g, " ")}
                      </p>
                      <p className="text-[10px] text-[var(--muted-foreground)]">
                        {new Date(h.timestamp).toLocaleString()}
                      </p>
                    </div>
                    <span className="text-sm font-bold text-[#D4734B]">+{h.xp}</span>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
            <div className="flex items-center gap-2 mb-4">
              <Users size={15} className="text-[var(--muted-foreground)]" />
              <h3 className="text-sm font-medium text-[var(--foreground)]">
                Cohort Leaderboard
              </h3>
              {isPreview && (
                <span className="rounded-full border border-[#D4734B]/30 bg-[#D4734B]/10 px-2 py-0.5 text-[10px] font-semibold text-[#f0b8a6]">
                  Preview
                </span>
              )}
            </div>
            <div className="space-y-2">
              {leaderboard.map((u) => (
                <div
                  key={u.rank}
                  className={`flex items-center gap-3 rounded-xl px-3 py-2.5 ${
                    u.you ? "border border-[#D4734B]/25 bg-[#D4734B]/10" : ""
                  }`}
                >
                  <span
                    className={`text-sm font-bold w-5 ${
                      u.rank === 1
                        ? "text-[#D4734B]"
                        : u.rank === 2
                          ? "text-slate-300"
                          : u.rank === 3
                            ? "text-[#b85a3a]"
                            : "text-[var(--muted-foreground)]"
                    }`}
                  >
                    #{u.rank}
                  </span>
                  <div className="flex-1">
                    <p
                      className={`text-sm font-medium ${
                        u.you ? "text-[#D4734B]" : "text-[var(--foreground)]"
                      }`}
                    >
                      {u.name}
                    </p>
                    <p className="text-[10px] text-[var(--muted-foreground)]">
                      Level {u.level}
                    </p>
                  </div>
                  <div className="flex items-center gap-1 text-xs">
                    <Zap size={10} className="text-[#D4734B]" />
                    <span className="font-mono text-[var(--muted-foreground)]">
                      {u.xp.toLocaleString()}
                    </span>
                  </div>
                  {u.rank === 1 && <Award size={14} className="text-[#D4734B]" />}
                </div>
              ))}
            </div>
            {isPreview && (
              <p className="mt-3 text-[10px] text-[var(--muted-foreground)]">
                Cohort comparison becomes live once multi-user is configured.
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
