/* eslint-disable i18n/no-literal-ui-text */
"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import {
  BookOpen,
  Brain,
  CheckCircle2,
  Clock,
  Code2,
  Flame,
  Loader2,
  Lock,
  Mic,
  Pen,
  PlayCircle,
  Star,
  Target,
  Trophy,
  Zap,
} from "lucide-react";

import {
  completeMission,
  fetchGamificationState,
  fetchMissionsToday,
  type GamificationState,
  type MissionItem,
  type MissionsToday,
} from "@/lib/workspace-api";
import { OfflineQueuedError } from "@/lib/offline-queue";

const ICON_BY_NAME: Record<string, React.ReactNode> = {
  play: <PlayCircle className="h-5 w-5" />,
  target: <Target className="h-5 w-5" />,
  brain: <Brain className="h-5 w-5" />,
  mic: <Mic className="h-5 w-5" />,
  pen: <Pen className="h-5 w-5" />,
  code: <Code2 className="h-5 w-5" />,
  book: <BookOpen className="h-5 w-5" />,
};

/** Mission card tint for violet/amber API keys → unified terracotta. */
const MISSION_CARD_ACCENT = "border-[#D4734B]/20 bg-[#D4734B]/5";

const COLOR_BY_NAME: Record<string, string> = {
  violet: MISSION_CARD_ACCENT,
  amber: MISSION_CARD_ACCENT,
  blue: "border-blue-500/20 bg-blue-500/5",
  teal: "border-teal-500/20 bg-teal-500/5",
  emerald: "border-emerald-500/20 bg-emerald-500/5",
};

function dateLabel(): string {
  return new Date().toLocaleDateString(undefined, {
    weekday: "long",
    month: "long",
    day: "numeric",
  });
}

