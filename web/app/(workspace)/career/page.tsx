"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import {
  ArrowRight,
  Briefcase,
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  ExternalLink,
  Loader2,
  MapPin,
  Sparkles,
  Star,
  Target,
  TrendingUp,
  XCircle,
  Zap,
} from "lucide-react";

import {
  fetchCareerPaths,
  type CareerPath,
  type CareerSkill,
  type CareerSkillLevel,
} from "@/lib/workspace-api";

const LEVEL_ORDER: Record<CareerSkillLevel, number> = {
  none: 0,
  beginner: 1,
  intermediate: 2,
  advanced: 3,
};

const LEVEL_COLOR: Record<CareerSkillLevel, string> = {
  none: "bg-red-500/20 text-red-400",
  beginner: "bg-amber-500/20 text-amber-400",
  intermediate: "bg-blue-500/20 text-blue-400",
  advanced: "bg-emerald-500/20 text-emerald-400",
};

function readinessColor(r: number): string {
  if (r >= 75) return "text-emerald-400 border-emerald-500/30 bg-emerald-500/10";
  if (r >= 50) return "text-amber-400 border-amber-500/30 bg-amber-500/10";
  return "text-red-400 border-red-500/30 bg-red-500/10";
}

function gapColor(skill: CareerSkill): string {
  const gap = LEVEL_ORDER[skill.required] - LEVEL_ORDER[skill.current];
  if (gap <= 0) return "text-emerald-400";
  if (gap === 1) return "text-amber-400";
  return "text-red-400";
}

