/* eslint-disable i18n/no-literal-ui-text */
"use client";

import {
  ArrowLeft,
  Award,
  BookOpen,
  Brain,
  Briefcase,
  Calendar,
  CheckCircle2,
  Code2,
  ExternalLink,
  Flame,
  Github,
  Globe,
  Linkedin,
  Mail,
  MapPin,
  Star,
  Target,
  TrendingUp,
} from "lucide-react";
import Link from "next/link";

const CANDIDATE = {
  name: "Aisha Raza",
  headline: "CS Graduate · FAANG Prep · Backend SDE",
  location: "New Delhi, India",
  email: "aisha.raza@email.com",
  github: "github.com/aisharaza",
  linkedin: "linkedin.com/in/aisharaza",
  portfolio: "aisharaza.dev",
  bio: "Passionate about distributed systems and high-performance backend engineering. Currently preparing intensively for FAANG SDE roles through DeepTutor's structured roadmap.",
  overallScore: 91,
  streak: 24,
  xp: 14200,
  problemsSolved: 312,
  hoursStudied: 89,
  joinedDate: "January 2026",
  skills: [
    { name: "Python",         score: 92, verified: true },
    { name: "Data Structures & Algorithms", score: 88, verified: true },
    { name: "System Design",  score: 85, verified: true },
    { name: "SQL / PostgreSQL", score: 78, verified: false },
    { name: "REST API Design", score: 82, verified: true },
    { name: "Docker / Kubernetes", score: 55, verified: false },
    { name: "React (basic)",  score: 45, verified: false },
    { name: "ML / AI",        score: 40, verified: false },
  ],
  certifications: [
    { name: "DSA Mastery — DeepTutor Verified", date: "Apr 2026", icon: "🏆" },
    { name: "System Design Foundations",        date: "Mar 2026", icon: "🏗" },
    { name: "Python Advanced Track",            date: "Feb 2026", icon: "🐍" },
  ],
  recentActivity: [
    { label: "Solved Hard: LRU Cache Implementation", date: "May 11", type: "code" },
    { label: "Completed: Distributed Systems module", date: "May 10", type: "lesson" },
    { label: "Mock test: System Design — 87/100",     date: "May 9",  type: "test" },
    { label: "Reviewed: Consistent Hashing notes",    date: "May 8",  type: "review" },
    { label: "Solved 15 tree traversal problems",     date: "May 7",  type: "code" },
  ],
  roadmap: [
    { phase: "Python & OOP",         done: true },
    { phase: "DSA Fundamentals",      done: true },
    { phase: "Advanced DSA",          done: true },
    { phase: "System Design Basics",  done: true },
    { phase: "Advanced System Design", done: false },
    { phase: "Mock Interviews",        done: false },
    { phase: "Offer Ready",            done: false },
  ],
};

function SkillBar({ name, score, verified }: { name: string; score: number; verified: boolean }) {
  const color = score >= 80 ? "from-emerald-500 to-teal-500" : score >= 60 ? "from-violet-500 to-indigo-500" : "from-amber-500 to-orange-500";
  return (
    <div>
      <div className="mb-1.5 flex items-center justify-between">
        <div className="flex items-center gap-1.5 text-xs text-[var(--foreground)]">
          {name}
          {verified && <CheckCircle2 className="h-3 w-3 text-emerald-400" />}
        </div>
        <span className="text-xs font-bold text-[var(--foreground)]">{score}%</span>
      </div>
      <div className="h-2 overflow-hidden rounded-full bg-white/10">
        <div className={`h-full rounded-full bg-gradient-to-r ${color} transition-all duration-500`} style={{ width: `${score}%` }} />
      </div>
    </div>
  );
}

