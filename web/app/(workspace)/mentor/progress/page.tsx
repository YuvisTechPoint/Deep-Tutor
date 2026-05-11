/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  Brain,
  Calendar,
  ChevronDown,
  ChevronUp,
  Flame,
  Star,
  Target,
  TrendingDown,
  TrendingUp,
} from "lucide-react";

interface Learner {
  id: string;
  name: string;
  initials: string;
  overallProgress: number;
  weekChange: number;
  streak: number;
  xp: number;
  missedDays: number;
  topics: { name: string; score: number }[];
  lastActive: string;
  riskFlag?: string;
}

const LEARNERS: Learner[] = [
  { id: "l1", name: "Aisha Raza",   initials: "AR", overallProgress: 91, weekChange: +5,  streak: 24, xp: 14200, missedDays: 0, lastActive: "Today",    topics: [{ name: "Python", score: 92 }, { name: "DSA", score: 88 }, { name: "System Design", score: 85 }] },
  { id: "l2", name: "Marcus Chen",  initials: "MC", overallProgress: 84, weekChange: +3,  streak: 18, xp: 11800, missedDays: 1, lastActive: "Yesterday",  topics: [{ name: "React", score: 82 }, { name: "Node.js", score: 78 }, { name: "SQL", score: 70 }] },
  { id: "l3", name: "Priya Sharma", initials: "PS", overallProgress: 72, weekChange: -2,  streak: 9,  xp: 8400,  missedDays: 2, lastActive: "2 days ago", topics: [{ name: "ML Fundamentals", score: 65 }, { name: "PyTorch", score: 41 }, { name: "Statistics", score: 70 }], riskFlag: "Stalling" },
  { id: "l4", name: "Raj Patel",    initials: "RP", overallProgress: 68, weekChange: +8,  streak: 12, xp: 8900,  missedDays: 0, lastActive: "Today",      topics: [{ name: "Java", score: 72 }, { name: "DSA", score: 67 }, { name: "Microservices", score: 60 }] },
  { id: "l5", name: "Mei Lin",      initials: "ML", overallProgress: 45, weekChange: -12, streak: 0,  xp: 3200,  missedDays: 5, lastActive: "5 days ago", topics: [{ name: "Statistics", score: 38 }, { name: "Probability", score: 34 }, { name: "Linear Algebra", score: 52 }], riskFlag: "At Risk" },
  { id: "l6", name: "David Okafor", initials: "DO", overallProgress: 38, weekChange: -9,  streak: 0,  xp: 2100,  missedDays: 7, lastActive: "7 days ago", topics: [{ name: "React", score: 44 }, { name: "JS Basics", score: 55 }, { name: "CSS", score: 60 }], riskFlag: "Inactive" },
];

const RISK_COLORS: Record<string, string> = {
  "At Risk":  "text-red-400 bg-red-500/10 border-red-500/30",
  "Stalling": "text-amber-400 bg-amber-500/10 border-amber-500/30",
  "Inactive": "text-orange-400 bg-orange-500/10 border-orange-500/30",
};

function ProgressCircle({ value, size = 48 }: { value: number; size?: number }) {
  const r = (size - 6) / 2;
  const c = 2 * Math.PI * r;
  const offset = c - (value / 100) * c;
  const color = value >= 80 ? "#10b981" : value >= 60 ? "#8b5cf6" : value >= 40 ? "#f59e0b" : "#ef4444";
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="-rotate-90">
      <circle cx={size / 2} cy={size / 2} r={r} stroke="rgba(255,255,255,0.1)" strokeWidth={5} fill="none" />
      <circle cx={size / 2} cy={size / 2} r={r} stroke={color} strokeWidth={5} fill="none"
        strokeDasharray={c} strokeDashoffset={offset} strokeLinecap="round" />
    </svg>
  );
}

