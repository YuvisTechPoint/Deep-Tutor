"use client";

import Link from "next/link";
import { useCallback, useState } from "react";
import {
  ArrowRight,
  BookOpen,
  Briefcase,
  CheckCircle2,
  Clock,
  Edit3,
  Flame,
  Loader2,
  MapPin,
  RefreshCw,
  Star,
  User,
} from "lucide-react";
import { useLiveLearningSnapshot } from "@/hooks/useLiveLearningSnapshot";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function ProfileChips({ items, color }: { items: string[]; color: string }) {
  if (!items.length) {
    return <p className="text-sm text-[var(--muted-foreground)] italic">Not set</p>;
  }
  return (
    <div className="flex flex-wrap gap-1.5">
      {items.map((item) => (
        <span
          key={item}
          className={`rounded-full border px-2.5 py-1 text-xs font-medium ${color}`}
        >
          {item}
        </span>
      ))}
    </div>
  );
}

function ProfileRow({
  icon,
  label,
  children,
}: {
  icon: React.ReactNode;
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex gap-4 rounded-xl border border-white/5 bg-[var(--background)]/40 px-5 py-4">
      <div className="mt-0.5 shrink-0 text-[var(--muted-foreground)]">{icon}</div>
      <div className="min-w-0 flex-1 space-y-2">
        <p className="text-[11px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
          {label}
        </p>
        {children}
      </div>
    </div>
  );
}

// ─── Main Component ───────────────────────────────────────────────────────────

