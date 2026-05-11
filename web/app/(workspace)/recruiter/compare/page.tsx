/* eslint-disable i18n/no-literal-ui-text */
"use client";

import {
  ArrowLeft,
  Brain,
  Briefcase,
  Code2,
  Flame,
  Star,
  Target,
  TrendingUp,
} from "lucide-react";
import Link from "next/link";

interface Candidate {
  id: string;
  name: string;
  initials: string;
  headline: string;
  color: string;
  overall: number;
  xp: number;
  streak: number;
  problems: number;
  hours: number;
  skills: { name: string; score: number }[];
  readiness: number;
  domain: string;
  location: string;
}

const CANDIDATES: Candidate[] = [
  {
    id: "1", name: "Aisha Raza", initials: "AR",
    headline: "CS Graduate · FAANG Prep",
    color: "from-violet-500 to-indigo-600",
    overall: 91, xp: 14200, streak: 24, problems: 312, hours: 89, readiness: 91,
    domain: "Backend SDE", location: "New Delhi, India",
    skills: [
      { name: "Python",        score: 92 },
      { name: "DSA",           score: 88 },
      { name: "System Design", score: 85 },
      { name: "SQL",           score: 78 },
      { name: "Docker/K8s",    score: 55 },
      { name: "ML/AI",         score: 40 },
    ],
  },
  {
    id: "2", name: "Raj Patel", initials: "RP",
    headline: "Backend SDE · Java/Microservices",
    color: "from-amber-500 to-orange-600",
    overall: 72, xp: 8900, streak: 12, problems: 198, hours: 62, readiness: 72,
    domain: "Backend SDE", location: "Mumbai, India",
    skills: [
      { name: "Python",        score: 65 },
      { name: "DSA",           score: 70 },
      { name: "System Design", score: 72 },
      { name: "SQL",           score: 81 },
      { name: "Docker/K8s",    score: 68 },
      { name: "ML/AI",         score: 22 },
    ],
  },
  {
    id: "3", name: "Marcus Chen", initials: "MC",
    headline: "Full-stack Dev · Node.js/React",
    color: "from-blue-500 to-cyan-600",
    overall: 84, xp: 11800, streak: 18, problems: 241, hours: 75, readiness: 84,
    domain: "Full-stack", location: "San Francisco, USA",
    skills: [
      { name: "Python",        score: 72 },
      { name: "DSA",           score: 75 },
      { name: "System Design", score: 68 },
      { name: "SQL",           score: 70 },
      { name: "Docker/K8s",    score: 48 },
      { name: "ML/AI",         score: 31 },
    ],
  },
];

function ScoreBar({ score, color }: { score: number; color: string }) {
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-2 overflow-hidden rounded-full bg-white/10">
        <div className={`h-full rounded-full bg-gradient-to-r ${color}`} style={{ width: `${score}%` }} />
      </div>
      <span className="text-xs font-bold text-[var(--foreground)] w-8 text-right">{score}</span>
    </div>
  );
}

function overallColor(score: number) {
  if (score >= 85) return "text-emerald-400";
  if (score >= 70) return "text-amber-400";
  return "text-red-400";
}

