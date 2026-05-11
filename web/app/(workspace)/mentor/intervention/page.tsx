/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  AlertTriangle,
  Calendar,
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  Clock,
  Plus,
  Target,
  X,
} from "lucide-react";

type Priority = "high" | "medium" | "low";
type PlanStatus = "active" | "resolved" | "pending";

interface InterventionPlan {
  id: string;
  learner: string;
  initials: string;
  issue: string;
  actions: string[];
  deadline: string;
  priority: Priority;
  status: PlanStatus;
  createdAt: string;
  notes: string;
}

const PRIORITY_CONFIG: Record<Priority, { label: string; color: string }> = {
  high:   { label: "High",   color: "text-red-400 bg-red-500/10 border-red-500/30" },
  medium: { label: "Medium", color: "text-amber-400 bg-amber-500/10 border-amber-500/30" },
  low:    { label: "Low",    color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/30" },
};

const STATUS_CONFIG: Record<PlanStatus, { label: string; color: string }> = {
  active:   { label: "Active",   color: "text-violet-400 bg-violet-500/10 border-violet-500/30" },
  resolved: { label: "Resolved", color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/30" },
  pending:  { label: "Pending",  color: "text-amber-400 bg-amber-500/10 border-amber-500/30" },
};

const PLANS: InterventionPlan[] = [
  {
    id: "p1", learner: "David Okafor", initials: "DO",
    issue: "React Hooks: Not completing exercises, 0-day streak, score dropped from 68% to 44%",
    actions: ["Schedule 1:1 session this week", "Assign 3 beginner React exercises", "Enable daily reminder notifications", "Review using AI Tutor together"],
    deadline: "May 18, 2026", priority: "high", status: "active", createdAt: "May 10, 2026",
    notes: "David mentioned he's been dealing with a family matter. Suggested async learning pace.",
  },
  {
    id: "p2", learner: "Mei Lin", initials: "ML",
    issue: "Probability & Statistics: 5-day absence, final exam in 3 weeks, score at 38%",
    actions: ["Share probability fundamentals resource pack", "Create 10-question adaptive quiz", "Set up AI Tutor session on Bayes theorem", "Daily check-in messages"],
    deadline: "May 25, 2026", priority: "high", status: "active", createdAt: "May 9, 2026",
    notes: "Mei is strong in other areas. This specific topic needs focused attention.",
  },
  {
    id: "p3", learner: "Priya Sharma", initials: "PS",
    issue: "ML Fundamentals: Progress stalled at 41%, PyTorch knowledge gap identified",
    actions: ["Recommend fast.ai practical course", "Pair with peer mentor for PyTorch exercises", "Weekly AI Tutor coding sessions"],
    deadline: "Jun 1, 2026", priority: "medium", status: "active", createdAt: "May 8, 2026",
    notes: "Strong theoretical background. Needs more hands-on coding practice.",
  },
  {
    id: "p4", learner: "Raj Patel", initials: "RP",
    issue: "Sorting algorithms: Confusion with merge sort implementation (previously resolved)",
    actions: ["Completed all exercises", "Score improved from 52% to 67%"],
    deadline: "May 5, 2026", priority: "low", status: "resolved", createdAt: "Apr 28, 2026",
    notes: "Successfully resolved. Raj is now on track.",
  },
];

const LEARNER_OPTIONS = ["David Okafor", "Mei Lin", "Priya Sharma", "Raj Patel", "Aisha Raza", "Marcus Chen", "Sara Kim", "Ahmed Hassan"];
const ACTION_SUGGESTIONS = [
  "Schedule 1:1 session this week",
  "Assign targeted practice exercises",
  "Enable daily reminder notifications",
  "Recommend supplementary resources",
  "Create adaptive quiz on weak topic",
  "Pair with peer mentor",
  "Set up AI Tutor coding session",
  "Adjust roadmap timeline",
];

export default function InterventionPage() {
  const [plans, setPlans] = useState<InterventionPlan[]>(PLANS);
  const [expanded, setExpanded] = useState<string | null>("p1");
  const [showForm, setShowForm] = useState(false);
  const [selectedActions, setSelectedActions] = useState<string[]>([]);
  const [newLearner, setNewLearner] = useState("");
  const [newIssue, setNewIssue] = useState("");
  const [newDeadline, setNewDeadline] = useState("");
  const [newPriority, setNewPriority] = useState<Priority>("medium");
  const [newNotes, setNewNotes] = useState("");

  const toggleAction = (a: string) =>
    setSelectedActions((prev) => prev.includes(a) ? prev.filter((x) => x !== a) : [...prev, a]);

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    const initials = newLearner.split(" ").map(w => w[0]).join("").slice(0, 2);
    const newPlan: InterventionPlan = {
      id: `p${plans.length + 1}`, learner: newLearner, initials,
      issue: newIssue, actions: selectedActions,
      deadline: newDeadline, priority: newPriority, status: "pending",
      createdAt: new Date().toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" }),
      notes: newNotes,
    };
    setPlans((prev) => [newPlan, ...prev]);
    setShowForm(false);
    setNewLearner(""); setNewIssue(""); setSelectedActions([]); setNewDeadline(""); setNewNotes("");
  };

  const activePlans = plans.filter((p) => p.status !== "resolved");
  const resolvedPlans = plans.filter((p) => p.status === "resolved");

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-4xl flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-orange-500 to-red-600 shadow-lg">
              <AlertTriangle className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">Intervention Plans</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">{activePlans.length} active · {resolvedPlans.length} resolved</p>
            </div>
          </div>
          <button
            onClick={() => setShowForm(!showForm)}
            className="flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2 text-sm font-semibold text-white hover:bg-violet-500 transition-colors"
          >
            <Plus className="h-4 w-4" /> Create Plan
          </button>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-4xl space-y-5 px-4 py-6 sm:px-6">
          {/* Create form */}
          {showForm && (
            <div className="rounded-2xl border border-violet-500/20 bg-violet-500/5 p-6">
              <div className="mb-4 flex items-center justify-between">
                <h2 className="font-bold text-[var(--foreground)]">New Intervention Plan</h2>
                <button onClick={() => setShowForm(false)} className="text-[var(--muted-foreground)] hover:text-[var(--foreground)]">
                  <X className="h-5 w-5" />
                </button>
              </div>
              <form onSubmit={handleCreate} className="space-y-4">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="mb-1 block text-xs font-semibold text-[var(--muted-foreground)]">Learner</label>
                    <select value={newLearner} onChange={(e) => setNewLearner(e.target.value)}
                      className="w-full rounded-xl border border-white/5 bg-[var(--background)] px-3 py-2.5 text-sm text-[var(--foreground)] outline-none">
                      <option value="">Select learner</option>
                      {LEARNER_OPTIONS.map((l) => <option key={l} value={l} className="bg-black">{l}</option>)}
                    </select>
                  </div>
                  <div>
                    <label className="mb-1 block text-xs font-semibold text-[var(--muted-foreground)]">Priority</label>
                    <select value={newPriority} onChange={(e) => setNewPriority(e.target.value as Priority)}
                      className="w-full rounded-xl border border-white/5 bg-[var(--background)] px-3 py-2.5 text-sm text-[var(--foreground)] outline-none">
                      <option value="high" className="bg-black">High</option>
                      <option value="medium" className="bg-black">Medium</option>
                      <option value="low" className="bg-black">Low</option>
                    </select>
                  </div>
                </div>
                <div>
                  <label className="mb-1 block text-xs font-semibold text-[var(--muted-foreground)]">Identified Gap / Issue</label>
                  <textarea value={newIssue} onChange={(e) => setNewIssue(e.target.value)} rows={2}
                    placeholder="Describe the learning gap or issue..."
                    className="w-full resize-none rounded-xl border border-white/5 bg-[var(--background)] px-4 py-2.5 text-sm text-[var(--foreground)] outline-none placeholder:text-[var(--muted-foreground)]" />
                </div>
                <div>
                  <label className="mb-2 block text-xs font-semibold text-[var(--muted-foreground)]">Recommended Actions</label>
                  <div className="flex flex-wrap gap-2">
                    {ACTION_SUGGESTIONS.map((a) => (
                      <button type="button" key={a} onClick={() => toggleAction(a)}
                        className={`rounded-full border px-3 py-1.5 text-xs font-medium transition-colors ${
                          selectedActions.includes(a)
                            ? "border-violet-500/50 bg-violet-500/15 text-violet-200"
                            : "border-white/10 bg-white/5 text-[var(--muted-foreground)] hover:border-white/20"
                        }`}>
                        {a}
                      </button>
                    ))}
                  </div>
                </div>
                <div>
                  <label className="mb-1 block text-xs font-semibold text-[var(--muted-foreground)]">Deadline</label>
                  <input type="date" value={newDeadline} onChange={(e) => setNewDeadline(e.target.value)}
                    className="rounded-xl border border-white/5 bg-[var(--background)] px-4 py-2.5 text-sm text-[var(--foreground)] outline-none" />
                </div>
                <div>
                  <label className="mb-1 block text-xs font-semibold text-[var(--muted-foreground)]">Notes</label>
                  <textarea value={newNotes} onChange={(e) => setNewNotes(e.target.value)} rows={2}
                    placeholder="Context, personal notes, background..."
                    className="w-full resize-none rounded-xl border border-white/5 bg-[var(--background)] px-4 py-2.5 text-sm text-[var(--foreground)] outline-none placeholder:text-[var(--muted-foreground)]" />
                </div>
                <div className="flex gap-3">
                  <button type="button" onClick={() => setShowForm(false)}
                    className="flex-1 rounded-xl border border-white/5 bg-white/5 py-2.5 text-sm font-medium text-[var(--muted-foreground)] hover:bg-white/10">Cancel</button>
                  <button type="submit"
                    className="flex-1 rounded-xl bg-violet-600 py-2.5 text-sm font-semibold text-white hover:bg-violet-500">
                    Create Plan
                  </button>
                </div>
              </form>
            </div>
          )}

          {/* Active plans */}
          <div className="space-y-3">
            <h2 className="text-sm font-semibold text-[var(--foreground)]">Active Plans ({activePlans.length})</h2>
            {activePlans.map((plan) => {
              const pc = PRIORITY_CONFIG[plan.priority];
              const sc = STATUS_CONFIG[plan.status];
              const isOpen = expanded === plan.id;
              return (
                <div key={plan.id} className="overflow-hidden rounded-2xl border border-white/5 bg-[var(--secondary)]">
                  <button
                    onClick={() => setExpanded(isOpen ? null : plan.id)}
                    className="flex w-full items-center gap-4 px-5 py-4 text-left"
                  >
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-indigo-600 text-sm font-bold text-white">
                      {plan.initials}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="mb-1 flex flex-wrap items-center gap-2">
                        <span className="font-bold text-[var(--foreground)]">{plan.learner}</span>
                        <span className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${pc.color}`}>{pc.label}</span>
                        <span className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${sc.color}`}>{sc.label}</span>
                      </div>
                      <p className="truncate text-xs text-[var(--muted-foreground)]">{plan.issue.split(":")[0]}</p>
                    </div>
                    <div className="shrink-0 flex items-center gap-2 text-xs text-[var(--muted-foreground)]">
                      <Calendar className="h-3.5 w-3.5" />
                      {plan.deadline}
                      {isOpen ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
                    </div>
                  </button>
                  {isOpen && (
                    <div className="border-t border-white/5 px-5 pb-5 pt-4 space-y-4">
                      <div>
                        <p className="mb-1 text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Issue</p>
                        <p className="text-sm text-[var(--foreground)]">{plan.issue}</p>
                      </div>
                      <div>
                        <p className="mb-2 text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Action Plan</p>
                        <div className="space-y-1.5">
                          {plan.actions.map((a, i) => (
                            <div key={i} className="flex items-center gap-2 text-sm text-[var(--muted-foreground)]">
                              <Target className="h-3.5 w-3.5 shrink-0 text-violet-400" />
                              {a}
                            </div>
                          ))}
                        </div>
                      </div>
                      {plan.notes && (
                        <div>
                          <p className="mb-1 text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Notes</p>
                          <p className="text-sm italic text-[var(--muted-foreground)]">{plan.notes}</p>
                        </div>
                      )}
                      <div className="flex gap-2 pt-2">
                        <button
                          onClick={() => setPlans(prev => prev.map(p => p.id === plan.id ? { ...p, status: "resolved" } : p))}
                          className="flex items-center gap-1.5 rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-500 transition-colors"
                        >
                          <CheckCircle2 className="h-3.5 w-3.5" /> Mark Resolved
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>

          {/* Resolved */}
          {resolvedPlans.length > 0 && (
            <div className="space-y-3">
              <h2 className="text-sm font-semibold text-[var(--foreground)]">Resolved ({resolvedPlans.length})</h2>
              {resolvedPlans.map((plan) => (
                <div key={plan.id} className="rounded-xl border border-emerald-500/10 bg-emerald-500/3 px-5 py-3 opacity-70">
                  <div className="flex items-center gap-3">
                    <CheckCircle2 className="h-5 w-5 text-emerald-400" />
                    <span className="font-medium text-[var(--foreground)]">{plan.learner}</span>
                    <span className="flex-1 text-xs text-[var(--muted-foreground)] truncate">{plan.issue.split(":")[0]}</span>
                    <span className="flex items-center gap-1 text-xs text-emerald-400">
                      <Clock className="h-3 w-3" /> Resolved {plan.deadline}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
