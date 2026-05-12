"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  ArrowRight,
  Brain,
  CheckCircle2,
  Clock,
  Code2,
  Flame,
  Loader2,
  RotateCcw,
  Sparkles,
  Star,
  Target,
  TrendingUp,
  Trophy,
  Zap,
} from "lucide-react";

import {
  type AnalyticsSummary,
  type GamificationState,
  type LearningPlan,
  type NextAction,
  type TopicMastery,
  type XPHistoryItem,
  type XPTrendPoint,
  fetchAnalyticsSummary,
  fetchGamificationState,
  fetchLearningPlan,
  fetchNextAction,
  fetchRevisionQueue,
  fetchTopicMastery,
  fetchXPHistory,
  fetchXPTrend,
} from "@/lib/workspace-api";

interface RadarData {
  axis: string;
  value: number;
}

function RadarChart({ data, size = 200 }: { data: RadarData[]; size?: number }) {
  if (!data.length) {
    return (
      <p className="py-12 text-center text-xs text-[var(--muted-foreground)]">
        No topic mastery yet — answer practice questions to start tracking skills.
      </p>
    );
  }
  const cx = size / 2;
  const cy = size / 2;
  const r = (size / 2) * 0.75;
  const n = data.length;
  const levels = 5;
  const angleFor = (i: number) => (Math.PI * 2 * i) / n - Math.PI / 2;
  const pointOnLevel = (level: number, i: number) => {
    const radius = (r * level) / levels;
    const a = angleFor(i);
    return { x: cx + radius * Math.cos(a), y: cy + radius * Math.sin(a) };
  };
  const polygonForLevel = (level: number) =>
    Array.from({ length: n }, (_, i) => {
      const { x, y } = pointOnLevel(level, i);
      return `${x},${y}`;
    }).join(" ");
  const dataPolygon = data
    .map((d, i) => {
      const radius = (r * d.value) / 100;
      const a = angleFor(i);
      return `${cx + radius * Math.cos(a)},${cy + radius * Math.sin(a)}`;
    })
    .join(" ");
  return (
    <svg width={size} height={size} className="overflow-visible">
      {Array.from({ length: levels }, (_, lvl) => (
        <polygon
          key={lvl}
          points={polygonForLevel(lvl + 1)}
          fill="none"
          stroke="rgba(255,255,255,0.06)"
          strokeWidth={1}
        />
      ))}
      {data.map((_, i) => {
        const { x, y } = pointOnLevel(levels, i);
        return (
          <line
            key={i}
            x1={cx}
            y1={cy}
            x2={x}
            y2={y}
            stroke="rgba(255,255,255,0.06)"
            strokeWidth={1}
          />
        );
      })}
      <polygon
        points={dataPolygon}
        fill="rgba(212,115,75,0.25)"
        stroke="rgba(212,115,75,0.85)"
        strokeWidth={2}
      />
      {data.map((d, i) => {
        const radius = (r * d.value) / 100;
        const a = angleFor(i);
        return (
          <circle
            key={i}
            cx={cx + radius * Math.cos(a)}
            cy={cy + radius * Math.sin(a)}
            r={4}
            fill="rgb(212,115,75)"
          />
        );
      })}
      {data.map((d, i) => {
        const { x, y } = pointOnLevel(levels + 0.6, i);
        return (
          <text
            key={i}
            x={x}
            y={y}
            textAnchor="middle"
            dominantBaseline="middle"
            fontSize={10}
            fill="rgba(255,255,255,0.5)"
          >
            {d.axis}
          </text>
        );
      })}
    </svg>
  );
}

