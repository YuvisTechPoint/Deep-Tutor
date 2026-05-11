/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  AlertCircle,
  CheckCircle2,
  Filter,
  Flag,
  MessageSquare,
  Shield,
  ShieldOff,
  TrendingDown,
  X,
} from "lucide-react";

type RiskLevel = "high" | "medium" | "low";
type ModAction = "pending" | "approved" | "blocked" | "flagged";

interface FlaggedItem {
  id: string;
  user: string;
  preview: string;
  timestamp: string;
  model: string;
  safetyScore: number;
  riskLevel: RiskLevel;
  flagReason: string;
  action: ModAction;
}

const RISK_CONFIG: Record<RiskLevel, { label: string; color: string }> = {
  high:   { label: "High Risk",   color: "text-red-400 bg-red-500/10 border-red-500/30" },
  medium: { label: "Medium Risk", color: "text-amber-400 bg-amber-500/10 border-amber-500/30" },
  low:    { label: "Low Risk",    color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/30" },
};

const ACTION_CONFIG: Record<ModAction, { label: string; color: string }> = {
  pending:  { label: "Pending",  color: "text-amber-400 bg-amber-500/10 border-amber-500/30" },
  approved: { label: "Approved", color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/30" },
  blocked:  { label: "Blocked",  color: "text-red-400 bg-red-500/10 border-red-500/30" },
  flagged:  { label: "Flagged",  color: "text-orange-400 bg-orange-500/10 border-orange-500/30" },
};

const INITIAL_ITEMS: FlaggedItem[] = [
  { id: "m1", user: "anon_user_84", preview: "How do I hack into a system and steal passwords without...", timestamp: "14:32", model: "Qwen3-32B", safetyScore: 12, riskLevel: "high",   flagReason: "Malicious intent / hacking", action: "pending" },
  { id: "m2", user: "john.doe@email.com", preview: "Can you write me a phishing email that looks like it's from PayPal...", timestamp: "14:18", model: "DeepSeek-Coder", safetyScore: 8,  riskLevel: "high",   flagReason: "Phishing / social engineering", action: "blocked" },
  { id: "m3", user: "student_456", preview: "What are some methods to cheat on an online exam without...", timestamp: "13:55", model: "Qwen3-32B", safetyScore: 31, riskLevel: "medium", flagReason: "Academic dishonesty", action: "pending" },
  { id: "m4", user: "user_789", preview: "Explain how drugs are synthesized, specifically methamphetamine...", timestamp: "13:40", model: "Qwen3-32B", safetyScore: 5,  riskLevel: "high",   flagReason: "Illegal substance instructions", action: "blocked" },
  { id: "m5", user: "learner_321", preview: "I want to understand the psychology of manipulation and how...", timestamp: "13:12", model: "Qwen3-32B", safetyScore: 48, riskLevel: "medium", flagReason: "Potentially manipulative content", action: "approved" },
  { id: "m6", user: "dev_user", preview: "Write a SQL injection payload that bypasses login authentication...", timestamp: "12:58", model: "DeepSeek-Coder", safetyScore: 22, riskLevel: "high", flagReason: "Security exploit code", action: "blocked" },
  { id: "m7", user: "student_112", preview: "How do I bypass the content filter to get the AI to tell me...", timestamp: "12:33", model: "Qwen3-32B", safetyScore: 35, riskLevel: "medium", flagReason: "Prompt injection attempt", action: "pending" },
  { id: "m8", user: "curious_user", preview: "What's the history of chemical weapons and how were they made...", timestamp: "11:47", model: "Qwen3-32B", safetyScore: 41, riskLevel: "low",    flagReason: "Sensitive historical content (borderline)", action: "approved" },
];

export default function ContentModerationPage() {
  const [items, setItems] = useState<FlaggedItem[]>(INITIAL_ITEMS);
  const [riskFilter, setRiskFilter] = useState<RiskLevel | "all">("all");
  const [actionFilter, setActionFilter] = useState<ModAction | "all">("all");
  const [threshold, setThreshold] = useState(75);

  const updateAction = (id: string, action: ModAction) =>
    setItems((prev) => prev.map((item) => item.id === id ? { ...item, action } : item));

  const filtered = items.filter((item) => {
    const matchRisk = riskFilter === "all" || item.riskLevel === riskFilter;
    const matchAction = actionFilter === "all" || item.action === actionFilter;
    return matchRisk && matchAction;
  });

  const stats = {
    flaggedToday: items.length,
    autoBlocked: items.filter(i => i.safetyScore <= 20).length,
    underReview: items.filter(i => i.action === "pending").length,
    falsePositives: items.filter(i => i.action === "approved" && i.riskLevel !== "low").length,
  };

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-6xl flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-red-500 to-rose-600 shadow-lg">
            <Shield className="h-5 w-5 text-white" />
          </div>
          <div>
            <h1 className="text-sm font-bold text-[var(--foreground)]">Content Moderation</h1>
            <p className="text-[11px] text-[var(--muted-foreground)]">Powered by Llama Guard 3 · Real-time safety screening</p>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-6xl space-y-5 px-4 py-5 sm:px-6">
          {/* Stats */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              { label: "Flagged Today",  value: stats.flaggedToday,  icon: <Flag className="h-5 w-5" />,         color: "text-amber-400" },
              { label: "Auto-blocked",   value: stats.autoBlocked,   icon: <ShieldOff className="h-5 w-5" />,    color: "text-red-400" },
              { label: "Under Review",   value: stats.underReview,   icon: <AlertCircle className="h-5 w-5" />,  color: "text-orange-400" },
              { label: "False Positives",value: stats.falsePositives, icon: <CheckCircle2 className="h-5 w-5" />, color: "text-emerald-400" },
            ].map((s) => (
              <div key={s.label} className="rounded-xl border border-white/5 bg-[var(--secondary)] p-4">
                <div className={`mb-1 ${s.color}`}>{s.icon}</div>
                <p className={`text-2xl font-black ${s.color}`}>{s.value}</p>
                <p className="text-[10px] text-[var(--muted-foreground)]">{s.label}</p>
              </div>
            ))}
          </div>

          {/* Safety threshold */}
          <div className="rounded-xl border border-white/5 bg-[var(--secondary)] p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-[var(--foreground)]">Auto-block threshold: {threshold}% safety score</span>
              <span className="text-xs text-[var(--muted-foreground)]">Below this → auto-blocked</span>
            </div>
            <input type="range" min={10} max={90} value={threshold} onChange={(e) => setThreshold(Number(e.target.value))}
              className="w-full accent-red-500" />
            <div className="mt-1 flex justify-between text-[10px] text-[var(--muted-foreground)]">
              <span>Permissive (10%)</span><span>Strict (90%)</span>
            </div>
          </div>

          {/* Filters */}
          <div className="flex flex-wrap gap-2">
            <div className="flex items-center gap-1.5 text-[var(--muted-foreground)]">
              <Filter className="h-4 w-4" />
            </div>
            {(["all", "high", "medium", "low"] as const).map((r) => (
              <button key={r} onClick={() => setRiskFilter(r)}
                className={`rounded-lg px-3 py-1.5 text-xs font-semibold capitalize transition-colors ${
                  riskFilter === r ? "bg-red-600 text-white" : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
                }`}>
                {r === "all" ? "All Risk" : `${r} Risk`}
              </button>
            ))}
            <div className="ml-2">
              {(["all", "pending", "approved", "blocked"] as const).map((a) => (
                <button key={a} onClick={() => setActionFilter(a)}
                  className={`mr-1 rounded-lg px-3 py-1.5 text-xs font-semibold capitalize transition-colors ${
                    actionFilter === a ? "bg-violet-600 text-white" : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
                  }`}>
                  {a === "all" ? "All Actions" : a}
                </button>
              ))}
            </div>
          </div>

          {/* Queue */}
          <div className="space-y-3">
            {filtered.map((item) => {
              const rc = RISK_CONFIG[item.riskLevel];
              const ac = ACTION_CONFIG[item.action];
              const autoBlocked = item.safetyScore <= threshold;
              return (
                <div key={item.id} className={`rounded-2xl border bg-[var(--secondary)] p-5 ${autoBlocked && item.action === "pending" ? "border-red-500/20" : "border-white/5"}`}>
                  <div className="flex items-start gap-4">
                    <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-red-500/10">
                      <MessageSquare className="h-4 w-4 text-red-400" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="mb-2 flex flex-wrap items-center gap-2">
                        <span className="text-xs font-semibold text-[var(--foreground)]">{item.user}</span>
                        <span className="text-xs text-[var(--muted-foreground)]">{item.timestamp}</span>
                        <span className="font-mono text-[10px] text-violet-400">{item.model}</span>
                        <span className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${rc.color}`}>{rc.label}</span>
                        <span className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${ac.color}`}>{ac.label}</span>
                        {autoBlocked && item.action === "pending" && (
                          <span className="rounded-full bg-red-500/10 px-2 py-0.5 text-[10px] font-bold text-red-400">Auto-block candidate</span>
                        )}
                      </div>
                      <p className="mb-2 text-sm text-[var(--foreground)] line-clamp-2">{item.preview}</p>
                      <div className="mb-3 flex items-center gap-3">
                        <span className="text-xs text-[var(--muted-foreground)]">
                          Safety score: <span className={`font-bold ${item.safetyScore <= 25 ? "text-red-400" : item.safetyScore <= 50 ? "text-amber-400" : "text-emerald-400"}`}>
                            {item.safetyScore}%
                          </span>
                        </span>
                        <div className="flex-1 h-1.5 max-w-32 overflow-hidden rounded-full bg-white/10">
                          <div className={`h-full rounded-full ${item.safetyScore <= 25 ? "bg-red-400" : item.safetyScore <= 50 ? "bg-amber-400" : "bg-emerald-400"}`}
                            style={{ width: `${item.safetyScore}%` }} />
                        </div>
                        <span className="text-xs text-[var(--muted-foreground)]">Reason: {item.flagReason}</span>
                      </div>

                      {/* Action buttons */}
                      {item.action === "pending" && (
                        <div className="flex gap-2">
                          <button onClick={() => updateAction(item.id, "approved")}
                            className="flex items-center gap-1.5 rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-500 transition-colors">
                            <CheckCircle2 className="h-3.5 w-3.5" /> Approve
                          </button>
                          <button onClick={() => updateAction(item.id, "blocked")}
                            className="flex items-center gap-1.5 rounded-lg bg-red-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-red-500 transition-colors">
                            <X className="h-3.5 w-3.5" /> Block
                          </button>
                          <button onClick={() => updateAction(item.id, "flagged")}
                            className="flex items-center gap-1.5 rounded-lg bg-orange-600/20 px-3 py-1.5 text-xs font-semibold text-orange-400 hover:bg-orange-600/30 transition-colors">
                            <Flag className="h-3.5 w-3.5" /> Flag for Review
                          </button>
                        </div>
                      )}
                      {item.action !== "pending" && (
                        <button onClick={() => updateAction(item.id, "pending")}
                          className="text-xs text-[var(--muted-foreground)] hover:text-[var(--foreground)] transition-colors">
                          <TrendingDown className="mr-1 inline h-3 w-3" /> Revert to pending
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
