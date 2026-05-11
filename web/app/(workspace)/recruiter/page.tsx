/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  Bookmark,
  BookmarkCheck,
  Briefcase,
  CheckCircle2,
  Code2,
  Eye,
  Flame,
  Search,
  Sparkles,
  Star,
  Target,
  TrendingUp,
  Users,
  Zap,
} from "lucide-react";

interface Candidate {
  id: string;
  name: string;
  initials: string;
  headline: string;
  location: string;
  domain: string;
  skills: string[];
  xp: number;
  streak: number;
  readiness: number;
  active: boolean;
  topColor: string;
}

const CANDIDATES: Candidate[] = [
  {
    id: "1", name: "Aisha Raza", initials: "AR", headline: "CS Graduate · FAANG Prep",
    location: "New Delhi, India", domain: "backend",
    skills: ["Python", "DSA", "System Design", "SQL", "Docker"],
    xp: 14200, streak: 24, readiness: 91, active: true, topColor: "from-violet-500 to-indigo-600",
  },
  {
    id: "2", name: "Marcus Chen", initials: "MC", headline: "Self-taught Full-stack Dev",
    location: "San Francisco, USA", domain: "frontend",
    skills: ["React", "TypeScript", "Node.js", "CSS", "Testing"],
    xp: 11800, streak: 18, readiness: 84, active: true, topColor: "from-blue-500 to-cyan-600",
  },
  {
    id: "3", name: "Sara Kim", initials: "SK", headline: "ML Engineer Candidate",
    location: "Seoul, South Korea", domain: "ml",
    skills: ["PyTorch", "Python", "Statistics", "Transformers", "MLOps"],
    xp: 9400, streak: 31, readiness: 78, active: false, topColor: "from-emerald-500 to-teal-600",
  },
  {
    id: "4", name: "Raj Patel", initials: "RP", headline: "Backend SDE Candidate",
    location: "Mumbai, India", domain: "backend",
    skills: ["Java", "Microservices", "Kafka", "PostgreSQL", "K8s"],
    xp: 8900, streak: 12, readiness: 72, active: true, topColor: "from-amber-500 to-orange-600",
  },
  {
    id: "5", name: "Mei Lin", initials: "ML", headline: "Data Engineer Track",
    location: "Singapore", domain: "data",
    skills: ["Spark", "Airflow", "Python", "SQL", "dbt"],
    xp: 7200, streak: 8, readiness: 68, active: true, topColor: "from-pink-500 to-rose-600",
  },
  {
    id: "6", name: "Ahmed Hassan", initials: "AH", headline: "Bootcamp Graduate → SWE",
    location: "Cairo, Egypt", domain: "frontend",
    skills: ["React", "JavaScript", "CSS", "Git", "REST APIs"],
    xp: 6100, streak: 5, readiness: 61, active: false, topColor: "from-cyan-500 to-sky-600",
  },
];

const DOMAINS = ["All", "backend", "frontend", "ml", "data", "devops"];

function readinessColor(r: number) {
  if (r >= 80) return { text: "text-emerald-400", bg: "bg-emerald-500/10 border-emerald-500/30", bar: "bg-emerald-400" };
  if (r >= 65) return { text: "text-amber-400",   bg: "bg-amber-500/10 border-amber-500/30",   bar: "bg-amber-400"   };
  return               { text: "text-red-400",     bg: "bg-red-500/10 border-red-500/30",       bar: "bg-red-400"     };
}

