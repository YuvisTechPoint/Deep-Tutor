/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  AlertTriangle,
  Bell,
  BookOpen,
  Brain,
  CheckCircle2,
  Clock,
  Code2,
  Flame,
  MessageSquare,
  Search,
  TrendingUp,
  User,
  Users,
  Zap,
} from "lucide-react";

type LearnerStatus = "on-track" | "needs-help" | "at-risk";

interface Learner {
  id: string;
  name: string;
  initials: string;
  topic: string;
  progress: number;
  score: number;
  streak: number;
  lastActive: string;
  status: LearnerStatus;
  xp: number;
  icon: React.ReactNode;
}

const STATUS_CONFIG: Record<LearnerStatus, { label: string; color: string }> = {
  "on-track":   { label: "On Track",    color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/30" },
  "needs-help": { label: "Needs Help",  color: "text-amber-400 bg-amber-500/10 border-amber-500/30" },
  "at-risk":    { label: "At Risk",     color: "text-red-400 bg-red-500/10 border-red-500/30" },
};

const LEARNERS: Learner[] = [
  { id: "1", name: "Aisha Raza",     initials: "AR", topic: "Dynamic Programming", progress: 82, score: 91, streak: 14, lastActive: "2h ago",   status: "on-track",   xp: 4200, icon: <Code2 className="h-4 w-4" /> },
  { id: "2", name: "Marcus Chen",    initials: "MC", topic: "System Design",       progress: 65, score: 73, streak: 7,  lastActive: "4h ago",   status: "on-track",   xp: 3100, icon: <Brain className="h-4 w-4" /> },
  { id: "3", name: "Priya Sharma",   initials: "PS", topic: "ML Fundamentals",     progress: 41, score: 58, streak: 2,  lastActive: "2 days",   status: "needs-help", xp: 1800, icon: <Zap className="h-4 w-4" /> },
  { id: "4", name: "David Okafor",   initials: "DO", topic: "React Hooks",         progress: 33, score: 44, streak: 0,  lastActive: "4 days",   status: "at-risk",    xp: 900,  icon: <Code2 className="h-4 w-4" /> },
  { id: "5", name: "Sara Kim",       initials: "SK", topic: "Graphs & Trees",      progress: 76, score: 85, streak: 11, lastActive: "1h ago",   status: "on-track",   xp: 3800, icon: <Brain className="h-4 w-4" /> },
  { id: "6", name: "Raj Patel",      initials: "RP", topic: "Sorting Algorithms",  progress: 58, score: 67, streak: 5,  lastActive: "Yesterday",status: "needs-help", xp: 2400, icon: <Zap className="h-4 w-4" /> },
  { id: "7", name: "Mei Lin",        initials: "ML", topic: "Probability",         progress: 25, score: 38, streak: 0,  lastActive: "5 days",   status: "at-risk",    xp: 600,  icon: <BookOpen className="h-4 w-4" /> },
  { id: "8", name: "Ahmed Hassan",   initials: "AH", topic: "Binary Search",       progress: 92, score: 96, streak: 18, lastActive: "30m ago",  status: "on-track",   xp: 5100, icon: <TrendingUp className="h-4 w-4" /> },
];

const COHORT_STATS = [
  { label: "Total Learners",   value: "8",   icon: <Users className="h-5 w-5" />,       color: "text-violet-400" },
  { label: "Active This Week", value: "6",   icon: <Flame className="h-5 w-5" />,        color: "text-orange-400" },
  { label: "Avg Score",        value: "69%", icon: <TrendingUp className="h-5 w-5" />,   color: "text-emerald-400" },
  { label: "At Risk",          value: "2",   icon: <AlertTriangle className="h-5 w-5" />, color: "text-red-400" },
];

export default function MentorDashboardPage() {
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<LearnerStatus | "all">("all");
  const [notified, setNotified] = useState<Set<string>>(new Set());

  const filtered = LEARNERS.filter((l) => {
    const matchSearch = l.name.toLowerCase().includes(search.toLowerCase()) || l.topic.toLowerCase().includes(search.toLowerCase());
    const matchFilter = filter === "all" || l.status === filter;
    return matchSearch && matchFilter;
  });

  const atRisk = LEARNERS.filter((l) => l.status === "at-risk");
  const needsHelp = LEARNERS.filter((l) => l.status === "needs-help");

  const sendNudge = (id: string) => setNotified((prev) => new Set([...prev, id]));

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-6xl flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-indigo-600 shadow-lg">
              <Users className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">Mentor Dashboard</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">SWE Track — Cohort July 2026</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {(["all", "on-track", "needs-help", "at-risk"] as const).map((s) => (
              <button
                key={s}
                onClick={() => setFilter(s)}
                className={`rounded-lg px-3 py-1.5 text-xs font-medium capitalize transition-colors ${
                  filter === s
                    ? "bg-violet-600 text-white"
                    : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
                }`}
              >
                {s === "all" ? "All" : STATUS_CONFIG[s].label}
              </button>
            ))}
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-6xl space-y-6 px-4 py-6 sm:px-6">
          {/* KPI cards */}
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
            {COHORT_STATS.map((s) => (
              <div key={s.label} className="rounded-xl border border-white/5 bg-[var(--secondary)] p-4">
                <div className={`mb-1 ${s.color}`}>{s.icon}</div>
                <p className={`text-2xl font-black ${s.color}`}>{s.value}</p>
                <p className="text-[10px] text-[var(--muted-foreground)]">{s.label}</p>
              </div>
            ))}
          </div>

          {/* Alerts */}
          {(atRisk.length > 0 || needsHelp.length > 0) && (
            <div className="rounded-xl border border-red-500/20 bg-red-500/5 p-4">
              <div className="mb-3 flex items-center gap-2">
                <AlertTriangle className="h-4 w-4 text-red-400" />
                <span className="text-sm font-semibold text-red-400">Learners needing attention</span>
              </div>
              <div className="space-y-2">
                {[...atRisk, ...needsHelp].map((l) => (
                  <div key={l.id} className="flex items-center gap-3 rounded-lg bg-white/3 px-3 py-2 text-sm">
                    <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-violet-500/20 text-xs font-bold text-violet-400">
                      {l.initials}
                    </div>
                    <span className="flex-1 font-medium text-[var(--foreground)]">{l.name}</span>
                    <span className="text-[var(--muted-foreground)]">{l.topic}</span>
                    <span className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${STATUS_CONFIG[l.status].color}`}>
                      {STATUS_CONFIG[l.status].label}
                    </span>
                    <span className="text-xs text-[var(--muted-foreground)]">Last: {l.lastActive}</span>
                    <button
                      onClick={() => sendNudge(l.id)}
                      disabled={notified.has(l.id)}
                      className="flex items-center gap-1.5 rounded-lg bg-amber-600 px-2.5 py-1 text-xs font-semibold text-white hover:bg-amber-500 transition-colors disabled:opacity-50"
                    >
                      <Bell className="h-3 w-3" />
                      {notified.has(l.id) ? "Sent!" : "Nudge"}
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Search */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--muted-foreground)]" />
            <input
              type="text"
              placeholder="Search learners or topics..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full rounded-xl border border-white/5 bg-[var(--secondary)] py-2.5 pl-10 pr-4 text-sm text-[var(--foreground)] outline-none ring-violet-500/30 placeholder:text-[var(--muted-foreground)] focus:ring-2"
            />
          </div>

          {/* Learners table */}
          <div className="overflow-hidden rounded-2xl border border-white/5 bg-[var(--secondary)]">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-white/5">
                  <th className="px-4 py-3 text-left text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Learner</th>
                  <th className="px-4 py-3 text-left text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Current Topic</th>
                  <th className="px-4 py-3 text-left text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Progress</th>
                  <th className="px-4 py-3 text-left text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Score</th>
                  <th className="hidden px-4 py-3 text-left text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)] sm:table-cell">Streak</th>
                  <th className="hidden px-4 py-3 text-left text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)] md:table-cell">Last Active</th>
                  <th className="px-4 py-3 text-left text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Status</th>
                  <th className="px-4 py-3 text-left text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Actions</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((l, i) => (
                  <tr key={l.id} className={`border-b border-white/5 ${i % 2 === 0 ? "" : "bg-white/1"}`}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2.5">
                        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-violet-500 to-indigo-600 text-xs font-bold text-white">
                          {l.initials}
                        </div>
                        <span className="font-medium text-[var(--foreground)]">{l.name}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2 text-[var(--muted-foreground)]">
                        {l.icon}
                        <span className="truncate">{l.topic}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <div className="h-2 w-20 overflow-hidden rounded-full bg-white/10">
                          <div
                            className={`h-full rounded-full transition-all ${l.progress >= 70 ? "bg-emerald-400" : l.progress >= 40 ? "bg-amber-400" : "bg-red-400"}`}
                            style={{ width: `${l.progress}%` }}
                          />
                        </div>
                        <span className="text-xs font-semibold text-[var(--foreground)]">{l.progress}%</span>
                      </div>
                    </td>
                    <td className={`px-4 py-3 font-bold ${l.score >= 80 ? "text-emerald-400" : l.score >= 60 ? "text-amber-400" : "text-red-400"}`}>
                      {l.score}%
                    </td>
                    <td className="hidden px-4 py-3 sm:table-cell">
                      <div className="flex items-center gap-1 text-orange-400">
                        <Flame className="h-3.5 w-3.5" />
                        <span className="text-xs font-semibold">{l.streak}d</span>
                      </div>
                    </td>
                    <td className="hidden px-4 py-3 text-xs text-[var(--muted-foreground)] md:table-cell">
                      <div className="flex items-center gap-1">
                        <Clock className="h-3 w-3" />
                        {l.lastActive}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${STATUS_CONFIG[l.status].color}`}>
                        {STATUS_CONFIG[l.status].label}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1.5">
                        <button
                          onClick={() => sendNudge(l.id)}
                          disabled={notified.has(l.id)}
                          title="Send nudge"
                          className="flex h-7 w-7 items-center justify-center rounded-lg bg-amber-500/10 text-amber-400 hover:bg-amber-500/20 transition-colors disabled:opacity-40"
                        >
                          <Bell className="h-3.5 w-3.5" />
                        </button>
                        <button title="Add note" className="flex h-7 w-7 items-center justify-center rounded-lg bg-blue-500/10 text-blue-400 hover:bg-blue-500/20 transition-colors">
                          <MessageSquare className="h-3.5 w-3.5" />
                        </button>
                        <button title="View profile" className="flex h-7 w-7 items-center justify-center rounded-lg bg-violet-500/10 text-violet-400 hover:bg-violet-500/20 transition-colors">
                          <User className="h-3.5 w-3.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {filtered.length === 0 && (
                  <tr>
                    <td colSpan={8} className="py-12 text-center text-[var(--muted-foreground)]">
                      No learners found matching your filters.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Bottom summary */}
          <div className="rounded-xl border border-white/5 bg-[var(--secondary)] p-4">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <span className="text-sm text-[var(--muted-foreground)]">
                Showing {filtered.length} of {LEARNERS.length} learners
              </span>
              <div className="flex items-center gap-4 text-sm">
                <span className="flex items-center gap-1.5 text-emerald-400">
                  <CheckCircle2 className="h-4 w-4" />
                  {LEARNERS.filter(l => l.status === "on-track").length} on track
                </span>
                <span className="flex items-center gap-1.5 text-amber-400">
                  <AlertTriangle className="h-4 w-4" />
                  {LEARNERS.filter(l => l.status === "needs-help").length} needs help
                </span>
                <span className="flex items-center gap-1.5 text-red-400">
                  <AlertTriangle className="h-4 w-4" />
                  {LEARNERS.filter(l => l.status === "at-risk").length} at risk
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