function ActivityHeatmap({ data }: { data: number[][] }) {
  const weekLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const maxVal = Math.max(...data.flat(), 1);
  const cellColor = (v: number) => {
    if (v === 0) return "bg-white/5";
    const intensity = v / maxVal;
    if (intensity < 0.25) return "bg-[#D4734B]/25";
    if (intensity < 0.5) return "bg-[#D4734B]/45";
    if (intensity < 0.75) return "bg-[#D4734B]/70";
    return "bg-[#D4734B]";
  };
  return (
    <div className="overflow-x-auto">
      <div className="flex gap-1 min-w-max">
        <div className="flex flex-col gap-1 pr-2">
          {weekLabels.map((d) => (
            <span
              key={d}
              className="flex h-3 w-7 items-center text-[9px] text-[var(--muted-foreground)]"
            >
              {d}
            </span>
          ))}
        </div>
        {data.map((week, wi) => (
          <div key={wi} className="flex flex-col gap-1">
            {week.map((val, di) => (
              <div
                key={di}
                className={`h-3 w-3 rounded-sm transition-colors hover:ring-1 hover:ring-[#D4734B] ${cellColor(
                  val,
                )}`}
                title={`${val} XP`}
              />
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}

function MiniBarChart({
  values,
  labels,
  color = "bg-[#D4734B]",
}: {
  values: number[];
  labels: string[];
  color?: string;
}) {
  const max = Math.max(...values, 1);
  return (
    <div className="flex items-end gap-1.5 h-16">
      {values.map((v, i) => (
        <div key={i} className="flex flex-1 flex-col items-center gap-1">
          <div
            className={`w-full rounded-t-sm ${color} opacity-80 transition-all`}
            style={{ height: `${(v / max) * 52}px` }}
          />
          <span className="text-[9px] text-[var(--muted-foreground)]">{labels[i]}</span>
        </div>
      ))}
    </div>
  );
}

function buildHeatmap(xpPerDay: Record<string, number>): number[][] {
  const weeks = 26;
  const days = weeks * 7;
  const grid: number[][] = Array.from({ length: weeks }, () =>
    Array.from({ length: 7 }, () => 0),
  );
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  for (let offset = 0; offset < days; offset++) {
    const d = new Date(today.getTime() - offset * 24 * 60 * 60 * 1000);
    const iso = d.toISOString().slice(0, 10);
    const weekIdx = weeks - 1 - Math.floor(offset / 7);
    const dayIdx = d.getUTCDay();
    grid[weekIdx][dayIdx] = xpPerDay[iso] ?? 0;
  }
  return grid;
}

function buildWeeklyBars(xpPerDay: Record<string, number>): {
  values: number[];
  labels: string[];
} {
  const labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  const values: number[] = [];
  const today = new Date();
  const day = today.getUTCDay() || 7;
  for (let i = 0; i < 7; i++) {
    const d = new Date(today.getTime() - (day - 1 - i) * 24 * 60 * 60 * 1000);
    const iso = d.toISOString().slice(0, 10);
    values.push(xpPerDay[iso] ?? 0);
  }
  return { values, labels };
}

export default function DashboardPage() {
  const [state, setState] = useState<GamificationState | null>(null);
  const [summary, setSummary] = useState<AnalyticsSummary | null>(null);
  const [topics, setTopics] = useState<TopicMastery[]>([]);
  const [trend, setTrend] = useState<XPTrendPoint[]>([]);
  const [recent, setRecent] = useState<XPHistoryItem[]>([]);
  const [plan, setPlan] = useState<LearningPlan | null>(null);
  const [nextAction, setNextAction] = useState<NextAction | null>(null);
  const [revisionDueCount, setRevisionDueCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const [s, sum, t, tr, hist, p, na, rev] = await Promise.all([
          fetchGamificationState(),
          fetchAnalyticsSummary("30d"),
          fetchTopicMastery(),
          fetchXPTrend("30d"),
          fetchXPHistory(8),
          fetchLearningPlan(),
          fetchNextAction(),
          fetchRevisionQueue(20),
        ]);
        if (cancelled) return;
        setState(s);
        setSummary(sum);
        setTopics(t.items);
        setTrend(tr.series);
        setRecent(hist.items);
        setPlan(p);
        setNextAction(na.action);
        setRevisionDueCount(rev.count);
      } catch (e) {
        if (!cancelled) {
          setError(
            e instanceof Error ? e.message : "Failed to load dashboard",
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

  const heatmap = useMemo(() => buildHeatmap(state?.xp_per_day ?? {}), [state]);
  const weekly = useMemo(() => buildWeeklyBars(state?.xp_per_day ?? {}), [state]);
  const radar = useMemo<RadarData[]>(
    () => topics.slice(0, 6).map((t) => ({ axis: t.topic, value: t.mastery })),
    [topics],
  );

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center gap-2 text-[var(--muted-foreground)]">
        <Loader2 className="h-5 w-5 animate-spin" />
        <span>Loading dashboard…</span>
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

  if (!state || !summary || !plan) return null;

  const minutesTotal = recent.reduce((s, e) => s + e.xp / 12, 0);
  const statsCards = [
    {
      label: "Total XP",
      value: state.total_xp.toLocaleString(),
      icon: <Star className="h-4 w-4" />,
      color: "text-[#D4734B]",
      bg: "bg-[#D4734B]/10",
    },
    {
      label: "Day Streak",
      value: String(state.streak_current),
      icon: <Flame className="h-4 w-4" />,
      color: "text-[#D4734B]",
      bg: "bg-[#D4734B]/10",
    },
    {
      label: "Hours Studied",
      value: `${summary.hours}h`,
      icon: <Clock className="h-4 w-4" />,
      color: "text-blue-400",
      bg: "bg-blue-500/10",
    },
    {
      label: "Milestones",
      value: `${plan.totals.milestones_completed}/${plan.totals.milestones_total}`,
      icon: <CheckCircle2 className="h-4 w-4" />,
      color: "text-emerald-400",
      bg: "bg-emerald-500/10",
    },
    {
      label: "Problems",
      value: String(summary.problems),
      icon: <Code2 className="h-4 w-4" />,
      color: "text-[#D4734B]",
      bg: "bg-[#D4734B]/10",
    },
    {
      label: "Accuracy",
      value: `${summary.accuracy}%`,
      icon: <Target className="h-4 w-4" />,
      color: "text-[#D4734B]",
      bg: "bg-[#D4734B]/10",
    },
  ];

  const totalDays = trend.length;
  const totalMinutes = trend.reduce((s, p) => s + p.xp / 12, 0);

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-6xl flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-[#D4734B] to-[#b85a3a] shadow-lg shadow-[#D4734B]/30">
              <TrendingUp className="h-4 w-4 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">
                Learning Dashboard
              </h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">
                Progress · Analytics · Insights
              </p>
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
        <div className="mx-auto max-w-6xl space-y-6 px-4 py-6 sm:px-6">
          {revisionDueCount > 0 ? (
            <Link
              href="/revision"
              className="group flex flex-col gap-2 rounded-2xl border border-emerald-500/30 bg-emerald-500/10 p-4 transition-colors hover:border-emerald-400/50 sm:flex-row sm:items-center"
            >
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-emerald-500/20 text-emerald-300">
                <RotateCcw className="h-4 w-4" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-[10px] font-semibold uppercase tracking-widest text-emerald-400/90">
                  Spaced revision
                </p>
                <h3 className="text-sm font-bold text-[var(--foreground)]">
                  {revisionDueCount} card{revisionDueCount === 1 ? "" : "s"} due now
                </h3>
                <p className="text-xs text-[var(--muted-foreground)]">
                  Short reviews from practice — keep recall strong.
                </p>
              </div>
              <div className="inline-flex items-center gap-1 self-end rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white transition-transform group-hover:translate-x-0.5 sm:self-center">
                Review
                <ArrowRight className="h-3.5 w-3.5" />
              </div>
            </Link>
          ) : null}
          {nextAction && (
            <Link
              href={nextAction.href}
              className="group flex flex-col gap-3 rounded-2xl border border-[#D4734B]/40 bg-gradient-to-br from-[#D4734B]/20 via-[#5c3018]/15 to-transparent p-5 transition-colors hover:border-[#D4734B] sm:flex-row sm:items-center"
              title={nextAction.rationale}
            >
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#D4734B]/30 text-[#f3b8a0]">
                <Sparkles className="h-5 w-5" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-[10px] font-semibold uppercase tracking-widest text-[#D4734B]">
                  Your next step ·{" "}
                  {nextAction.kind === "tutor"
                    ? "AI Tutor"
                    : nextAction.kind.charAt(0).toUpperCase() +
                      nextAction.kind.slice(1)}
                </p>
                <h3 className="truncate text-base font-bold text-[var(--foreground)]">
                  {nextAction.title}
                </h3>
                <p className="line-clamp-2 text-xs text-[var(--muted-foreground)]">
                  {nextAction.description}
                </p>
                <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1 text-[10px] text-[var(--muted-foreground)]">
                  {nextAction.estimated_minutes ? (
                    <span className="inline-flex items-center gap-1">
                      <Clock className="h-3 w-3" />
                      {nextAction.estimated_minutes} min
                    </span>
                  ) : null}
                  {nextAction.milestone_title ? (
                    <span className="inline-flex items-center gap-1">
                      <Target className="h-3 w-3" />
                      {nextAction.milestone_title}
                    </span>
                  ) : null}
                </div>
              </div>
              <div className="inline-flex items-center gap-1 self-end rounded-lg bg-[#D4734B] px-3 py-1.5 text-xs font-semibold text-white transition-transform group-hover:translate-x-0.5 sm:self-center">
                Start
                <ArrowRight className="h-3.5 w-3.5" />
              </div>
            </Link>
          )}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
            {statsCards.map((s) => (
              <div
                key={s.label}
                className={`rounded-xl border border-white/5 ${s.bg} p-4`}
              >
                <div className={`mb-1 ${s.color}`}>{s.icon}</div>
                <p className={`text-xl font-bold ${s.color}`}>{s.value}</p>
                <p className="text-[10px] text-[var(--muted-foreground)]">{s.label}</p>
              </div>
            ))}
          </div>

          <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
            <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
              <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">
                Skill Radar
              </h3>
              <div className="flex justify-center">
                <RadarChart data={radar} size={220} />
              </div>
              <div className="mt-4 space-y-2">
                {radar.map((d) => (
                  <div key={d.axis} className="flex items-center gap-2">
                    <span className="w-20 truncate text-xs text-[var(--muted-foreground)] capitalize">
                      {d.axis}
                    </span>
                    <div className="flex-1 h-1.5 overflow-hidden rounded-full bg-white/5">
                      <div
                        className="h-full rounded-full bg-gradient-to-r from-[#D4734B] to-[#b85a3a]"
                        style={{ width: `${d.value}%` }}
                      />
                    </div>
                    <span className="w-8 text-right text-xs font-semibold text-[#D4734B]">
                      {d.value}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            <div className="space-y-4 lg:col-span-2">
              <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
                <div className="mb-4 flex items-center justify-between">
                  <h3 className="text-sm font-semibold text-[var(--foreground)]">
                    Study XP This Week
                  </h3>
                  <span className="text-xs font-semibold text-[#D4734B]">
                    {weekly.values.reduce((a, b) => a + b, 0)} XP this week
                  </span>
                </div>
                <MiniBarChart
                  values={weekly.values}
                  labels={weekly.labels}
                  color="bg-[#D4734B]"
                />
              </div>
              <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
                <div className="mb-4 flex items-center justify-between">
                  <h3 className="text-sm font-semibold text-[var(--foreground)]">
                    Activity Heatmap (6 months)
                  </h3>
                  <span className="text-[11px] text-[var(--muted-foreground)]">
                    {Math.round(totalMinutes)} mins over {totalDays} days
                  </span>
                </div>
                <ActivityHeatmap data={heatmap} />
                <div className="mt-2 flex items-center gap-1.5 justify-end">
                  <span className="text-[10px] text-[var(--muted-foreground)]">Less</span>
                  {[
                    "bg-white/5",
                    "bg-[#D4734B]/25",
                    "bg-[#D4734B]/45",
                    "bg-[#D4734B]/70",
                    "bg-[#D4734B]",
                  ].map((c) => (
                    <div key={c} className={`h-2.5 w-2.5 rounded-sm ${c}`} />
                  ))}
                  <span className="text-[10px] text-[var(--muted-foreground)]">More</span>
                </div>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
              <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">
                Recent XP Awards
              </h3>
              {recent.length === 0 ? (
                <p className="text-xs text-[var(--muted-foreground)]">
                  No XP yet. Start a practice quiz or complete a mission to earn XP.
                </p>
              ) : (
                <div className="space-y-3">
                  {recent.map((e) => (
                    <div
                      key={e.event_id}
                      className="flex items-center gap-3 rounded-xl bg-white/5 px-4 py-3"
                    >
                      <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-[#D4734B]/20 text-[#D4734B]">
                        <Brain className="h-4 w-4" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="truncate text-sm font-medium text-[var(--foreground)]">
                          {e.action.replace(/[._]/g, " ")}
                        </p>
                        <p className="text-[11px] text-[var(--muted-foreground)]">
                          {new Date(e.timestamp).toLocaleString()}
                          {" · "}
                          {e.source}
                        </p>
                      </div>
                      <div className="text-right shrink-0">
                        <div className="text-sm font-bold text-[#D4734B]">
                          +{e.xp}
                        </div>
                        <p className="text-[10px] text-[var(--muted-foreground)]">XP</p>
                      </div>
                    </div>
                  ))}
                </div>
              )}
              <Link
                href="/achievements"
                className="mt-4 block text-center text-xs text-[#D4734B] hover:text-[#e88a68]"
              >
                View all achievements →
              </Link>
            </div>

            <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
              <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">
                Level Progress
              </h3>
              <div className="mb-4 flex items-center gap-3">
                <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-[#D4734B] to-[#b85a3a] text-lg font-bold text-white shadow-md shadow-[#D4734B]/25">
                  {state.level.level}
                </div>
                <div>
                  <p className="text-sm font-semibold text-[var(--foreground)]">
                    Level {state.level.level} — Scholar
                  </p>
                  <p className="text-xs text-[var(--muted-foreground)]">
                    {state.level.xp_into_level.toLocaleString()} /
                    {" "}
                    {state.level.xp_for_next_level.toLocaleString()} XP into level
                  </p>
                </div>
              </div>
              <div className="rounded-xl bg-white/5 px-4 py-3">
                <div className="mb-2 flex items-center justify-between">
                  <div className="flex items-center gap-1.5">
                    <Trophy className="h-3.5 w-3.5 text-[#D4734B]" />
                    <span className="text-xs font-semibold text-[var(--foreground)]">
                      Level {state.level.level} → {state.level.level + 1}
                    </span>
                  </div>
                  <span className="text-xs font-semibold text-[#D4734B]">
                    {state.level.progress_pct}%
                  </span>
                </div>
                <div className="h-2 overflow-hidden rounded-full bg-white/10">
                  <div
                    className="h-full rounded-full bg-gradient-to-r from-[#D4734B] to-[#b85a3a] transition-all"
                    style={{ width: `${state.level.progress_pct}%` }}
                  />
                </div>
                <p className="mt-1 text-[10px] text-[var(--muted-foreground)]">
                  {(
                    state.level.xp_for_next_level - state.level.xp_into_level
                  ).toLocaleString()}{" "}
                  XP to next level
                </p>
              </div>
              <div className="mt-4 grid grid-cols-2 gap-3">
                <Link
                  href="/missions"
                  className="rounded-xl bg-[#D4734B] px-4 py-2 text-center text-xs font-semibold text-white hover:bg-[#c26244]"
                >
                  Today&apos;s Missions
                  <Zap className="ml-1 inline h-3 w-3" />
                </Link>
                <Link
                  href="/practice"
                  className="rounded-xl border border-white/10 bg-white/5 px-4 py-2 text-center text-xs font-medium text-[var(--foreground)] hover:bg-white/10"
                >
                  Quick Practice
                </Link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