export default function RecruiterPage() {
  const [search, setSearch] = useState("");
  const [domain, setDomain] = useState("All");
  const [saved, setSaved] = useState<Set<string>>(new Set());
  const [sort, setSort] = useState<"readiness" | "xp" | "streak">("readiness");

  const toggleSave = (id: string) =>
    setSaved((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    });

  const filtered = CANDIDATES
    .filter((c) => {
      const matchSearch =
        c.name.toLowerCase().includes(search.toLowerCase()) ||
        c.skills.some((s) => s.toLowerCase().includes(search.toLowerCase()));
      const matchDomain = domain === "All" || c.domain === domain;
      return matchSearch && matchDomain;
    })
    .sort((a, b) => b[sort] - a[sort]);

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-6xl flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-pink-500 to-rose-600 shadow-lg">
              <Briefcase className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">Talent Search</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">TechCorp Recruiting · Verified Learner Profiles</p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            {/* Stats */}
            <div className="hidden items-center gap-4 sm:flex">
              {[
                { icon: <Eye className="h-4 w-4 text-blue-400" />, value: "34", label: "Viewed" },
                { icon: <Bookmark className="h-4 w-4 text-amber-400" />, value: String(saved.size), label: "Saved" },
                { icon: <CheckCircle2 className="h-4 w-4 text-emerald-400" />, value: "2", label: "Contacted" },
              ].map((s) => (
                <div key={s.label} className="text-center">
                  <div className="flex items-center gap-1">
                    {s.icon}
                    <span className="text-sm font-bold text-[var(--foreground)]">{s.value}</span>
                  </div>
                  <p className="text-[10px] text-[var(--muted-foreground)]">{s.label}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-6xl space-y-6 px-4 py-6 sm:px-6">
          {/* Search + filters */}
          <div className="flex flex-col gap-3 sm:flex-row">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--muted-foreground)]" />
              <input
                type="text"
                placeholder="Search by name or skill (e.g. Python, React, DSA)..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="w-full rounded-xl border border-white/5 bg-[var(--secondary)] py-2.5 pl-10 pr-4 text-sm text-[var(--foreground)] outline-none ring-violet-500/30 placeholder:text-[var(--muted-foreground)] focus:ring-2"
              />
            </div>
            <div className="flex gap-2">
              <select
                value={sort}
                onChange={(e) => setSort(e.target.value as typeof sort)}
                className="rounded-xl border border-white/5 bg-[var(--secondary)] px-3 py-2 text-sm text-[var(--foreground)] outline-none"
              >
                <option value="readiness">Sort: Readiness</option>
                <option value="xp">Sort: XP</option>
                <option value="streak">Sort: Streak</option>
              </select>
            </div>
          </div>

          {/* Domain filters */}
          <div className="flex flex-wrap gap-2">
            {DOMAINS.map((d) => (
              <button
                key={d}
                onClick={() => setDomain(d)}
                className={`rounded-full px-3 py-1.5 text-xs font-semibold capitalize transition-colors ${
                  domain === d ? "bg-violet-600 text-white" : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
                }`}
              >
                {d === "All" ? "All Domains" : d}
              </button>
            ))}
          </div>

          {/* Candidate grid */}
          <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {filtered.map((c) => {
              const rc = readinessColor(c.readiness);
              const isSaved = saved.has(c.id);
              return (
                <div
                  key={c.id}
                  className="group flex flex-col rounded-2xl border border-white/5 bg-[var(--secondary)] overflow-hidden transition-all hover:border-white/10 hover:shadow-xl hover:scale-[1.02]"
                >
                  {/* Top gradient bar */}
                  <div className={`h-1.5 w-full bg-gradient-to-r ${c.topColor}`} />

                  <div className="flex-1 p-5">
                    {/* Header */}
                    <div className="mb-4 flex items-start justify-between gap-3">
                      <div className="flex items-center gap-3">
                        <div className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br ${c.topColor} text-sm font-bold text-white shadow-lg`}>
                          {c.initials}
                        </div>
                        <div>
                          <p className="font-bold text-[var(--foreground)]">{c.name}</p>
                          <p className="text-xs text-[var(--muted-foreground)]">{c.headline}</p>
                        </div>
                      </div>
                      <div className="flex flex-col items-end gap-1.5">
                        {c.active && (
                          <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">
                            Active
                          </span>
                        )}
                        <button onClick={() => toggleSave(c.id)} className="text-[var(--muted-foreground)] hover:text-amber-400 transition-colors">
                          {isSaved ? <BookmarkCheck className="h-4.5 w-4.5 text-amber-400" /> : <Bookmark className="h-4.5 w-4.5" />}
                        </button>
                      </div>
                    </div>

                    {/* Skills */}
                    <div className="mb-4 flex flex-wrap gap-1.5">
                      {c.skills.slice(0, 4).map((s) => (
                        <span key={s} className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] font-medium text-[var(--muted-foreground)]">
                          {s}
                        </span>
                      ))}
                      {c.skills.length > 4 && (
                        <span className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] text-[var(--muted-foreground)]">
                          +{c.skills.length - 4}
                        </span>
                      )}
                    </div>

                    {/* Stats row */}
                    <div className="mb-4 grid grid-cols-3 gap-2 text-center">
                      <div>
                        <div className="flex items-center justify-center gap-1 text-amber-400">
                          <Star className="h-3 w-3" />
                          <span className="text-xs font-bold">{(c.xp / 1000).toFixed(1)}K</span>
                        </div>
                        <p className="text-[10px] text-[var(--muted-foreground)]">XP</p>
                      </div>
                      <div>
                        <div className="flex items-center justify-center gap-1 text-orange-400">
                          <Flame className="h-3 w-3" />
                          <span className="text-xs font-bold">{c.streak}d</span>
                        </div>
                        <p className="text-[10px] text-[var(--muted-foreground)]">Streak</p>
                      </div>
                      <div>
                        <div className={`flex items-center justify-center gap-1 ${rc.text}`}>
                          <Target className="h-3 w-3" />
                          <span className="text-xs font-bold">{c.readiness}%</span>
                        </div>
                        <p className="text-[10px] text-[var(--muted-foreground)]">Readiness</p>
                      </div>
                    </div>

                    {/* Readiness bar */}
                    <div className="mb-4">
                      <div className="mb-1 flex items-center justify-between text-[10px] text-[var(--muted-foreground)]">
                        <span>Role Readiness</span>
                        <span className={rc.text}>{c.readiness}%</span>
                      </div>
                      <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
                        <div className={`h-full rounded-full transition-all ${rc.bar}`} style={{ width: `${c.readiness}%` }} />
                      </div>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="border-t border-white/5 px-5 py-3">
                    <div className="flex gap-2">
                      <button className="flex flex-1 items-center justify-center gap-1.5 rounded-lg bg-violet-600 py-2 text-xs font-semibold text-white hover:bg-violet-500 transition-colors">
                        <Eye className="h-3.5 w-3.5" />
                        View Profile
                      </button>
                      <button className="flex items-center justify-center rounded-lg bg-white/5 px-3 py-2 text-[var(--muted-foreground)] hover:bg-white/10 transition-colors">
                        <TrendingUp className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {filtered.length === 0 && (
            <div className="flex flex-col items-center justify-center py-16 text-center">
              <Users className="mb-4 h-12 w-12 text-[var(--muted-foreground)]" />
              <p className="text-[var(--muted-foreground)]">No candidates match your search criteria.</p>
            </div>
          )}

          {/* AI suggestion banner */}
          <div className="rounded-xl border border-violet-500/20 bg-violet-500/5 p-4">
            <div className="flex items-start gap-3">
              <Sparkles className="mt-0.5 h-5 w-5 shrink-0 text-violet-400" />
              <div>
                <p className="mb-1 text-sm font-semibold text-violet-300">AI Matching Suggestion</p>
                <p className="text-sm text-[var(--muted-foreground)]">
                  Based on your hiring criteria for a <strong className="text-[var(--foreground)]">Backend SDE</strong>, 
                  Aisha Raza (91%) and Raj Patel (72%) are your strongest matches.
                  Consider comparing their system design scores before reaching out.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
