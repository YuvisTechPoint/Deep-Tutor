"use client";

import Link from "next/link";
import { useTranslation } from "react-i18next";

const ACCENT = "#D4734B";

export default function TutorWorkspacePage() {
  const { t } = useTranslation();

  return (
    <div className="flex h-full min-h-0 flex-col gap-4 p-4 md:flex-row md:p-6">
      <div className="flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--background)]/40 shadow-sm">
        <div className="flex items-center justify-between border-b border-[var(--border)]/50 px-4 py-3">
          <h1 className="text-sm font-semibold text-[var(--foreground)]">
            {t("tutor.workspace_title", {
              defaultValue: "Tutor workspace",
            })}
          </h1>
          <Link
            href="/chat"
            className="text-xs font-medium text-[var(--muted-foreground)] underline-offset-2 hover:underline"
          >
            {t("tutor.open_full_chat", { defaultValue: "Open full chat" })}
          </Link>
        </div>
        <iframe
          title="Tutor chat"
          src="/chat"
          className="min-h-[420px] w-full flex-1 border-0 bg-[var(--background)] md:min-h-0"
        />
      </div>
      <aside className="flex w-full shrink-0 flex-col gap-3 md:w-80">
        <div
          className="rounded-2xl border border-[var(--border)] p-4"
          style={{ borderColor: `${ACCENT}33` }}
        >
          <h2 className="text-xs font-semibold uppercase tracking-wide text-[var(--muted-foreground)]">
            {t("tutor.hints_title", { defaultValue: "Hints & next steps" })}
          </h2>
          <ul className="mt-3 list-inside list-disc space-y-2 text-sm text-[var(--muted-foreground)]">
            <li>
              {t("tutor.hint_1", {
                defaultValue: "Ask for a hint before the full solution.",
              })}
            </li>
            <li>
              {t("tutor.hint_2", {
                defaultValue: "Use the chat model menu for a stronger reasoning model.",
              })}
            </li>
            <li>
              {t("tutor.hint_3", {
                defaultValue: "Attach images or PDFs from the chat composer.",
              })}
            </li>
          </ul>
        </div>
        <div className="rounded-2xl border border-[var(--border)]/60 bg-[var(--secondary)]/20 p-4 text-xs text-[var(--muted-foreground)]">
          {t("tutor.whiteboard_note", {
            defaultValue:
              "Structured math and markdown render in chat. A dedicated drawing canvas can be added behind a feature flag later.",
          })}
        </div>
        <Link
          href="/roadmap"
          className="rounded-xl px-4 py-3 text-center text-sm font-medium text-white transition-opacity hover:opacity-90"
          style={{ backgroundColor: ACCENT }}
        >
          {t("tutor.back_roadmap", { defaultValue: "Back to roadmap" })}
        </Link>
      </aside>
    </div>
  );
}