export default function ComparePageUI() {
  const SKILLS = CANDIDATES[0].skills.map((s) => s.name);

  const bestFit = CANDIDATES.reduce((best, c) => (c.overall > best.overall ? c : best), CANDIDATES[0]);

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-5xl flex items-center gap-4">
          <Link href="/recruiter" className="text-[var(--muted-foreground)] hover:text-[var(--foreground)] transition-colors">
            <ArrowLeft className="h-5 w-5" />
          </Link>
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-pink-500 to-rose-600 shadow-lg">
              <TrendingUp className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">Candidate Comparison</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">Side-by-side skill assessment</p>
            </div>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-5xl space-y-6 px-4 py-6 sm:px-6">
          {/* Candidate headers */}
          <div className="grid grid-cols-4 gap-4">
            <div className="col-span-1" /> {/* label column */}
            {CANDIDATES.map((c) => (
              <div key={c.id} className="col-span-1 text-center">
                <div className={`mx-auto mb-2 flex h-14 w-14 items-center justify-center rounded-xl bg-gradient-to-br ${c.color} text-lg font-bold text-white shadow-lg`}>
                  {c.initials}
                </div>
                <p className="font-bold text-[var(--foreground)] text-sm">{c.name}</p>
                <p className="text-[11px] text-[var(--muted-foreground)]">{c.headline}</p>
                <p className="text-[10px] text-[var(--muted-foreground)]">{c.location}</p>
                {c.id === bestFit.id && (
                  <span className="mt-1 inline-block rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-bold text-emerald-400">
                    Best Fit
                  </span>
                )}
              </div>
            ))}
          </div>

          {/* Overall readiness */}
          <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
            <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">Overall Readiness Score</h3>
            <div className="grid grid-cols-4 gap-4 items-center">
              <span className="text-xs text-[var(--muted-foreground)]">Role Readiness</span>
              {CANDIDATES.map((c) => (
                <div key={c.id} className="text-center">
                  <p className={`text-4xl font-black ${overallColor(c.overall)}`}>{c.overall}%</p>
                </div>
              ))}
            </div>
          </div>

          {/* Key stats */}
          <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
            <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">Key Statistics</h3>
            <div className="space-y-3">
              {[
                {
                  label: "XP Earned", icon: <Star className="h-3.5 w-3.5 text-amber-400" />,
                  values: CANDIDATES.map((c) => ({ v: `${(c.xp / 1000).toFixed(1)}K`, best: c.xp === Math.max(...CANDIDATES.map(x => x.xp)) })),
                },
                {
                  label: "Problems Solved", icon: <Code2 className="h-3.5 w-3.5 text-blue-400" />,
                  values: CANDIDATES.map((c) => ({ v: c.problems, best: c.problems === Math.max(...CANDIDATES.map(x => x.problems)) })),
                },
                {
                  label: "Study Hours", icon: <TrendingUp className="h-3.5 w-3.5 text-violet-400" />,
                  values: CANDIDATES.map((c) => ({ v: `${c.hours}h`, best: c.hours === Math.max(...CANDIDATES.map(x => x.hours)) })),
                },
                {
                  label: "Day Streak", icon: <Flame className="h-3.5 w-3.5 text-orange-400" />,
                  values: CANDIDATES.map((c) => ({ v: `${c.streak}d`, best: c.streak === Math.max(...CANDIDATES.map(x => x.streak)) })),
                },
              ].map((row) => (
                <div key={row.label} className="grid grid-cols-4 gap-4 items-center py-2 border-b border-white/5 last:border-0">
                  <div className="flex items-center gap-1.5 text-xs text-[var(--muted-foreground)]">
                    {row.icon} {row.label}
                  </div>
                  {row.values.map((val, i) => (
                    <div key={i} className={`text-center text-sm font-bold ${val.best ? "text-emerald-400" : "text-[var(--foreground)]"}`}>
                      {val.v}
                      {val.best && <span className="ml-1 text-[10px]">★</span>}
                    </div>
                  ))}
                </div>
              ))}
            </div>
          </div>

          {/* Skill breakdown */}
          <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
            <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">Skill-by-Skill Breakdown</h3>
            <div className="space-y-4">
              {SKILLS.map((skill) => (
                <div key={skill}>
                  <div className="mb-2 flex items-center gap-2 text-xs font-semibold text-[var(--foreground)]">
                    <Brain className="h-3.5 w-3.5 text-violet-400" /> {skill}
                  </div>
                  <div className="grid grid-cols-3 gap-3">
                    {CANDIDATES.map((c) => {
                      const s = c.skills.find((sk) => sk.name === skill);
                      const score = s?.score ?? 0;
                      const maxScore = Math.max(...CANDIDATES.map(ca => ca.skills.find(sk => sk.name === skill)?.score ?? 0));
                      const isTop = score === maxScore;
                      return (
                        <div key={c.id}>
                          <div className="mb-1 flex items-center justify-between text-[10px]">
                            <span className={isTop ? "text-emerald-400 font-bold" : "text-[var(--muted-foreground)]"}>{c.name.split(" ")[0]}</span>
                            <span className={isTop ? "text-emerald-400 font-bold" : "text-[var(--foreground)]"}>{score}%</span>
                          </div>
                          <ScoreBar score={score} color={isTop ? "from-emerald-500 to-teal-500" : `from-violet-500/60 to-indigo-500/60`} />
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Recommendation */}
          <div className="rounded-2xl border border-emerald-500/20 bg-gradient-to-br from-emerald-500/10 to-teal-500/5 p-6">
            <div className="mb-2 flex items-center gap-2">
              <Target className="h-5 w-5 text-emerald-400" />
              <span className="font-bold text-emerald-400">AI Recommendation</span>
            </div>
            <p className="text-sm text-[var(--foreground)]">
              Based on the skill comparison, <strong className="text-emerald-400">{bestFit.name}</strong> is the strongest candidate
              for a <strong>Backend SDE</strong> role with {bestFit.overall}% readiness. She leads in Python (+20%), DSA (+13%),
              and System Design (+17%) — all critical skills for this role. Recommend proceeding to technical interview.
            </p>
            <div className="mt-4 flex gap-3">
              <button className="flex items-center gap-1.5 rounded-lg bg-emerald-600 px-4 py-2 text-xs font-semibold text-white hover:bg-emerald-500 transition-colors">
                <Briefcase className="h-3.5 w-3.5" /> Schedule Interview
              </button>
              <button className="flex items-center gap-1.5 rounded-lg bg-white/5 px-4 py-2 text-xs font-medium text-[var(--muted-foreground)] hover:bg-white/10 transition-colors">
                Export Report
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