export default function MissionsPage() {
  const [data, setData] = useState<MissionsToday | null>(null);
  const [state, setState] = useState<GamificationState | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [bonusStarted, setBonusStarted] = useState(false);
  const [busyId, setBusyId] = useState<string | null>(null);

  const reload = async () => {
    const [today, st] = await Promise.all([
      fetchMissionsToday(),
      fetchGamificationState(),
    ]);
    setData(today);
    setState(st);
  };

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        await reload();
      } catch (e) {
        if (!cancelled) {
          setError(
            e instanceof Error ? e.message : "Failed to load missions",
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
        <span>Loading missions…</span>
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

  if (!data || !state) return null;

  const completedCount = data.totals.completed;
  const totalMissions = data.totals.total;
  const allDone = completedCount >= totalMissions;
  const xpPct = data.totals.xp_target
    ? Math.min(100, Math.round((data.totals.xp_earned / data.totals.xp_target) * 100))
    : 0;

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-3xl flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-[#D4734B] to-[#b85a3a] shadow-lg shadow-[#D4734B]/30">
              <Flame className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">Daily Missions</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">{dateLabel()}</p>
            </div>
          </div>
          <div className="flex items-center gap-2 rounded-lg border border-[#D4734B]/25 bg-[#D4734B]/10 px-3 py-1.5">
            <Flame className="h-3.5 w-3.5 text-[#D4734B]" />
            <span className="text-xs font-bold text-[#D4734B]">
              {state.streak_current} day streak
            </span>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-3xl space-y-6 px-4 py-6 sm:px-6">
          <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
            <div className="mb-3 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Star className="h-4 w-4 text-[#D4734B]" />
                <span className="text-sm font-semibold text-[var(--foreground)]">
                  Today&apos;s XP Progress
                </span>
              </div>
              <span className="text-sm font-bold text-[#D4734B]">
                {data.totals.xp_earned} / {data.totals.xp_target} XP
              </span>
            </div>
            <div className="mb-2 h-3 overflow-hidden rounded-full bg-white/10">
              <div
                className="h-full rounded-full bg-gradient-to-r from-[#D4734B] to-[#b85a3a] transition-all duration-700"
                style={{ width: `${xpPct}%` }}
              />
            </div>
            <div className="flex items-center justify-between text-xs text-[var(--muted-foreground)]">
              <span>{xpPct}% complete</span>
              <span>
                {Math.max(0, data.totals.xp_target - data.totals.xp_earned)} XP remaining
              </span>
            </div>
          </div>

          {allDone && (
            <div className="rounded-2xl border border-emerald-500/30 bg-gradient-to-br from-emerald-500/10 to-teal-500/10 p-6 text-center">
              <Trophy className="mx-auto mb-3 h-10 w-10 text-[#D4734B]" />
              <h3 className="mb-1 text-lg font-bold text-[var(--foreground)]">
                All missions complete!
              </h3>
              <p className="text-sm text-[var(--muted-foreground)]">
                Amazing! You&apos;ve finished today&apos;s missions. Try the bonus challenge to earn extra XP.
              </p>
            </div>
          )}

          <div className="space-y-3">
            {data.missions.map((m: MissionItem) => {
              const isCompleted = m.status === "completed";
              const isLocked = Boolean(m.requires_feature);
              const colorCls = COLOR_BY_NAME[m.color] ?? MISSION_CARD_ACCENT;
              const busy = busyId === m.id;
              return (
                <div
                  key={m.id}
                  className={`overflow-hidden rounded-2xl border transition-all ${colorCls} ${
                    isLocked ? "opacity-60" : ""
                  }`}
                >
                  <div className="flex items-center gap-4 p-5">
                    <div
                      className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border ${
                        isCompleted
                          ? "bg-emerald-500/20 text-emerald-400 border-emerald-500/30"
                          : isLocked
                            ? "bg-white/5 text-white/30 border-white/10"
                            : "border-[#D4734B]/30 bg-[#D4734B]/20 text-[#D4734B]"
                      }`}
                    >
                      {isCompleted ? (
                        <CheckCircle2 className="h-5 w-5" />
                      ) : isLocked ? (
                        <Lock className="h-5 w-5" />
                      ) : (
                        (ICON_BY_NAME[m.icon] ?? <Target className="h-5 w-5" />)
                      )}
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="mb-1 flex flex-wrap items-center gap-2">
                        <h3 className="text-sm font-semibold text-[var(--foreground)]">
                          {m.title}
                        </h3>
                        <span
                          className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${
                            isCompleted
                              ? "text-emerald-400 bg-emerald-500/10 border-emerald-500/30"
                              : isLocked
                                ? "text-white/40 bg-white/5 border-white/10"
                                : "border-[#D4734B]/30 bg-[#D4734B]/10 text-[#D4734B]"
                          }`}
                        >
                          {isCompleted
                            ? "Completed"
                            : isLocked
                              ? `Requires ${m.requires_feature}`
                              : "Available"}
                        </span>
                        <span className="text-[10px] font-medium text-[#D4734B]">
                          {m.category}
                        </span>
                      </div>
                      <p className="text-xs text-[var(--muted-foreground)] line-clamp-1">
                        {m.description}
                      </p>
                      <div className="mt-2 flex flex-wrap items-center gap-3 text-xs">
                        <span className="flex items-center gap-1 text-[#D4734B]">
                          <Star className="h-3 w-3" />+{m.xp} XP
                        </span>
                        <span className="flex items-center gap-1 text-[var(--muted-foreground)]">
                          <Clock className="h-3 w-3" />
                          {m.duration}
                        </span>
                        {m.model_roles.map((role) => (
                          <span
                            key={role}
                            className="rounded-full border border-[#D4734B]/25 bg-[#D4734B]/10 px-2 py-0.5 text-[10px] text-[#f0b8a6]"
                          >
                            {role}
                          </span>
                        ))}
                      </div>
                    </div>

                    {!isLocked && !isCompleted && (
                      <div className="flex shrink-0 items-center gap-2">
                        <Link
                          href={m.cta_href}
                          className="rounded-xl bg-white/5 px-3 py-2 text-xs font-medium text-[var(--muted-foreground)] hover:bg-white/10"
                        >
                          Open
                        </Link>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={async () => {
                            try {
                              setBusyId(m.id);
                              await completeMission(m.id, m.xp);
                              await reload();
                            } catch (e) {
                              setError(
                                e instanceof OfflineQueuedError
                                  ? "Offline — mission marked locally; will sync when online."
                                  : e instanceof Error
                                    ? e.message
                                    : "Failed to complete mission",
                              );
                            } finally {
                              setBusyId(null);
                            }
                          }}
                          className="flex items-center gap-1.5 rounded-xl bg-[#D4734B] px-3 py-2 text-xs font-semibold text-white transition-colors hover:bg-[#c26244] disabled:opacity-50"
                        >
                          {busy ? (
                            <Loader2 className="h-3.5 w-3.5 animate-spin" />
                          ) : (
                            <CheckCircle2 className="h-3.5 w-3.5" />
                          )}
                          Mark done
                        </button>
                      </div>
                    )}
                    {isCompleted && (
                      <div className="shrink-0 flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-500/20">
                        <CheckCircle2 className="h-5 w-5 text-emerald-400" />
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>

          <div className="overflow-hidden rounded-2xl border border-[#D4734B]/30 bg-gradient-to-br from-[#D4734B]/12 to-[#5c3018]/8 p-6">
            <div className="mb-3 flex items-center gap-2">
              <Zap className="h-5 w-5 text-[#D4734B]" />
              <span className="text-xs font-bold uppercase tracking-widest text-[#D4734B]">
                Bonus Challenge
              </span>
            </div>
            <h3 className="mb-2 text-base font-bold text-[var(--foreground)]">
              {data.bonus.title}
            </h3>
            <p className="mb-4 text-sm text-[var(--muted-foreground)]">
              {data.bonus.description}
            </p>
            <div className="mb-4 flex items-center gap-4 text-sm">
              <span className="flex items-center gap-1.5 font-bold text-[#D4734B]">
                <Star className="h-4 w-4" />+{data.bonus.xp} XP
              </span>
              <span className="flex items-center gap-1.5 text-[var(--muted-foreground)]">
                <Clock className="h-4 w-4" />
                {data.bonus.duration}
              </span>
              {data.bonus.model_roles.map((r) => (
                <span
                  key={r}
                  className="rounded-full border border-[#D4734B]/30 bg-[#D4734B]/10 px-2 py-0.5 text-[10px] text-[#f0b8a6]"
                >
                  {r}
                </span>
              ))}
            </div>
            <Link
              href={data.bonus.cta_href}
              onClick={() => setBonusStarted(true)}
              className={`block w-full rounded-xl py-2.5 text-center text-sm font-semibold transition-colors ${
                bonusStarted
                  ? "bg-emerald-600 text-white"
                  : "bg-[#D4734B] text-white hover:bg-[#c26244]"
              }`}
            >
              {bonusStarted ? "✓ Challenge Started" : "Start Bonus Challenge"}
            </Link>
          </div>

          <div className="grid grid-cols-3 gap-3">
            {[
              {
                label: "Missions Done",
                value: `${completedCount}/${totalMissions}`,
                color: "text-emerald-400",
                icon: <CheckCircle2 className="h-5 w-5" />,
              },
              {
                label: "XP Today",
                value: String(data.totals.xp_earned),
                color: "text-[#D4734B]",
                icon: <Star className="h-5 w-5" />,
              },
              {
                label: "Streak",
                value: `${state.streak_current}d`,
                color: "text-[#D4734B]",
                icon: <Flame className="h-5 w-5" />,
              },
            ].map((s) => (
              <div
                key={s.label}
                className="rounded-xl border border-white/5 bg-[var(--secondary)] p-3 text-center"
              >
                <div className={`mb-1 flex justify-center ${s.color}`}>{s.icon}</div>
                <p className={`text-lg font-black ${s.color}`}>{s.value}</p>
                <p className="text-[10px] text-[var(--muted-foreground)]">{s.label}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
