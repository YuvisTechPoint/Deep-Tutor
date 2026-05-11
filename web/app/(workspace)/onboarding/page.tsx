"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  ClipboardList,
  Loader2,
  Sparkles,
} from "lucide-react";
import { useTranslation } from "react-i18next";
import type { LearningProfile } from "@/lib/learning-profile-api";
import {
  getLearningProfile,
  saveLearningProfile,
} from "@/lib/learning-profile-api";
import { notifyLearningProfileUpdated } from "@/lib/learning-profile-events";

const STEP_COUNT = 7;

function goalsOptions(t: (k: string) => string): string[] {
  return [
    t("onboarding.goal.exam_prep"),
    t("onboarding.goal.job_skills"),
    t("onboarding.goal.university"),
    t("onboarding.goal.certification"),
    t("onboarding.goal.hobby"),
    t("onboarding.goal.research"),
  ];
}

function styleOptions(t: (k: string) => string): string[] {
  return [
    t("onboarding.style.visual"),
    t("onboarding.style.reading"),
    t("onboarding.style.hands_on"),
    t("onboarding.style.video"),
    t("onboarding.style.discussion"),
  ];
}

function emptyProfile(): LearningProfile {
  return {
    goals: [],
    target_path: "",
    weekly_hours: null,
    learning_styles: [],
    experience_level: "",
    prior_summary: "",
    diagnostic_completed: false,
  };
}

