"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { FileText, Trash2, Upload } from "lucide-react";

const ACCENT = "#D4734B";
const STORAGE = "deeptutor.resume.uploads.v1";
const MAX_FILES = 5;
const MAX_BYTES = 450_000;

interface ResumeFileMeta {
  id: string;
  name: string;
  type: string;
  size: number;
  at: string;
  /** Optional small payload for demo restore */
  dataUrl?: string;
}

function newId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `r_${Date.now()}`;
}

export default function ResumeUploadPage() {
  const { t } = useTranslation();
  const [files, setFiles] = useState<ResumeFileMeta[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(STORAGE);
      if (raw) setFiles(JSON.parse(raw) as ResumeFileMeta[]);
    } catch {
      /* ignore */
    }
  }, []);

  const persist = useCallback((next: ResumeFileMeta[]) => {
    setFiles(next);
    try {
      window.localStorage.setItem(STORAGE, JSON.stringify(next));
    } catch {
      setError(t("resume.storage_quota"));
    }
  }, [t]);

  const onPick = async (list: FileList | null) => {
    setError(null);
    if (!list?.length) return;
    const next = [...files];
    for (let i = 0; i < list.length; i++) {
      if (next.length >= MAX_FILES) {
        setError(t("resume.max_files", { n: MAX_FILES }));
        break;
      }
      const f = list[i];
      const meta: ResumeFileMeta = {
        id: newId(),
        name: f.name,
        type: f.type || "application/octet-stream",
        size: f.size,
        at: new Date().toISOString(),
      };
      if (f.size <= MAX_BYTES) {
        const dataUrl = await new Promise<string>((resolve, reject) => {
          const r = new FileReader();
          r.onload = () => resolve(String(r.result));
          r.onerror = () => reject(new Error("read"));
          r.readAsDataURL(f);
        }).catch(() => undefined);
        if (dataUrl) meta.dataUrl = dataUrl;
      }
      next.push(meta);
    }
    persist(next);
  };

  const remove = (id: string) => {
    persist(files.filter((x) => x.id !== id));
  };

  return (
    <div className="flex h-full min-h-0 flex-col overflow-y-auto">
      <header className="shrink-0 border-b border-[var(--border)]/60 bg-[var(--card)]/40 px-6 py-5">
        <div className="mx-auto flex max-w-2xl items-start gap-3">
          <div
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-[var(--border)]/60 bg-[var(--background)]"
            style={{ color: ACCENT }}
          >
            <Upload className="h-5 w-5" />
          </div>
          <div>
            <h1 className="text-lg font-semibold text-[var(--foreground)]">
              {t("resume.page_title")}
            </h1>
            <p className="mt-1 text-sm text-[var(--muted-foreground)]">
              {t("resume.page_subtitle")}
            </p>
          </div>
        </div>
      </header>

      <div className="mx-auto w-full max-w-2xl space-y-6 px-6 py-8">
        <label className="flex cursor-pointer flex-col items-center justify-center gap-3 rounded-2xl border-2 border-dashed border-[var(--border)]/70 bg-[var(--card)]/20 px-6 py-14 transition-colors hover:border-[#D4734B]/55 hover:bg-[var(--card)]/40">
          <Upload className="h-8 w-8 text-[var(--muted-foreground)]" />
          <span className="text-sm font-medium text-[var(--foreground)]">
            {t("resume.drop_label")}
          </span>
          <span className="text-center text-xs text-[var(--muted-foreground)]">
            {t("resume.drop_hint")}
          </span>
          <input
            type="file"
            className="sr-only"
            accept=".pdf,.doc,.docx,.txt,.rtf,application/pdf"
            multiple
            onChange={(e) => void onPick(e.target.files)}
          />
        </label>

        {error ? (
          <p className="rounded-lg border border-rose-500/30 bg-rose-500/10 px-3 py-2 text-xs text-rose-200">
            {error}
          </p>
        ) : null}

        <section className="rounded-2xl border border-[var(--border)]/60 bg-[var(--card)]/30 p-4">
          <h2 className="flex items-center gap-2 text-sm font-semibold text-[var(--foreground)]">
            <FileText className="h-4 w-4" style={{ color: ACCENT }} />
            {t("resume.list_title")}
          </h2>
          {files.length === 0 ? (
            <p className="mt-4 text-center text-xs text-[var(--muted-foreground)]">
              {t("resume.empty")}
            </p>
          ) : (
            <ul className="mt-3 space-y-2">
              {files.map((f) => (
                <li
                  key={f.id}
                  className="flex items-center justify-between gap-3 rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/40 px-3 py-2"
                >
                  <div className="min-w-0">
                    <div className="truncate text-sm font-medium text-[var(--foreground)]">
                      {f.name}
                    </div>
                    <div className="mt-0.5 text-[11px] text-[var(--muted-foreground)]">
                      {(f.size / 1024).toFixed(1)} KB
                      {!f.dataUrl && f.size > MAX_BYTES
                        ? ` · ${t("resume.meta_only")}`
                        : f.dataUrl
                          ? ` · ${t("resume.stored_local")}`
                          : ""}
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => remove(f.id)}
                    className="rounded-md p-2 text-[var(--muted-foreground)] hover:bg-rose-500/15 hover:text-rose-400"
                    aria-label={t("resume.remove")}
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>

        <p className="text-[11px] leading-relaxed text-[var(--muted-foreground)]">
          {t("resume.privacy_note")}
        </p>
      </div>
    </div>
  );
}
