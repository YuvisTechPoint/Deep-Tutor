"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  BookOpen,
  Check,
  ChevronRight,
  Clock,
  ExternalLink,
  Flag,
  Flame,
  Loader2,
  Lock,
  MapPin,
  Play,
  Sparkles,
  Star,
  Target,
  Trophy,
  Zap,
} from "lucide-react";

import {
  fetchGamificationState,
  fetchLearningPlan,
  type GamificationState,
  type LearningPlan,
  type RoadmapMilestone,
  type RoadmapPhase,
  type RoadmapResource,
  updateMilestoneStatus,
} from "@/lib/workspace-api";

/** Roadmap terracotta accent (replaces violet / amber / red family accents on this screen). */
const ROADMAP_ACCENT = {
  color: "from-[#D4734B]/18 to-[#5c3018]/12",
  accent: "border-[#D4734B]/50 text-[#D4734B]",
} as const;

const RESOURCE_ICONS: Record<RoadmapResource["type"], React.ReactNode> = {
  video: <Play className="h-3 w-3 text-[#D4734B]" />,
  article: <BookOpen className="h-3 w-3 text-[#D4734B]" />,
  exercise: <Zap className="h-3 w-3 text-[#D4734B]" />,
  project: <Flag className="h-3 w-3 text-emerald-400" />,
};

const PHASE_ACCENTS: Record<string, { color: string; accent: string }> = {
  foundations: ROADMAP_ACCENT,
  core_skills: ROADMAP_ACCENT,
  specialization: ROADMAP_ACCENT,
  career_ready: ROADMAP_ACCENT,
  statistics: ROADMAP_ACCENT,
  tooling: ROADMAP_ACCENT,
  modeling: ROADMAP_ACCENT,
  languages: ROADMAP_ACCENT,
  apis: ROADMAP_ACCENT,
  systems: ROADMAP_ACCENT,
};

const DEFAULT_ACCENT = ROADMAP_ACCENT;