export default function CareerPage() {
  const [paths, setPaths] = useState<CareerPath[]>([]);
  const [selected, setSelected] = useState<CareerPath | null>(null);
  const [expandedSection, setExpandedSection] = useState<string | null>("skills");
  const [preview, setPreview] = useState(false);
  const [rationale, setRationale] = useState<string>("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const resp = await fetchCareerPaths();
        if (cancelled) return;
        setPaths(resp.paths);
        setSelected(resp.paths[0] ?? null);
        setPreview(resp.preview);
        setRationale(resp.rationale);
      } catch (e) {
        if (!cancelled) {
          setError(
            e instanceof Error ? e.message : "Failed to load career paths",
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
        <span>Loading career paths…</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex h-screen items-center justify-center px-6">
        <div className="max-w-md rounded-2xl border border-red-500/30 bg-red-500/10 px-6 py-4 text-sm text-red-200">
          {error}
        </div>
      </div>
    );
  }

  if (!selected) {
    return (
      <div className="flex h-screen items-center justify-center px-6 text-sm text-[var(--muted-foreground)]">
        No career paths configured yet.
      </div>
    );
  }

  const gapSkills = selected.skills.filter(
    (s) => LEVEL_ORDER[s.current] < LEVEL_ORDER[s.required],
  );

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-5xl flex items-center gap-3">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-pink-500 to-rose-600 shadow-lg">
            <Briefcase className="h-4 w-4 text-white" />
          </div>
          <div>
            <h1 className="text-sm font-bold text-[var(--foreground)]">
              Career Intelligence
            </h1>
            <p className="text-[11px] text-[var(--muted-foreground)]">
              Skill gap · Readiness score · Roadmap
            </p>
          </div>
          {preview && (
            <span className="ml-auto flex items-center gap-1 rounded-full border border-amber-500/30 bg-amber-500/10 px-2 py-1 text-[10px] font-semibold text-amber-300">
              <Sparkles className="h-3 w-3" /> Preview
            </span>
          )}
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-5xl px-4 py-6 sm:px-6">
          {preview && rationale && (
            <p className="mb-4 text-xs text-[var(--muted-foreground)]">{rationale}</p>
          )}

          <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
            {paths.map((path) => {
              const rc = readinessColor(path.readiness);
              const isSelected = selected.id === path.id;
              return (
                <button
                  key={path.id}
                  type="button"
                  onClick={() => setSelected(path)}
                  className={`rounded-2xl border p-5 text-left transition-all ${
                    isSelected
                      ? "border-violet-500/50 bg-violet-500/10 ring-1 ring-violet-500/20"
                      : "border-white/5 bg-[var(--secondary)] hover:border-white/10"
                  }`}
                >
                  <div className="mb-2 flex items-center justify-between">
                    <h3 className="font-bold text-[var(--foreground)]">{path.title}</h3>
                    <span className={`rounded-full border px-2 py-0.5 text-sm font-black ${rc}`}>
                      {path.readiness}%
                    </span>
                  </div>
                  <p className="mb-3 text-xs text-[var(--muted-foreground)] line-clamp-2">
                    {path.description}
                  </p>
                  <div className="flex items-center gap-2 text-xs">
                    <span className="font-semibold text-emerald-400">{path.avg_salary}</span>
                    <span className="text-[var(--muted-foreground)]">·</span>
                    <span
                      className={`capitalize font-medium ${
                        path.demand === "high"
                          ? "text-emerald-400"
                          : path.demand === "medium"
                            ? "text-amber-400"
                            : "text-red-400"
                      }`}
                    >
                      {path.demand} demand
                    </span>
                  </div>
                  <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-white/10">
                    <div
                      className={`h-full rounded-full transition-all ${
                        path.readiness >= 75
                          ? "bg-emerald-400"
                          : path.readiness >= 50
                            ? "bg-amber-400"
                            : "bg-red-400"
                      }`}
                      style={{ width: `${path.readiness}%` }}
                    />
                  </div>
                  <div className="mt-3 flex flex-wrap gap-1">
                    {path.model_roles.map((r) => (
                      <span
                        key={r}
                        className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] text-[var(--muted-foreground)]"
                      >
                        {r}
                      </span>
                    ))}
                  </div>
                </button>
              );
            })}
          </div>

          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              {[
                {
                  label: "Readiness",
                  value: `${selected.readiness}%`,
                  icon: <Target className="h-4 w-4 text-violet-400" />,
                  color: "text-violet-400",
                },
                {
                  label: "Est. Timeline",
                  value: selected.timeline,
                  icon: <MapPin className="h-4 w-4 text-blue-400" />,
                  color: "text-blue-400",
                },
                {
                  label: "Skills to gain",
                  value: String(gapSkills.length),
                  icon: <TrendingUp className="h-4 w-4 text-amber-400" />,
                  color: "text-amber-400",
                },
                {
                  label: "Avg Salary",
                  value: selected.avg_salary.split("–")[0] + "+",
                  icon: <Star className="h-4 w-4 text-emerald-400" />,
                  color: "text-emerald-400",
                },
              ].map((stat) => (
                <div
                  key={stat.label}
                  className="rounded-xl border border-white/5 bg-[var(--secondary)] p-4"
                >
                  <div className="mb-1">{stat.icon}</div>
                  <p className={`text-lg font-bold ${stat.color}`}>{stat.value}</p>
                  <p className="text-[10px] text-[var(--muted-foreground)]">{stat.label}</p>
                </div>
              ))}
            </div>

            <CollapsibleSection
              title="Skill Gap Analysis"
              id="skills"
              expanded={expandedSection === "skills"}
              onToggle={(id) => setExpandedSection(expandedSection === id ? null : id)}
            >
              <div className="space-y-2.5">
                {selected.skills
                  .slice()
                  .sort((a, b) => b.weight - a.weight)
                  .map((skill) => {
                    const gap = LEVEL_ORDER[skill.required] - LEVEL_ORDER[skill.current];
                    const isOk = gap <= 0;
                    return (
                      <div
                        key={skill.name}
                        className={`flex items-center gap-3 rounded-xl border px-4 py-3 ${
                          isOk
                            ? "border-emerald-500/15 bg-emerald-500/5"
                            : "border-red-500/15 bg-red-500/5"
                        }`}
                      >
                        {isOk ? (
                          <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-400" />
                        ) : (
                          <XCircle className="h-4 w-4 shrink-0 text-red-400" />
                        )}
                        <div className="flex-1">
                          <div className="flex items-center gap-2">
                            <span className="text-sm font-medium text-[var(--foreground)]">
                              {skill.name}
                            </span>
                            <span className="text-[10px] font-semibold text-[var(--muted-foreground)]">
                              importance: {skill.weight}/10
                            </span>
                          </div>
                          <div className="mt-1 flex items-center gap-1.5 text-[11px]">
                            <span
                              className={`rounded px-1.5 py-0.5 capitalize ${LEVEL_COLOR[skill.current]}`}
                            >
                              {skill.current === "none" ? "Not started" : skill.current}
                            </span>
                            <ArrowRight className="h-3 w-3 text-[var(--muted-foreground)]" />
                            <span
                              className={`rounded px-1.5 py-0.5 capitalize ${LEVEL_COLOR[skill.required]}`}
                            >
                              {skill.required} needed
                            </span>
                          </div>
                        </div>
                        <div className={`text-xs font-bold ${gapColor(skill)}`}>
                          {gap <= 0 ? "Ready" : `+${gap} level${gap > 1 ? "s" : ""}`}
                        </div>
                      </div>
                    );
                  })}
              </div>
            </CollapsibleSection>

            <CollapsibleSection
              title="Recommended Portfolio Projects"
              id="projects"
              expanded={expandedSection === "projects"}
              onToggle={(id) => setExpandedSection(expandedSection === id ? null : id)}
            >
              <div className="space-y-2.5">
                {selected.projects.map((project, i) => (
                  <div
                    key={i}
                    className="flex items-center gap-3 rounded-xl border border-white/5 bg-[var(--secondary)] px-4 py-3"
                  >
                    <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-violet-500/20 text-[11px] font-bold text-violet-400">
                      {i + 1}
                    </div>
                    <span className="flex-1 text-sm text-[var(--foreground)]">{project}</span>
                    <ExternalLink className="h-3.5 w-3.5 shrink-0 text-[var(--muted-foreground)]" />
                  </div>
                ))}
              </div>
              <Link
                href="/co-writer"
                className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-violet-600 py-2.5 text-xs font-semibold text-white hover:bg-violet-500 transition-colors"
              >
                <Zap className="h-3.5 w-3.5" />
                Open Co-Writer to draft a project plan
              </Link>
            </CollapsibleSection>

            <CollapsibleSection
              title="Target Companies & Tutor Setup"
              id="companies"
              expanded={expandedSection === "companies"}
              onToggle={(id) => setExpandedSection(expandedSection === id ? null : id)}
            >
              <div className="flex flex-wrap gap-2">
                {selected.company_types.map((c) => (
                  <span
                    key={c}
                    className="rounded-full border border-violet-500/30 bg-violet-500/10 px-3 py-1 text-xs font-medium text-violet-300"
                  >
                    {c}
                  </span>
                ))}
              </div>
              <div className="mt-4 rounded-xl bg-white/5 p-4">
                <p className="text-sm text-[var(--muted-foreground)]">
                  This track currently routes to{" "}
                  {selected.model_roles.map((r) => (
                    <span
                      key={r}
                      className="ml-1 rounded-full border border-violet-500/30 bg-violet-500/10 px-2 py-0.5 text-[10px] text-violet-300"
                    >
                      {r}
                    </span>
                  ))}
                  {" "}via the model router. Run a mock interview from the chat workspace to
                  exercise the matching open-source models.
                </p>
                <Link
                  href="/chat"
                  className="mt-3 inline-flex items-center gap-2 rounded-lg bg-violet-600 px-4 py-2 text-xs font-semibold text-white hover:bg-violet-500"
                >
                  Start mock interview <ArrowRight className="h-3.5 w-3.5" />
                </Link>
              </div>
            </CollapsibleSection>
          </div>
        </div>
      </div>
    </div>
  );
}

function CollapsibleSection({
  title,
  id,
  expanded,
  onToggle,
  children,
}: {
  title: string;
  id: string;
  expanded: boolean;
  onToggle: (id: string) => void;
  children: React.ReactNode;
}) {
  return (
    <div className="overflow-hidden rounded-2xl border border-white/5 bg-[var(--secondary)]">
      <button
        type="button"
        onClick={() => onToggle(id)}
        className="flex w-full items-center justify-between px-6 py-4 text-left"
      >
        <span className="text-sm font-semibold text-[var(--foreground)]">{title}</span>
        {expanded ? (
          <ChevronUp className="h-4 w-4 text-[var(--muted-foreground)]" />
        ) : (
          <ChevronDown className="h-4 w-4 text-[var(--muted-foreground)]" />
        )}
      </button>
      {expanded && <div className="px-6 pb-6">{children}</div>}
    </div>
  );
}
