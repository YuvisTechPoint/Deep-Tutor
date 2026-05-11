"use client";

import Link from "next/link";
import { useTranslation } from "react-i18next";
import {
  ArrowRight,
  ClipboardCheck,
  ClipboardList,
  Sparkles,
  Target,
} from "lucide-react";

const ACCENT = "#D4734B";

const tiles = [
  {
    href: "/practice",
    titleKey: "assessments.tile_practice_title",
    bodyKey: "assessments.tile_practice_body",
    icon: Target,
    accent: "from-emerald-500/20 to-teal-500/10",
  },
  {
    href: "/mock-test",
    titleKey: "assessments.tile_mock_title",
    bodyKey: "assessments.tile_mock_body",
    icon: ClipboardCheck,
    accent: "from-violet-500/20 to-indigo-500/10",
  },
  {
    href: "/onboarding",
    titleKey: "assessments.tile_onboarding_title",
    bodyKey: "assessments.tile_onboarding_body",
    icon: ClipboardList,
    accent: "from-amber-500/20 to-orange-500/10",
  },
] as const;

export default function AssessmentsCenterPage() {
  const { t } = useTranslation();

  return (
    <div className="flex h-full flex-col overflow-auto bg-[var(--background)]">
      <header className="shrink-0 border-b border-[var(--border)] bg-[var(--card)] px-6 py-5">
        <div className="mx-auto max-w-3xl">
          <div
            className="flex items-center gap-2 text-xs font-medium uppercase tracking-wider"
            style={{ color: ACCENT }}
          >
            <Sparkles className="h-3.5 w-3.5" />
            {t("assessments.badge")}
          </div>
          <h1 className="mt-1 text-xl font-semibold tracking-tight text-[var(--foreground)]">
            {t("assessments.title")}
          </h1>
          <p className="mt-2 max-w-2xl text-sm text-[var(--muted-foreground)]">
            {t("assessments.subtitle")}
          </p>
        </div>
      </header>

      <div className="mx-auto w-full max-w-3xl flex-1 space-y-4 px-6 py-8">
        {tiles.map((tile) => {
          const Icon = tile.icon;
          return (
            <Link
              key={tile.href}
              href={tile.href}
              className={`flex gap-4 rounded-2xl border border-[var(--border)] bg-gradient-to-br ${tile.accent} p-5 shadow-sm transition hover:border-[#D4734B]/40 hover:shadow-md`}
            >
              <div
                className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-[var(--card)] ring-1 ring-[var(--border)]"
                style={{ color: ACCENT }}
              >
                <Icon className="h-6 w-6" />
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <h2 className="text-base font-semibold text-[var(--foreground)]">
                    {t(tile.titleKey)}
                  </h2>
                  <ArrowRight className="h-4 w-4 shrink-0 text-[var(--muted-foreground)]" />
                </div>
                <p className="mt-1 text-sm leading-relaxed text-[var(--muted-foreground)]">
                  {t(tile.bodyKey)}
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
