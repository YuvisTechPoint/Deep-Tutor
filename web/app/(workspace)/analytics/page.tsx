/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Brain,
  Clock,
  Code2,
  Flame,
  Loader2,
  Target,
  TrendingUp,
  Zap,
} from "lucide-react";

import {
  fetchAnalyticsSummary,
  fetchTimeDistribution,
  fetchTopicMastery,
  fetchWeakAreas,
  fetchXPTrend,
  type AnalyticsSummary,
  type TopicMastery,
  type WeakArea,
  type XPTrendPoint,
} from "@/lib/workspace-api";

type DateRange = "7d" | "30d" | "90d";

function XPLineChart({ series }: { series: XPTrendPoint[] }) {
  if (series.length === 0) {
    return (
      <p className="py-12 text-center text-xs text-[var(--muted-foreground)]">
        No XP recorded yet. Complete a practice quiz or mission to populate the chart.
      </p>
    );
  }
  const max = Math.max(...series.map((p) => p.xp));
  const min = Math.min(...series.map((p) => p.xp));
  const range = Math.max(max - min, 1);
  const w = 600;
  const h = 120;
  const pad = 8;
  const xs = series.map((_, i) => pad + (i / Math.max(series.length - 1, 1)) * (w - pad * 2));
  const ys = series.map((p) => pad + ((max - p.xp) / range) * (h - pad * 2));
  const points = xs.map((x, i) => `${x},${ys[i]}`).join(" ");
  const area = `${pad},${h - pad} ${points} ${w - pad},${h - pad}`;
  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="w-full" preserveAspectRatio="none">
      <defs>
        <linearGradient id="xp-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="rgb(212,115,75)" stopOpacity="0.35" />
          <stop offset="100%" stopColor="rgb(212,115,75)" stopOpacity="0" />
        </linearGradient>
      </defs>
      <polygon points={area} fill="url(#xp-grad)" />
      <polyline
        points={points}
        fill="none"
        stroke="rgb(212,115,75)"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function HBarChart({ data }: { data: TopicMastery[] }) {
  if (data.length === 0) {
    return (
      <p className="py-6 text-center text-xs text-[var(--muted-foreground)]">
        Mastery shows up once you answer practice questions tagged by topic.
      </p>
    );
  }
  const max = Math.max(...data.map((d) => d.mastery), 1);
  const color = (v: number) => {
    if (v >= 80) return "bg-[#D4734B]";
    if (v >= 60) return "bg-[#D4734B]/90";
    if (v >= 40) return "bg-[#D4734B]/75";
    return "bg-[#D4734B]/55";
  };
  return (
    <div className="space-y-3">
      {data.map((d) => (
        <div key={d.topic} className="flex items-center gap-3">
          <span className="w-32 shrink-0 text-xs text-[var(--muted-foreground)] capitalize">
            {d.topic}
          </span>
          <div className="flex-1 overflow-hidden rounded-full bg-white/10 h-2">
            <div
              className={`h-full rounded-full ${color(d.mastery)} transition-all`}
              style={{ width: `${(d.mastery / max) * 100}%` }}
            />
          </div>
          <span className="w-12 text-right text-xs font-semibold text-[var(--foreground)]">
            {d.mastery}%
          </span>
          <span className="w-10 text-right text-[10px] text-[var(--muted-foreground)]">
            {d.answers}q
          </span>
        </div>
      ))}
    </div>
  );
}

export default function AnalyticsPage() {
  const [range, setRange] = useState<DateRange>("30d");
  const [summary, setSummary] = useState<AnalyticsSummary | null>(null);
  const [topics, setTopics] = useState<TopicMastery[]>([]);
  const [trend, setTrend] = useState<XPTrendPoint[]>([]);
  const [distribution, setDistribution] = useState<
    { label: string; pct: number; xp: number }[]
  >([]);
  const [weak, setWeak] = useState<WeakArea[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const [s, t, tr, td, w] = await Promise.all([
          fetchAnalyticsSummary(range),
          fetchTopicMastery(),
          fetchXPTrend(range),
          fetchTimeDistribution(),
          fetchWeakAreas(),
        ]);
        if (cancelled) return;
        setSummary(s);
        setTopics(t.items);
        setTrend(tr.series);
        setDistribution(td.items);
        setWeak(w.items);
      } catch (e) {
        if (!cancelled) {
          setError(
            e instanceof Error ? e.message : "Failed to load analytics",
          );
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [range]);

  const distributionColors = useMemo(
    () => [
      "bg-[#D4734B]",
      "bg-[#c26244]",
      "bg-[#b85a3a]",
      "bg-[#e88a68]",
      "bg-[#9a4d32]",
      "bg-[#7a3d26]",
    ],
    [],
  );

  if (loading || !summary) {
    return (
      <div className="flex h-screen items-center justify-center gap-2 text-[var(--muted-foreground)]">
        <Loader2 className="h-5 w-5 animate-spin" />
        <span>Loading analytics…</span>
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

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-5xl flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-[#D4734B] to-[#b85a3a] shadow-lg shadow-[#D4734B]/30">
              <TrendingUp className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">
                Personal Analytics
              </h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">
                Real signals from your sessions and practice ledger
              </p>
            </div>
          </div>
          <div className="flex gap-2">
            {(["7d", "30d", "90d"] as DateRange[]).map((r) => (
              <button
                key={r}
                type="button"
                onClick={() => setRange(r)}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                  range === r
                    ? "bg-[#D4734B] text-white"
                    : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
                }`}
              >
                Last {r}
              </button>
            ))}
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-5xl space-y-6 px-4 py-6 sm:px-6">
          {summary.preview && (
            <div className="rounded-2xl border border-[#D4734B]/30 bg-[#D4734B]/10 px-5 py-3 text-xs text-[#f0c4b8]">
              No practice data yet — answer a few questions in /practice to populate accuracy &
              topic-mastery signals.
            </div>
          )}

          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              {
                label: "Study Sessions",
                value: summary.sessions,
                icon: <Brain className="h-5 w-5" />,
                color: "text-[#D4734B]",
              },
              {
                label: "Avg Accuracy",
                value: `${summary.accuracy}%`,
                icon: <Target className="h-5 w-5" />,
                color: "text-[#D4734B]",
              },
              {
                label: "Problems Solved",
                value: summary.problems,
                icon: <Code2 className="h-5 w-5" />,
                color: "text-[#D4734B]",
              },
              {
                label: "Hours Studied",
                value: `${summary.hours}h`,
                icon: <Clock className="h-5 w-5" />,
                color: "text-[#D4734B]",
              },
            ].map((s) => (
              <div
                key={s.label}
                className="rounded-xl border border-white/5 bg-[var(--secondary)] p-4"
              >
                <div className={`mb-1 ${s.color}`}>{s.icon}</div>
                <p className={`text-2xl font-black ${s.color}`}>{s.value}</p>
                <p className="text-[10px] text-[var(--muted-foreground)]">{s.label}</p>
              </div>
            ))}
          </div>

          <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
            <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6 lg:col-span-2">
              <div className="mb-4 flex items-center justify-between">
                <h3 className="text-sm font-semibold text-[var(--foreground)]">XP Trend</h3>
                <span className="text-xs text-[#D4734B]">
                  {trend.reduce((s, p) => s + p.xp, 0)} XP total
                </span>
              </div>
              <XPLineChart series={trend} />
              <div className="mt-2 flex items-center justify-between text-xs text-[var(--muted-foreground)]">
                <span>{trend[0]?.date}</span>
                <span>{trend[trend.length - 1]?.date}</span>
              </div>
            </div>

            <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
              <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">
                Level Snapshot
              </h3>
              <div className="mb-4 flex h-32 w-32 mx-auto flex-col items-center justify-center rounded-full border-4 border-[#D4734B]">
                <p className="text-3xl font-black text-[#D4734B]">Lv.</p>
                <p className="text-4xl font-black text-white">{summary.level.level}</p>
              </div>
              <p className="text-center text-xs text-[var(--muted-foreground)]">
                {summary.level.total_xp.toLocaleString()} XP lifetime
              </p>
              <div className="mt-4 space-y-2">
                {[
                  {
                    label: "Streak",
                    value: `${summary.streak_current}d`,
                    icon: <Flame className="h-3.5 w-3.5 text-[#D4734B]" />,
                  },
                  {
                    label: "Max streak",
                    value: `${summary.streak_max}d`,
                    icon: <Flame className="h-3.5 w-3.5 text-[#D4734B]" />,
                  },
                  {
                    label: "Level progress",
                    value: `${summary.level.progress_pct}%`,
                    icon: <Zap className="h-3.5 w-3.5 text-[#D4734B]" />,
                  },
                ].map((s) => (
                  <div
                    key={s.label}
                    className="flex items-center justify-between rounded-lg bg-white/5 px-3 py-2 text-xs"
                  >
                    <span className="text-[var(--muted-foreground)]">{s.label}</span>
                    <span className="flex items-center gap-1 font-bold">
                      {s.icon}
                      {s.value}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
            <h3 className="mb-5 text-sm font-semibold text-[var(--foreground)]">
              Topic Mastery
            </h3>
            <HBarChart data={topics} />
          </div>

          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
              <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">
                Study Time Distribution
              </h3>
              {distribution.length === 0 ? (
                <p className="text-xs text-[var(--muted-foreground)]">
                  No activity yet. Distribution refreshes as XP is earned across surfaces.
                </p>
              ) : (
                <>
                  <div className="mb-4 flex h-4 overflow-hidden rounded-full">
                    {distribution.map((t, i) => (
                      <div
                        key={t.label}
                        className={`${distributionColors[i % distributionColors.length]} transition-all`}
                        style={{ width: `${t.pct}%` }}
                      />
                    ))}
                  </div>
                  <div className="flex flex-wrap gap-3">
                    {distribution.map((t, i) => (
                      <div key={t.label} className="flex items-center gap-1.5 text-xs">
                        <div
                          className={`h-2.5 w-2.5 rounded-full ${distributionColors[i % distributionColors.length]}`}
                        />
                        <span className="text-[var(--foreground)]">{t.label}</span>
                        <span className="text-[var(--muted-foreground)]">{t.pct}%</span>
                      </div>
                    ))}
                  </div>
                </>
              )}
            </div>

            <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
              <div className="mb-4 flex items-center gap-2">
                <Zap className="h-4 w-4 text-[#D4734B]" />
                <h3 className="text-sm font-semibold text-[var(--foreground)]">
                  AI-Identified Weak Areas
                </h3>
              </div>
              {weak.length === 0 ? (
                <p className="text-xs text-[var(--muted-foreground)]">
                  No weak areas detected yet. Answer 5+ questions per topic and they show
                  up here.
                </p>
              ) : (
                <div className="space-y-3">
                  {weak.map((w) => (
                    <div
                      key={w.topic}
                      className="rounded-xl border border-[#D4734B]/20 bg-[#D4734B]/8 px-4 py-3"
                    >
                      <div className="mb-1 flex items-center justify-between">
                        <span className="text-sm font-medium text-[var(--foreground)] capitalize">
                          {w.topic}
                        </span>
                        <span
                          className={`text-xs font-bold ${
                            w.mastery < 40
                              ? "text-[#D4734B]"
                              : w.mastery < 60
                                ? "text-[#D4734B]/90"
                                : "text-[#D4734B]/75"
                          }`}
                        >
                          {w.mastery}%
                        </span>
                      </div>
                      <p className="text-xs text-[var(--muted-foreground)]">
                        → {w.action}
                      </p>
                      <p className="mt-1 text-[10px] text-[#D4734B]">
                        Routes to {w.recommended_model_role} role
                      </p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