export default function LearnerProgressPage() {
  const [expanded, setExpanded] = useState<string | null>(null);
  const [sortBy, setSortBy] = useState<"progress" | "streak" | "risk">("progress");

  const sorted = [...LEARNERS].sort((a, b) => {
    if (sortBy === "progress") return b.overallProgress - a.overallProgress;
    if (sortBy === "streak")   return b.streak - a.streak;
    return (b.riskFlag ? 1 : 0) - (a.riskFlag ? 1 : 0);
  });

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-4xl flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-indigo-600 shadow-lg">
              <TrendingUp className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">Learner Progress</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">{LEARNERS.length} learners · {LEARNERS.filter(l => l.riskFlag).length} need attention</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-xs text-[var(--muted-foreground)]">Sort:</span>
            {(["progress", "streak", "risk"] as const).map((s) => (
              <button key={s} onClick={() => setSortBy(s)}
                className={`rounded-lg px-3 py-1.5 text-xs font-medium capitalize transition-colors ${
                  sortBy === s ? "bg-violet-600 text-white" : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
                }`}>{s}</button>
            ))}
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-4xl space-y-3 px-4 py-5 sm:px-6">
          {/* Cohort summary */}
          <div className="grid grid-cols-4 gap-3">
            {[
              { label: "Avg. Progress", value: `${Math.round(LEARNERS.reduce((s, l) => s + l.overallProgress, 0) / LEARNERS.length)}%`, color: "text-violet-400" },
              { label: "At Risk",       value: LEARNERS.filter(l => l.riskFlag).length, color: "text-red-400" },
              { label: "Active Today",  value: LEARNERS.filter(l => l.lastActive === "Today").length, color: "text-emerald-400" },
              { label: "Total XP",      value: `${(LEARNERS.reduce((s, l) => s + l.xp, 0) / 1000).toFixed(1)}K`, color: "text-amber-400" },
            ].map((s) => (
              <div key={s.label} className="rounded-xl border border-white/5 bg-[var(--secondary)] p-3 text-center">
                <p className={`text-2xl font-black ${s.color}`}>{s.value}</p>
                <p className="text-[10px] text-[var(--muted-foreground)]">{s.label}</p>
              </div>
            ))}
          </div>

          {/* Learner cards */}
          {sorted.map((learner) => {
            const isOpen = expanded === learner.id;
            return (
              <div key={learner.id} className={`overflow-hidden rounded-2xl border bg-[var(--secondary)] ${learner.riskFlag ? "border-red-500/20" : "border-white/5"}`}>
                <button
                  onClick={() => setExpanded(isOpen ? null : learner.id)}
                  className="flex w-full items-center gap-4 px-5 py-4 text-left"
                >
                  {/* Progress circle */}
                  <div className="relative shrink-0">
                    <ProgressCircle value={learner.overallProgress} />
                    <div className="absolute inset-0 flex items-center justify-center">
                      <span className="text-[10px] font-bold text-[var(--foreground)]">{learner.overallProgress}%</span>
                    </div>
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="mb-1 flex flex-wrap items-center gap-2">
                      <span className="font-bold text-[var(--foreground)]">{learner.name}</span>
                      {learner.riskFlag && (
                        <span className={`rounded-full border px-2 py-0.5 text-[10px] font-bold ${RISK_COLORS[learner.riskFlag]}`}>
                          {learner.riskFlag}
                        </span>
                      )}
                    </div>
                    <div className="flex flex-wrap items-center gap-3 text-[10px] text-[var(--muted-foreground)]">
                      <span className="flex items-center gap-1"><Calendar className="h-3 w-3" />{learner.lastActive}</span>
                      <span className="flex items-center gap-1"><Flame className="h-3 w-3 text-orange-400" />{learner.streak}d streak</span>
                      <span className="flex items-center gap-1"><Star className="h-3 w-3 text-amber-400" />{(learner.xp / 1000).toFixed(1)}K XP</span>
                      {learner.weekChange > 0
                        ? <span className="flex items-center gap-1 text-emerald-400"><TrendingUp className="h-3 w-3" />+{learner.weekChange}% this week</span>
                        : <span className="flex items-center gap-1 text-red-400"><TrendingDown className="h-3 w-3" />{learner.weekChange}% this week</span>
                      }
                    </div>
                  </div>

                  {isOpen ? <ChevronUp className="h-4 w-4 shrink-0 text-[var(--muted-foreground)]" /> : <ChevronDown className="h-4 w-4 shrink-0 text-[var(--muted-foreground)]" />}
                </button>

                {isOpen && (
                  <div className="border-t border-white/5 px-5 pb-5 pt-4">
                    <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Topic Mastery</p>
                    <div className="space-y-2">
                      {learner.topics.map((t) => (
                        <div key={t.name}>
                          <div className="mb-1 flex justify-between text-xs">
                            <span className="flex items-center gap-1.5 text-[var(--muted-foreground)]">
                              <Brain className="h-3 w-3 text-violet-400" /> {t.name}
                            </span>
                            <span className={`font-bold ${t.score >= 75 ? "text-emerald-400" : t.score >= 55 ? "text-amber-400" : "text-red-400"}`}>
                              {t.score}%
                            </span>
                          </div>
                          <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
                            <div className={`h-full rounded-full ${t.score >= 75 ? "bg-emerald-500" : t.score >= 55 ? "bg-amber-500" : "bg-red-500"}`}
                              style={{ width: `${t.score}%` }} />
                          </div>
                        </div>
                      ))}
                    </div>
                    <div className="mt-4 flex gap-2">
                      <button className="flex items-center gap-1.5 rounded-lg bg-violet-600/20 px-3 py-1.5 text-xs font-semibold text-violet-300 hover:bg-violet-600/30 transition-colors">
                        <Target className="h-3.5 w-3.5" /> Create Intervention Plan
                      </button>
                      <button className="flex items-center gap-1.5 rounded-lg bg-white/5 px-3 py-1.5 text-xs font-medium text-[var(--muted-foreground)] hover:bg-white/10 transition-colors">
                        Message Learner
                      </button>
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