export default function CandidateProfilePage() {
  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-5xl flex items-center gap-4">
          <Link href="/recruiter" className="text-[var(--muted-foreground)] hover:text-[var(--foreground)] transition-colors">
            <ArrowLeft className="h-5 w-5" />
          </Link>
          <div className="flex items-center gap-3">
            <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-indigo-600 text-lg font-bold text-white shadow-lg">
              AR
            </div>
            <div>
              <h1 className="font-bold text-[var(--foreground)]">{CANDIDATE.name}</h1>
              <p className="text-xs text-[var(--muted-foreground)]">{CANDIDATE.headline}</p>
            </div>
          </div>
          <div className="ml-auto flex gap-2">
            <Link href="/recruiter/compare"
              className="flex items-center gap-1.5 rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-xs font-medium text-[var(--foreground)] hover:bg-white/10 transition-colors">
              <TrendingUp className="h-3.5 w-3.5" /> Compare
            </Link>
            <button className="flex items-center gap-1.5 rounded-xl bg-violet-600 px-4 py-2 text-xs font-semibold text-white hover:bg-violet-500 transition-colors">
              <Briefcase className="h-3.5 w-3.5" /> Schedule Interview
            </button>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-5xl px-4 py-6 sm:px-6">
          <div className="grid grid-cols-3 gap-6">
            {/* Left column */}
            <div className="col-span-1 space-y-5">
              {/* Contact */}
              <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-4 space-y-2">
                {[
                  { icon: <MapPin className="h-3.5 w-3.5" />, value: CANDIDATE.location },
                  { icon: <Mail className="h-3.5 w-3.5" />, value: CANDIDATE.email },
                  { icon: <Github className="h-3.5 w-3.5" />, value: CANDIDATE.github },
                  { icon: <Linkedin className="h-3.5 w-3.5" />, value: CANDIDATE.linkedin },
                  { icon: <Globe className="h-3.5 w-3.5" />, value: CANDIDATE.portfolio },
                ].map((item, i) => (
                  <div key={i} className="flex items-center gap-2 text-xs text-[var(--muted-foreground)]">
                    <span className="text-violet-400">{item.icon}</span>
                    <span className="truncate">{item.value}</span>
                    <ExternalLink className="ml-auto h-3 w-3 shrink-0 opacity-50" />
                  </div>
                ))}
              </div>

              {/* Stats */}
              <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-4">
                <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Platform Stats</h3>
                <div className="space-y-3">
                  {[
                    { label: "XP Earned",        value: "14.2K", icon: <Star className="h-3.5 w-3.5 text-amber-400" /> },
                    { label: "Problems Solved",   value: CANDIDATE.problemsSolved, icon: <Code2 className="h-3.5 w-3.5 text-blue-400" /> },
                    { label: "Study Hours",       value: `${CANDIDATE.hoursStudied}h`, icon: <TrendingUp className="h-3.5 w-3.5 text-violet-400" /> },
                    { label: "Day Streak",        value: `${CANDIDATE.streak}d`, icon: <Flame className="h-3.5 w-3.5 text-orange-400" /> },
                    { label: "Member Since",      value: CANDIDATE.joinedDate, icon: <Calendar className="h-3.5 w-3.5 text-emerald-400" /> },
                  ].map((s) => (
                    <div key={s.label} className="flex items-center justify-between">
                      <div className="flex items-center gap-2 text-xs text-[var(--muted-foreground)]">{s.icon}{s.label}</div>
                      <span className="text-xs font-bold text-[var(--foreground)]">{s.value}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Certifications */}
              <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-4">
                <h3 className="mb-3 text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Certifications</h3>
                <div className="space-y-2">
                  {CANDIDATE.certifications.map((cert, i) => (
                    <div key={i} className="flex items-start gap-2 rounded-xl bg-white/5 px-3 py-2">
                      <span className="text-base">{cert.icon}</span>
                      <div>
                        <p className="text-xs font-medium text-[var(--foreground)]">{cert.name}</p>
                        <p className="text-[10px] text-[var(--muted-foreground)]">{cert.date}</p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Right columns */}
            <div className="col-span-2 space-y-5">
              {/* Overall readiness */}
              <div className="rounded-2xl border border-emerald-500/20 bg-gradient-to-br from-emerald-500/10 to-teal-500/5 p-6">
                <div className="flex items-center gap-6">
                  <div className="text-center">
                    <p className="text-6xl font-black text-emerald-400">{CANDIDATE.overallScore}%</p>
                    <p className="text-xs text-[var(--muted-foreground)]">Role Readiness</p>
                  </div>
                  <div className="flex-1">
                    <p className="mb-1 text-sm font-bold text-[var(--foreground)]">Backend SDE — FAANG Level</p>
                    <p className="mb-3 text-xs text-[var(--muted-foreground)]">{CANDIDATE.bio}</p>
                    <div className="flex items-center gap-2">
                      <Target className="h-4 w-4 text-emerald-400" />
                      <span className="text-xs font-medium text-emerald-400">AI recommends proceeding to technical screen</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Skills */}
              <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
                <div className="mb-4 flex items-center justify-between">
                  <h3 className="flex items-center gap-2 text-sm font-semibold text-[var(--foreground)]">
                    <Brain className="h-4 w-4 text-violet-400" /> Skill Assessment
                  </h3>
                  <span className="flex items-center gap-1 text-xs text-emerald-400">
                    <CheckCircle2 className="h-3.5 w-3.5" /> Verified by DeepTutor
                  </span>
                </div>
                <div className="space-y-3">
                  {CANDIDATE.skills.map((s) => (
                    <SkillBar key={s.name} name={s.name} score={s.score} verified={s.verified} />
                  ))}
                </div>
              </div>

              {/* Roadmap */}
              <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
                <h3 className="mb-4 flex items-center gap-2 text-sm font-semibold text-[var(--foreground)]">
                  <Award className="h-4 w-4 text-amber-400" /> Learning Roadmap Progress
                </h3>
                <div className="flex items-center gap-0">
                  {CANDIDATE.roadmap.map((phase, i) => (
                    <div key={i} className="flex flex-1 flex-col items-center gap-1">
                      <div className={`flex h-6 w-6 items-center justify-center rounded-full text-[10px] font-bold ${
                        phase.done ? "bg-emerald-500 text-white" : "bg-white/10 text-[var(--muted-foreground)]"
                      }`}>
                        {phase.done ? "✓" : i + 1}
                      </div>
                      {i < CANDIDATE.roadmap.length - 1 && (
                        <div className={`absolute ml-6 h-0.5 flex-1 ${phase.done ? "bg-emerald-500" : "bg-white/10"}`} />
                      )}
                      <p className="text-center text-[9px] text-[var(--muted-foreground)] leading-tight">{phase.phase}</p>
                    </div>
                  ))}
                </div>
                <div className="mt-3 text-xs text-[var(--muted-foreground)]">
                  {CANDIDATE.roadmap.filter(p => p.done).length}/{CANDIDATE.roadmap.length} phases complete
                </div>
              </div>

              {/* Recent activity */}
              <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
                <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">Recent Learning Activity</h3>
                <div className="space-y-2">
                  {CANDIDATE.recentActivity.map((a, i) => {
                    const icon = { code: <Code2 className="h-3.5 w-3.5 text-blue-400" />, lesson: <BookOpen className="h-3.5 w-3.5 text-violet-400" />, test: <Target className="h-3.5 w-3.5 text-amber-400" />, review: <Brain className="h-3.5 w-3.5 text-emerald-400" /> }[a.type] ?? null;
                    return (
                      <div key={i} className="flex items-center gap-3 rounded-xl bg-white/5 px-3 py-2">
                        {icon}
                        <span className="flex-1 text-xs text-[var(--foreground)]">{a.label}</span>
                        <span className="text-[10px] text-[var(--muted-foreground)]">{a.date}</span>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