export default function EipPage() {
  const { profile, game, loading, error, refresh, lastRefresh } =
    useLiveLearningSnapshot(true);
  const [refreshSpin, setRefreshSpin] = useState(false);

  const handleManualRefresh = useCallback(async () => {
    setRefreshSpin(true);
    try {
      await refresh();
    } finally {
      setRefreshSpin(false);
    }
  }, [refresh]);

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center gap-2 text-[var(--muted-foreground)]">
        <Loader2 className="h-5 w-5 animate-spin" />
        <span>Loading profile…</span>
      </div>
    );
  }

  const isEmpty =
    !profile ||
    (profile.goals.length === 0 &&
      !profile.target_path &&
      !profile.experience_level);

  return (
    <div className="flex h-full flex-col overflow-hidden">
      {/* Header */}
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-2xl flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-[var(--primary)] to-[#9e5038] shadow-lg shadow-[var(--primary)]/20">
            <User className="h-4 w-4 text-white" />
          </div>
          <div className="flex-1">
            <h1 className="text-sm font-bold text-[var(--foreground)]">
              Education Intelligence Profile
            </h1>
            <p className="text-[11px] text-[var(--muted-foreground)]">
              Your personalized learning identity
            </p>
          </div>
          <div className="flex flex-wrap items-center justify-end gap-2">
            {lastRefresh != null && (
              <span
                className="hidden text-[10px] text-[var(--muted-foreground)] sm:inline"
                title="Auto-refreshes while this tab is visible"
              >
                Live ·{" "}
                {new Date(lastRefresh).toLocaleTimeString(undefined, {
                  hour: "2-digit",
                  minute: "2-digit",
                  second: "2-digit",
                })}
              </span>
            )}
            <button
              type="button"
              onClick={() => void handleManualRefresh()}
              disabled={refreshSpin}
              className="inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-2.5 py-1.5 text-xs text-[var(--muted-foreground)] transition-colors hover:bg-white/10 disabled:opacity-50"
              title="Refresh profile and XP from server"
            >
              <RefreshCw
                className={`h-3.5 w-3.5 ${refreshSpin ? "animate-spin" : ""}`}
              />
              Refresh
            </button>
            <Link
              href="/onboarding"
              className="flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-3 py-1.5 text-xs text-[var(--muted-foreground)] transition-colors hover:bg-white/10"
            >
              <Edit3 className="h-3.5 w-3.5" />
              Edit
            </Link>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto px-4 py-6 sm:px-6">
        <div className="mx-auto max-w-2xl space-y-4">
          {error && (
            <div className="rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300">
              {error}
            </div>
          )}

          {isEmpty ? (
            /* ── Empty state ── */
            <div className="flex flex-col items-center justify-center gap-6 py-16 text-center">
              <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-[var(--primary)]/15">
                <BookOpen className="h-7 w-7 text-[var(--primary)]" />
              </div>
              <div className="space-y-2">
                <h2 className="text-lg font-semibold text-[var(--foreground)]">
                  Your profile is empty
                </h2>
                <p className="max-w-sm text-sm text-[var(--muted-foreground)]">
                  Complete the onboarding to set your goals, learning style, and
                  career target. The AI Tutor will personalise everything to you.
                </p>
              </div>
              <Link
                href="/onboarding"
                className="flex items-center gap-2 rounded-xl bg-[var(--primary)] px-5 py-2.5 text-sm font-semibold text-[var(--primary-foreground)] shadow-lg shadow-[var(--primary)]/25 hover:opacity-90 transition-opacity"
              >
                Start onboarding <ArrowRight className="h-4 w-4" />
              </Link>
            </div>
          ) : (
            /* ── Profile cards ── */
            <>
              {/* Quick stats */}
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                {[
                  {
                    icon: <Star className="h-4 w-4 text-amber-400" />,
                    label: "XP",
                    value: game ? game.total_xp.toLocaleString() : "—",
                    color: "text-amber-400",
                  },
                  {
                    icon: <Flame className="h-4 w-4 text-[var(--primary)]" />,
                    label: "Streak",
                    value: game ? `${game.streak_current} days` : "—",
                    color: "text-[var(--primary)]",
                  },
                  {
                    icon: <Clock className="h-4 w-4 text-blue-400" />,
                    label: "Hours",
                    value: profile?.weekly_hours
                      ? `${profile.weekly_hours}h/wk`
                      : "—",
                    color: "text-blue-400",
                  },
                  {
                    icon: <CheckCircle2 className="h-4 w-4 text-emerald-400" />,
                    label: "Diagnostic",
                    value: profile?.diagnostic_completed ? "Done" : "Pending",
                    color: profile?.diagnostic_completed
                      ? "text-emerald-400"
                      : "text-[var(--muted-foreground)]",
                  },
                ].map((s) => (
                  <div
                    key={s.label}
                    className="rounded-xl border border-white/5 bg-[var(--secondary)] p-4"
                  >
                    <div className="mb-1">{s.icon}</div>
                    <p className={`text-lg font-bold ${s.color}`}>{s.value}</p>
                    <p className="text-[10px] text-[var(--muted-foreground)]">
                      {s.label}
                    </p>
                  </div>
                ))}
              </div>

              {/* Learning goals */}
              <ProfileRow
                icon={<Star className="h-4 w-4" />}
                label="Learning Goals"
              >
                <ProfileChips
                  items={profile?.goals ?? []}
                  color="border-[var(--primary)]/35 bg-[var(--primary)]/12 text-[#eab8aa]"
                />
              </ProfileRow>

              {/* Target path */}
              <ProfileRow
                icon={<MapPin className="h-4 w-4" />}
                label="Target Career / Subject"
              >
                {profile?.target_path ? (
                  <p className="text-sm text-[var(--foreground)]">
                    {profile.target_path}
                  </p>
                ) : (
                  <p className="text-sm italic text-[var(--muted-foreground)]">
                    Not set
                  </p>
                )}
              </ProfileRow>

              {/* Experience level */}
              <ProfileRow
                icon={<Briefcase className="h-4 w-4" />}
                label="Experience Level"
              >
                {profile?.experience_level ? (
                  <span className="inline-block rounded-full border border-[var(--primary)]/35 bg-[var(--primary)]/12 px-3 py-1 text-xs font-semibold capitalize text-[#eab8aa]">
                    {profile.experience_level}
                  </span>
                ) : (
                  <p className="text-sm italic text-[var(--muted-foreground)]">
                    Not set
                  </p>
                )}
              </ProfileRow>

              {/* Learning styles */}
              <ProfileRow
                icon={<BookOpen className="h-4 w-4" />}
                label="Preferred Learning Styles"
              >
                <ProfileChips
                  items={profile?.learning_styles ?? []}
                  color="border-[var(--primary)]/35 bg-[var(--primary)]/12 text-[#eab8aa]"
                />
              </ProfileRow>

              {/* Notes */}
              {profile?.prior_summary && (
                <ProfileRow
                  icon={<Edit3 className="h-4 w-4" />}
                  label="Background & Notes"
                >
                  <p className="whitespace-pre-wrap text-sm leading-relaxed text-[var(--foreground)]">
                    {profile.prior_summary}
                  </p>
                </ProfileRow>
              )}

              {/* Last updated */}
              {profile?.updated_at && (
                <p className="text-center text-[11px] text-[var(--muted-foreground)]">
                  Last updated:{" "}
                  {new Date(profile.updated_at).toLocaleDateString(undefined, {
                    year: "numeric",
                    month: "long",
                    day: "numeric",
                  })}
                </p>
              )}

              {/* CTA row */}
              <div className="flex flex-wrap gap-3 pt-2">
                <Link
                  href="/roadmap"
                  className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[var(--primary)] py-2.5 text-sm font-semibold text-[var(--primary-foreground)] shadow-md shadow-[var(--primary)]/20 hover:opacity-90 transition-opacity"
                >
                  View my roadmap <ArrowRight className="h-4 w-4" />
                </Link>
                <Link
                  href="/onboarding"
                  className="flex items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/5 px-5 py-2.5 text-sm font-medium text-[var(--foreground)] hover:bg-white/10 transition-colors"
                >
                  <Edit3 className="h-3.5 w-3.5" />
                  Update profile
                </Link>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