export default function RoadmapPage() {
  const [plan, setPlan] = useState<LearningPlan | null>(null);
  const [state, setState] = useState<GamificationState | null>(null);
  const [expandedMilestone, setExpandedMilestone] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const [planResp, stateResp] = await Promise.all([
          fetchLearningPlan(),
          fetchGamificationState(),
        ]);
        if (cancelled) return;
        setPlan(planResp);
        setState(stateResp);
        const active = planResp.phases
          .flatMap((p) => p.milestones)
          .find((m) => m.status === "active");
        setExpandedMilestone(active?.id ?? null);
      } catch (e) {
        if (!cancelled) {
          setError(
            e instanceof Error ? e.message : "Failed to load roadmap",
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

  const stats = useMemo(() => {
    if (!plan) return [];
    return [
      {
        label: "XP Earned",
        value: plan.totals.xp_completed.toLocaleString(),
        icon: <Star className="h-4 w-4 text-[#D4734B]" />,
        color: "text-[#D4734B]",
      },
      {
        label: "Day Streak",
        value: state ? String(state.streak_current) : "—",
        icon: <Flame className="h-4 w-4 text-[#D4734B]" />,
        color: "text-[#D4734B]",
      },
      {
        label: "Milestones",
        value: `${plan.totals.milestones_completed} / ${plan.totals.milestones_total}`,
        icon: <Target className="h-4 w-4 text-[#D4734B]" />,
        color: "text-[#D4734B]",
      },
      {
        label: "Est. Complete",
        value: `${plan.phases
          .flatMap((p) => p.milestones)
          .filter((m) => m.status !== "completed")
          .reduce((s, m) => s + m.estimated_days, 0)} days`,
        icon: <Clock className="h-4 w-4 text-[#D4734B]" />,
        color: "text-[#D4734B]",
      },
    ];
  }, [plan, state]);

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center gap-2 text-[var(--muted-foreground)]">
        <Loader2 className="h-5 w-5 animate-spin" />
        <span>Loading learning plan…</span>
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

  if (!plan) return null;
  const progress = plan.totals.progress_pct;

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-5xl">
          <div className="mb-4 flex items-center gap-3">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-[#D4734B] to-[#b85a3a] shadow-lg shadow-[#D4734B]/30">
              <MapPin className="h-4 w-4 text-white" />
            </div>
            <div className="min-w-0 flex-1">
              <h1 className="truncate text-sm font-bold text-[var(--foreground)]">
                {plan.title}
              </h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">
                {plan.summary}
              </p>
            </div>
            {plan.is_preview && (
              <span className="flex items-center gap-1 rounded-full border border-[#D4734B]/30 bg-[#D4734B]/10 px-2 py-1 text-[10px] font-semibold text-[#f0b8a6]">
                <Sparkles className="h-3 w-3" /> Preview · complete onboarding to personalise
              </span>
            )}
            <div className="ml-auto flex items-center gap-2 rounded-lg bg-white/5 px-3 py-1.5">
              <div className="h-1.5 w-24 overflow-hidden rounded-full bg-white/10">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-[#D4734B] to-[#b85a3a] transition-all"
                  style={{ width: `${progress}%` }}
                />
              </div>
              <span className="text-xs font-semibold text-[#D4734B]">{progress}%</span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {stats.map((s) => (
              <div
                key={s.label}
                className="flex items-center gap-2 rounded-lg bg-white/5 px-3 py-2"
              >
                {s.icon}
                <div>
                  <p className={`text-sm font-bold ${s.color}`}>{s.value}</p>
                  <p className="text-[10px] text-[var(--muted-foreground)]">
                    {s.label}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto px-4 py-6 sm:px-6">
        <div className="mx-auto max-w-5xl space-y-6">
          {plan.phases.length === 0 && (
            <div className="rounded-2xl border border-white/5 bg-white/5 px-6 py-10 text-center">
              <p className="text-sm text-[var(--muted-foreground)]">
                No phases generated yet. Complete onboarding to seed a roadmap.
              </p>
            </div>
          )}
          {plan.phases.map((phase, idx) => (
            <PhaseCard
              key={phase.id}
              phase={phase}
              phaseNumber={idx + 1}
              expandedMilestone={expandedMilestone}
              onToggle={setExpandedMilestone}
              onMarkActive={async (milestoneId) => {
                try {
                  await updateMilestoneStatus(milestoneId, "active");
                  const fresh = await fetchLearningPlan();
                  setPlan(fresh);
                } catch (e) {
                  setError(e instanceof Error ? e.message : "Failed to update milestone");
                }
              }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

function PhaseCard({
  phase,
  phaseNumber,
  expandedMilestone,
  onToggle,
  onMarkActive,
}: {
  phase: RoadmapPhase;
  phaseNumber: number;
  expandedMilestone: string | null;
  onToggle: (id: string | null) => void;
  onMarkActive: (id: string) => void;
}) {
  const accents = PHASE_ACCENTS[phase.id] ?? DEFAULT_ACCENT;
  const doneCount = phase.milestones.filter((m) => m.status === "completed").length;
  return (
    <div
      className={`overflow-hidden rounded-2xl border border-white/5 bg-gradient-to-br ${accents.color} backdrop-blur-sm`}
    >
      <div className="flex items-center gap-4 px-6 py-4">
        <div
          className={`flex h-9 w-9 items-center justify-center rounded-xl border ${accents.accent} bg-black/20`}
        >
          <Trophy className="h-5 w-5" />
        </div>
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <span className="text-[10px] font-semibold uppercase tracking-widest text-[var(--muted-foreground)]">
              Phase {phaseNumber}
            </span>
            {phase.status === "completed" && (
              <span className="rounded-full bg-emerald-500/20 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">
                Completed
              </span>
            )}
            {phase.status === "active" && (
              <span className="rounded-full bg-[#D4734B]/20 px-2 py-0.5 text-[10px] font-semibold text-[#D4734B]">
                In Progress
              </span>
            )}
            {phase.status === "locked" && (
              <span className="flex items-center gap-1 rounded-full bg-white/5 px-2 py-0.5 text-[10px] font-semibold text-[var(--muted-foreground)]">
                <Lock className="h-2.5 w-2.5" />
                Locked
              </span>
            )}
          </div>
          <h3 className="font-bold text-[var(--foreground)]">{phase.title}</h3>
          <p className="text-xs text-[var(--muted-foreground)]">{phase.subtitle}</p>
        </div>
        <div className="text-right">
          <p className="text-lg font-bold text-[var(--foreground)]">
            {doneCount}/{phase.milestones.length}
          </p>
          <p className="text-[10px] text-[var(--muted-foreground)]">milestones</p>
        </div>
      </div>

      <div className="relative px-6 pb-6">
        <div className="absolute left-[34px] top-0 bottom-6 w-px bg-white/5" />
        <div className="space-y-3">
          {phase.milestones.map((milestone) => (
            <MilestoneRow
              key={milestone.id}
              milestone={milestone}
              isExpanded={expandedMilestone === milestone.id}
              onToggle={() =>
                onToggle(expandedMilestone === milestone.id ? null : milestone.id)
              }
              onContinue={() => onMarkActive(milestone.id)}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

function MilestoneRow({
  milestone,
  isExpanded,
  onToggle,
  onContinue,
}: {
  milestone: RoadmapMilestone;
  isExpanded: boolean;
  onToggle: () => void;
  onContinue: () => void;
}) {
  const isLocked = milestone.status === "locked";
  const isCompleted = milestone.status === "completed";
  const isActive = milestone.status === "active";

  const progressPct = isCompleted ? 100 : isActive ? 50 : 0;

  return (
    <div
      className={`ml-6 overflow-hidden rounded-xl border transition-all ${
        isActive
          ? "border-[#D4734B]/30 bg-[#D4734B]/10"
          : isCompleted
            ? "border-emerald-500/20 bg-emerald-500/5"
            : "border-white/5 bg-black/10"
      }`}
    >
      <button
        type="button"
        onClick={onToggle}
        disabled={isLocked}
        className="flex w-full items-center gap-3 px-4 py-3 text-left"
      >
        <div
          className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full ${
            isCompleted
              ? "bg-emerald-500 text-white"
              : isActive
                ? "border-2 border-[#D4734B] bg-[#D4734B]/20 text-[#D4734B]"
                : "border border-white/20 bg-white/5 text-[var(--muted-foreground)]"
          }`}
        >
          {isCompleted ? (
            <Check className="h-3.5 w-3.5" />
          ) : isLocked ? (
            <Lock className="h-3 w-3" />
          ) : (
            <ChevronRight
              className={`h-3.5 w-3.5 transition-transform ${isExpanded ? "rotate-90" : ""}`}
            />
          )}
        </div>
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <h4 className="truncate text-sm font-semibold text-[var(--foreground)]">
              {milestone.title}
            </h4>
            <span className="shrink-0 text-[10px] font-bold text-[#D4734B]">
              +{milestone.xp} XP
            </span>
          </div>
          <p className="truncate text-xs text-[var(--muted-foreground)]">
            {milestone.description}
          </p>
        </div>
        <div className="shrink-0 text-right">
          <p className="text-xs text-[var(--muted-foreground)]">
            ~{milestone.estimated_days}d
          </p>
          {(isActive || isCompleted) && (
            <div className="mt-1 h-1 w-16 overflow-hidden rounded-full bg-white/10">
              <div
                className={`h-full rounded-full transition-all ${
                  isCompleted ? "bg-emerald-400" : "bg-[#D4734B]"
                }`}
                style={{ width: `${progressPct}%` }}
              />
            </div>
          )}
        </div>
      </button>

      {isExpanded && (
        <div className="border-t border-white/5 px-4 pb-4 pt-3">
          <div className="mb-3 flex flex-wrap gap-1.5">
            {milestone.skills.map((s) => (
              <span
                key={s}
                className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] font-medium text-[var(--muted-foreground)]"
              >
                {s}
              </span>
            ))}
          </div>
          {milestone.model_roles.length > 0 && (
            <div className="mb-3 flex flex-wrap items-center gap-1.5 text-[10px] text-[var(--muted-foreground)]">
              <span className="uppercase tracking-widest">Tutor model roles</span>
              {milestone.model_roles.map((r) => (
                <span
                  key={r}
                  className="rounded-full border border-[#D4734B]/30 bg-[#D4734B]/10 px-2 py-0.5 text-[#f0b8a6]"
                >
                  {r}
                </span>
              ))}
            </div>
          )}
          <div className="space-y-1.5">
            <p className="text-[10px] font-semibold uppercase tracking-widest text-[var(--muted-foreground)]">
              Resources
            </p>
            {milestone.resources.map((r, i) => (
              <div
                key={i}
                className="flex items-center gap-2 rounded-lg bg-white/5 px-3 py-2"
              >
                {RESOURCE_ICONS[r.type]}
                <span className="flex-1 text-xs text-[var(--foreground)]">
                  {r.title}
                </span>
                <span className="text-[10px] text-[var(--muted-foreground)]">
                  {r.duration}
                </span>
                {r.url && <ExternalLink className="h-3 w-3 text-[var(--muted-foreground)]" />}
              </div>
            ))}
          </div>

          {!isLocked && (
            <div className="mt-3 flex flex-wrap gap-2">
              <Link
                href={`/chat?context=milestone:${encodeURIComponent(milestone.id)}`}
                className="flex flex-1 min-w-[180px] items-center justify-center gap-2 rounded-lg bg-[#D4734B] py-2 text-xs font-semibold text-white transition-colors hover:bg-[#c26244]"
                title="Open AI Tutor with this milestone pre-filled"
              >
                <Play className="h-3 w-3" />
                Ask AI Tutor
              </Link>
              <Link
                href={`/practice?milestone=${encodeURIComponent(milestone.id)}`}
                className="flex min-w-[110px] items-center justify-center gap-2 rounded-lg border border-amber-500/40 bg-amber-500/10 px-3 py-2 text-xs font-semibold text-amber-200 transition-colors hover:bg-amber-500/20"
                title="Practice questions tied to this milestone"
              >
                <Target className="h-3 w-3" />
                Practice
              </Link>
              <Link
                href={`/assessments?milestone=${encodeURIComponent(milestone.id)}`}
                className="flex min-w-[110px] items-center justify-center gap-2 rounded-lg border border-emerald-500/40 bg-emerald-500/10 px-3 py-2 text-xs font-semibold text-emerald-200 transition-colors hover:bg-emerald-500/20"
                title="Take a mastery assessment for this milestone"
              >
                <Sparkles className="h-3 w-3" />
                Assess
              </Link>
              {!isActive && (
                <button
                  type="button"
                  onClick={onContinue}
                  className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-xs font-medium text-[var(--muted-foreground)] hover:bg-white/10"
                >
                  Make active
                </button>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