export default function OnboardingPage() {
  const { t } = useTranslation();
  const [step, setStep] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [profile, setProfile] = useState<LearningProfile>(emptyProfile());

  const goalPresets = useMemo(() => goalsOptions(t), [t]);
  const stylePresets = useMemo(() => styleOptions(t), [t]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const data = await getLearningProfile();
        if (!cancelled) {
          setProfile({ ...emptyProfile(), ...data });
        }
      } catch (e) {
        if (!cancelled) {
          setError(
            e instanceof Error ? e.message : t("onboarding.load_failed"),
          );
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [t]);

  const toggleInList = useCallback(
    (field: "goals" | "learning_styles", value: string) => {
      setProfile((prev) => {
        const list = prev[field];
        const has = list.includes(value);
        const next = has ? list.filter((x) => x !== value) : [...list, value];
        return { ...prev, [field]: next };
      });
    },
    [],
  );

  const persist = async () => {
    setSaving(true);
    setError(null);
    try {
      const saved = await saveLearningProfile(profile);
      setProfile((prev) => ({ ...prev, ...saved }));
      notifyLearningProfileUpdated();
      setDone(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : t("onboarding.save_failed"));
    } finally {
      setSaving(false);
    }
  };

  /** Push current draft to the server so EIP, roadmap, and tutor stay aligned in real time. */
  const syncDraft = async () => {
    setSyncing(true);
    setError(null);
    try {
      const saved = await saveLearningProfile(profile);
      setProfile((prev) => ({ ...prev, ...saved }));
      notifyLearningProfileUpdated();
    } catch (e) {
      setError(e instanceof Error ? e.message : t("onboarding.save_failed"));
      throw e;
    } finally {
      setSyncing(false);
    }
  };

  const goNext = async () => {
    if (step >= STEP_COUNT - 1) return;
    try {
      await syncDraft();
      setStep((s) => Math.min(STEP_COUNT - 1, s + 1));
    } catch {
      /* error surfaced via setError */
    }
  };

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center gap-2 text-[var(--muted-foreground)]">
        <Loader2 className="h-5 w-5 animate-spin" />
        <span>{t("Loading…")}</span>
      </div>
    );
  }

  if (done) {
    return (
      <div className="flex h-full flex-col items-center justify-center gap-6 px-6 text-center">
        <div className="rounded-full bg-emerald-500/15 p-4 text-emerald-400">
          <Check className="h-10 w-10" strokeWidth={2} />
        </div>
        <div className="max-w-md space-y-2">
          <h1 className="text-xl font-semibold text-[var(--foreground)]">
            {t("onboarding.saved_title")}
          </h1>
          <p className="text-sm text-[var(--muted-foreground)]">
            {t("onboarding.saved_body")}
          </p>
        </div>
        <div className="flex flex-wrap items-center justify-center gap-3">
          <Link
            href="/eip"
            className="rounded-lg bg-[var(--foreground)] px-4 py-2 text-sm font-medium text-[var(--background)] transition-opacity hover:opacity-90"
          >
            {t("onboarding.view_learning_id")}
          </Link>
          <Link
            href="/roadmap"
            className="rounded-lg border border-[var(--border)] px-4 py-2 text-sm text-[var(--foreground)] transition-colors hover:bg-[var(--secondary)]"
          >
            {t("onboarding.go_roadmap")}
          </Link>
        </div>
      </div>
    );
  }

  const weeklyLabel =
    profile.weekly_hours == null
      ? t("onboarding.hours_not_set")
      : t("onboarding.hours_value", { hours: profile.weekly_hours });

  return (
    <div className="flex h-full flex-col overflow-hidden">
      <header className="border-b border-[var(--border)]/60 px-6 py-4">
        <div className="flex flex-wrap items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-violet-500/15 text-violet-300">
            <ClipboardList className="h-5 w-5" />
          </div>
          <div className="min-w-0 flex-1">
            <h1 className="text-lg font-semibold tracking-tight text-[var(--foreground)]">
              {t("onboarding.page_title")}
            </h1>
            <p className="text-sm text-[var(--muted-foreground)]">
              {t("onboarding.page_subtitle")}
            </p>
          </div>
          <div className="flex flex-wrap items-center justify-end gap-2">
            {(syncing || saving) && (
              <span className="inline-flex items-center gap-1.5 rounded-full border border-[var(--border)]/60 bg-[var(--secondary)]/40 px-2.5 py-1 text-[11px] text-[var(--muted-foreground)]">
                <Loader2 className="h-3 w-3 animate-spin" />
                {saving ? t("onboarding.saving_final") : t("onboarding.syncing")}
              </span>
            )}
            <div className="flex items-center gap-1 rounded-full border border-[var(--border)]/60 bg-[var(--secondary)]/40 px-3 py-1 text-xs text-[var(--muted-foreground)]">
              <Sparkles className="h-3.5 w-3.5 text-amber-400" />
              {t("onboarding.step_indicator", {
                current: step + 1,
                total: STEP_COUNT,
              })}
            </div>
          </div>
        </div>
      </header>

      <div className="flex flex-1 flex-col overflow-y-auto px-6 py-8">
        <div className="mx-auto w-full max-w-xl space-y-8">
          {error && (
            <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-200">
              {error}
            </div>
          )}

          {step === 0 && (
            <section className="space-y-4">
              <h2 className="text-base font-medium text-[var(--foreground)]">
                {t("onboarding.step_welcome_title")}
              </h2>
              <p className="text-sm leading-relaxed text-[var(--muted-foreground)]">
                {t("onboarding.step_welcome_body")}
              </p>
            </section>
          )}

          {step === 1 && (
            <section className="space-y-4">
              <h2 className="text-base font-medium text-[var(--foreground)]">
                {t("onboarding.step_goals_title")}
              </h2>
              <p className="text-sm text-[var(--muted-foreground)]">
                {t("onboarding.step_goals_hint")}
              </p>
              <div className="flex flex-wrap gap-2">
                {goalPresets.map((g) => {
                  const active = profile.goals.includes(g);
                  return (
                    <button
                      key={g}
                      type="button"
                      onClick={() => toggleInList("goals", g)}
                      className={`rounded-full border px-3 py-1.5 text-xs font-medium transition-colors ${
                        active
                          ? "border-violet-500/60 bg-violet-500/15 text-violet-100"
                          : "border-[var(--border)] bg-[var(--background)]/40 text-[var(--muted-foreground)] hover:border-[var(--border)]/80"
                      }`}
                    >
                      {g}
                    </button>
                  );
                })}
              </div>
            </section>
          )}

          {step === 2 && (
            <section className="space-y-4">
              <h2 className="text-base font-medium text-[var(--foreground)]">
                {t("onboarding.step_path_title")}
              </h2>
              <p className="text-sm text-[var(--muted-foreground)]">
                {t("onboarding.step_path_hint")}
              </p>
              <textarea
                value={profile.target_path}
                onChange={(e) =>
                  setProfile((p) => ({ ...p, target_path: e.target.value }))
                }
                rows={5}
                placeholder={t("onboarding.step_path_placeholder")}
                className="w-full resize-none rounded-xl border border-[var(--border)] bg-[var(--background)]/60 px-4 py-3 text-sm text-[var(--foreground)] outline-none ring-violet-500/30 placeholder:text-[var(--muted-foreground)] focus:ring-2"
              />
            </section>
          )}

          {step === 3 && (
            <section className="space-y-4">
              <h2 className="text-base font-medium text-[var(--foreground)]">
                {t("onboarding.step_hours_title")}
              </h2>
              <p className="text-sm text-[var(--muted-foreground)]">
                {weeklyLabel}
              </p>
              <input
                type="range"
                min={1}
                max={40}
                step={1}
                value={profile.weekly_hours ?? 8}
                onChange={(e) =>
                  setProfile((p) => ({
                    ...p,
                    weekly_hours: Number(e.target.value),
                  }))
                }
                className="w-full accent-violet-500"
              />
              <button
                type="button"
                onClick={() =>
                  setProfile((p) => ({ ...p, weekly_hours: null }))
                }
                className="text-xs text-[var(--muted-foreground)] underline decoration-dotted underline-offset-2 hover:text-[var(--foreground)]"
              >
                {t("onboarding.clear_hours")}
              </button>
            </section>
          )}

          {step === 4 && (
            <section className="space-y-4">
              <h2 className="text-base font-medium text-[var(--foreground)]">
                {t("onboarding.step_styles_title")}
              </h2>
              <div className="flex flex-wrap gap-2">
                {stylePresets.map((s) => {
                  const active = profile.learning_styles.includes(s);
                  return (
                    <button
                      key={s}
                      type="button"
                      onClick={() => toggleInList("learning_styles", s)}
                      className={`rounded-full border px-3 py-1.5 text-xs font-medium transition-colors ${
                        active
                          ? "border-teal-500/60 bg-teal-500/15 text-teal-100"
                          : "border-[var(--border)] bg-[var(--background)]/40 text-[var(--muted-foreground)] hover:border-[var(--border)]/80"
                      }`}
                    >
                      {s}
                    </button>
                  );
                })}
              </div>
            </section>
          )}

          {step === 5 && (
            <section className="space-y-4">
              <h2 className="text-base font-medium text-[var(--foreground)]">
                {t("onboarding.step_experience_title")}
              </h2>
              <div className="flex flex-col gap-2">
                {(["beginner", "intermediate", "advanced"] as const).map(
                  (lvl) => (
                    <label
                      key={lvl}
                      className={`flex cursor-pointer items-center gap-3 rounded-xl border px-4 py-3 text-sm transition-colors ${
                        profile.experience_level === lvl
                          ? "border-violet-500/50 bg-violet-500/10"
                          : "border-[var(--border)] hover:bg-[var(--secondary)]/40"
                      }`}
                    >
                      <input
                        type="radio"
                        name="exp"
                        checked={profile.experience_level === lvl}
                        onChange={() =>
                          setProfile((p) => ({ ...p, experience_level: lvl }))
                        }
                        className="accent-violet-500"
                      />
                      <span className="text-[var(--foreground)]">
                        {t(`onboarding.experience.${lvl}`)}
                      </span>
                    </label>
                  ),
                )}
              </div>
            </section>
          )}

          {step === 6 && (
            <section className="space-y-4">
              <h2 className="text-base font-medium text-[var(--foreground)]">
                {t("onboarding.step_notes_title")}
              </h2>
              <textarea
                value={profile.prior_summary}
                onChange={(e) =>
                  setProfile((p) => ({ ...p, prior_summary: e.target.value }))
                }
                rows={5}
                placeholder={t("onboarding.step_notes_placeholder")}
                className="w-full resize-none rounded-xl border border-[var(--border)] bg-[var(--background)]/60 px-4 py-3 text-sm text-[var(--foreground)] outline-none ring-violet-500/30 placeholder:text-[var(--muted-foreground)] focus:ring-2"
              />
              <label className="flex cursor-pointer items-center gap-2 text-sm text-[var(--muted-foreground)]">
                <input
                  type="checkbox"
                  checked={profile.diagnostic_completed}
                  onChange={(e) =>
                    setProfile((p) => ({
                      ...p,
                      diagnostic_completed: e.target.checked,
                    }))
                  }
                  className="accent-violet-500"
                />
                {t("onboarding.diagnostic_done")}
              </label>
            </section>
          )}

          <div className="flex flex-wrap items-center justify-between gap-3 border-t border-[var(--border)]/40 pt-6">
            <button
              type="button"
              disabled={step === 0 || syncing || saving}
              onClick={() => setStep((s) => Math.max(0, s - 1))}
              className="inline-flex items-center gap-2 rounded-lg border border-[var(--border)] px-4 py-2 text-sm text-[var(--foreground)] transition-colors hover:bg-[var(--secondary)] disabled:pointer-events-none disabled:opacity-40"
            >
              <ArrowLeft className="h-4 w-4" />
              {t("Back")}
            </button>
            {step < STEP_COUNT - 1 ? (
              <button
                type="button"
                disabled={syncing || saving}
                onClick={() => void goNext()}
                className="inline-flex items-center gap-2 rounded-lg bg-[var(--foreground)] px-4 py-2 text-sm font-medium text-[var(--background)] transition-opacity hover:opacity-90 disabled:opacity-60"
              >
                {syncing && <Loader2 className="h-4 w-4 shrink-0 animate-spin" />}
                {t("Continue")}
                {!syncing && <ArrowRight className="h-4 w-4 shrink-0" />}
              </button>
            ) : (
              <button
                type="button"
                disabled={saving || syncing}
                onClick={() => void persist()}
                className="inline-flex items-center gap-2 rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white transition-opacity hover:opacity-90 disabled:opacity-60"
              >
                {saving ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <Check className="h-4 w-4" />
                )}
                {t("onboarding.save")}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
