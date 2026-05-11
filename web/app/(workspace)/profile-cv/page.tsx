"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Copy, Save, UserRound } from "lucide-react";

const ACCENT = "#D4734B";
const STORAGE = "deeptutor.profileCv.v1";

interface ProfileCvDraft {
  headline: string;
  summary: string;
  experience: string;
  education: string;
  skills: string;
  certifications: string;
  links: string;
}

const emptyDraft: ProfileCvDraft = {
  headline: "",
  summary: "",
  experience: "",
  education: "",
  skills: "",
  certifications: "",
  links: "",
};

export default function ProfileCvPage() {
  const { t } = useTranslation();
  const [draft, setDraft] = useState<ProfileCvDraft>(emptyDraft);
  const [toast, setToast] = useState<string | null>(null);

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(STORAGE);
      if (raw) {
        const o = JSON.parse(raw) as Partial<ProfileCvDraft>;
        setDraft({ ...emptyDraft, ...o });
      }
    } catch {
      /* ignore */
    }
  }, []);

  const persist = useCallback((next: ProfileCvDraft) => {
    setDraft(next);
    try {
      window.localStorage.setItem(STORAGE, JSON.stringify(next));
      setToast(t("profileCv.saved"));
      window.setTimeout(() => setToast(null), 2000);
    } catch {
      setToast(t("profileCv.save_failed"));
      window.setTimeout(() => setToast(null), 3000);
    }
  }, [t]);

  const field = (key: keyof ProfileCvDraft, rows: number) => (
    <label className="block">
      <span className="mb-1.5 block text-[11px] font-medium text-[var(--muted-foreground)]">
        {t(`profileCv.field_${key}`)}
      </span>
      <textarea
        value={draft[key]}
        onChange={(e) => setDraft({ ...draft, [key]: e.target.value })}
        rows={rows}
        className="w-full resize-y rounded-xl border border-[var(--border)]/60 bg-[var(--background)]/40 px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[#D4734B]/55"
        placeholder={t(`profileCv.placeholder_${key}`)}
      />
    </label>
  );

  const buildExport = () => {
    const lines: string[] = [];
    if (draft.headline.trim()) lines.push(`# ${draft.headline.trim()}`);
    if (draft.summary.trim()) {
      lines.push("", "## Summary", draft.summary.trim());
    }
    if (draft.experience.trim()) {
      lines.push("", "## Experience", draft.experience.trim());
    }
    if (draft.education.trim()) {
      lines.push("", "## Education", draft.education.trim());
    }
    if (draft.skills.trim()) {
      lines.push("", "## Skills", draft.skills.trim());
    }
    if (draft.certifications.trim()) {
      lines.push("", "## Certifications", draft.certifications.trim());
    }
    if (draft.links.trim()) {
      lines.push("", "## Links", draft.links.trim());
    }
    return lines.join("\n").trim();
  };

  const copyExport = async () => {
    const text = buildExport();
    if (!text) {
      setToast(t("profileCv.nothing_to_copy"));
      window.setTimeout(() => setToast(null), 2000);
      return;
    }
    try {
      await navigator.clipboard.writeText(text);
      setToast(t("profileCv.copied"));
      window.setTimeout(() => setToast(null), 2000);
    } catch {
      setToast(t("profileCv.copy_failed"));
      window.setTimeout(() => setToast(null), 3000);
    }
  };

  return (
    <div className="flex h-full min-h-0 flex-col overflow-y-auto">
      <header className="shrink-0 border-b border-[var(--border)]/60 bg-[var(--card)]/40 px-6 py-5">
        <div className="mx-auto flex max-w-3xl flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-start gap-3">
            <div
              className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-[var(--border)]/60 bg-[var(--background)]"
              style={{ color: ACCENT }}
            >
              <UserRound className="h-5 w-5" />
            </div>
            <div>
              <h1 className="text-lg font-semibold text-[var(--foreground)]">
                {t("profileCv.page_title")}
              </h1>
              <p className="mt-1 text-sm text-[var(--muted-foreground)]">
                {t("profileCv.page_subtitle")}
              </p>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => persist(draft)}
              className="inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-medium text-white transition-opacity hover:opacity-90"
              style={{ backgroundColor: ACCENT }}
            >
              <Save className="h-4 w-4" />
              {t("profileCv.save")}
            </button>
            <button
              type="button"
              onClick={() => void copyExport()}
              className="inline-flex items-center gap-2 rounded-lg border border-[var(--border)]/60 px-4 py-2 text-sm font-medium text-[var(--foreground)] hover:bg-[var(--background)]/60"
            >
              <Copy className="h-4 w-4" />
              {t("profileCv.copy_markdown")}
            </button>
          </div>
        </div>
      </header>

      <div className="mx-auto w-full max-w-3xl space-y-5 px-6 py-8">
        {toast ? (
          <div className="rounded-lg border border-[var(--border)]/60 bg-[var(--card)]/50 px-3 py-2 text-xs text-[var(--foreground)]">
            {toast}
          </div>
        ) : null}

        <div className="space-y-4 rounded-2xl border border-[var(--border)]/60 bg-[var(--card)]/30 p-5">
          {field("headline", 2)}
          {field("summary", 4)}
          {field("experience", 6)}
          {field("education", 4)}
          {field("skills", 3)}
          {field("certifications", 3)}
          {field("links", 2)}
        </div>

        <p className="text-[11px] leading-relaxed text-[var(--muted-foreground)]">
          {t("profileCv.hint")}
        </p>
      </div>
    </div>
  );
}
