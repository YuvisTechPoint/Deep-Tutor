"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { ArrowRight, CheckCircle2, Circle, Sparkles, Target, Zap } from "lucide-react";

const ACCENT = "#D4734B";
const STORAGE = "deeptutor.skillBoost.checklist.v1";

const DEFAULT_IDS = [
  "sb.focus_block",
  "sb.review_notes",
  "sb.practice_set",
  "sb.teach_back",
  "sb.sleep_hydration",
] as const;

export default function SkillBoostPage() {
  const { t } = useTranslation();
  const [done, setDone] = useState<Record<string, boolean>>({});

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(STORAGE);
      if (raw) setDone(JSON.parse(raw) as Record<string, boolean>);
    } catch {
      /* ignore */
    }
  }, []);

  const persist = useCallback((next: Record<string, boolean>) => {
    setDone(next);
    try {
      window.localStorage.setItem(STORAGE, JSON.stringify(next));
    } catch {
      /* ignore */
    }
  }, []);

  const toggle = (id: string) => {
    persist({ ...done, [id]: !done[id] });
  };

  return (
    <div className="flex h-full min-h-0 flex-col overflow-y-auto">
      <header className="shrink-0 border-b border-[var(--border)]/60 bg-[var(--card)]/40 px-6 py-5">
        <div className="mx-auto flex max-w-3xl items-start gap-3">
          <div
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-[var(--border)]/60 bg-[var(--background)]"
            style={{ color: ACCENT }}
          >
            <Sparkles className="h-5 w-5" />
          </div>
          <div>
            <h1 className="text-lg font-semibold text-[var(--foreground)]">
              {t("skillBoost.page_title")}
            </h1>
            <p className="mt-1 text-sm text-[var(--muted-foreground)]">
              {t("skillBoost.page_subtitle")}
            </p>
          </div>
        </div>
      </header>

      <div className="mx-auto w-full max-w-3xl space-y-6 px-6 py-8">
        <section className="rounded-2xl border border-[var(--border)]/60 bg-[var(--card)]/30 p-5">
          <h2 className="flex items-center gap-2 text-sm font-semibold text-[var(--foreground)]">
            <Zap className="h-4 w-4" style={{ color: ACCENT }} />
            {t("skillBoost.daily_title")}
          </h2>
          <p className="mt-2 text-xs text-[var(--muted-foreground)]">
            {t("skillBoost.daily_body")}
          </p>
          <ul className="mt-4 space-y-2">
            {DEFAULT_IDS.map((id) => (
              <li key={id}>
                <button
                  type="button"
                  onClick={() => toggle(id)}
                  className="flex w-full items-start gap-3 rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/30 px-3 py-2.5 text-left text-sm transition-colors hover:border-[#D4734B]/40"
                >
                  {done[id] ? (
                    <CheckCircle2
                      className="mt-0.5 h-5 w-5 shrink-0 text-emerald-400"
                      aria-hidden
                    />
                  ) : (
                    <Circle
                      className="mt-0.5 h-5 w-5 shrink-0 text-[var(--muted-foreground)]"
                      aria-hidden
                    />
                  )}
                  <span
                    className={
                      done[id]
                        ? "text-[var(--muted-foreground)] line-through"
                        : "text-[var(--foreground)]"
                    }
                  >
                    {t(id)}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </section>

        <section className="grid gap-4 sm:grid-cols-2">
          <Link
            href="/practice"
            className="group rounded-2xl border border-[var(--border)]/60 bg-[var(--card)]/30 p-4 transition-colors hover:border-[#D4734B]/45"
          >
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <Target className="h-5 w-5" style={{ color: ACCENT }} />
                <span className="text-sm font-semibold text-[var(--foreground)]">
                  {t("skillBoost.card_practice_title")}
                </span>
              </div>
              <ArrowRight className="h-4 w-4 text-[var(--muted-foreground)] transition-transform group-hover:translate-x-0.5" />
            </div>
            <p className="mt-2 text-xs text-[var(--muted-foreground)]">
              {t("skillBoost.card_practice_body")}
            </p>
          </Link>
          <Link
            href="/career"
            className="group rounded-2xl border border-[var(--border)]/60 bg-[var(--card)]/30 p-4 transition-colors hover:border-[#D4734B]/45"
          >
            <div className="flex items-center justify-between gap-2">
              <div className="flex items-center gap-2">
                <Sparkles className="h-5 w-5" style={{ color: ACCENT }} />
                <span className="text-sm font-semibold text-[var(--foreground)]">
                  {t("skillBoost.card_career_title")}
                </span>
              </div>
              <ArrowRight className="h-4 w-4 text-[var(--muted-foreground)] transition-transform group-hover:translate-x-0.5" />
            </div>
            <p className="mt-2 text-xs text-[var(--muted-foreground)]">
              {t("skillBoost.card_career_body")}
            </p>
          </Link>
        </section>
      </div>
    </div>
  );
}
