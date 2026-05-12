"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import {
  Briefcase,
  Calendar,
  ChevronDown,
  ChevronUp,
  FileText,
  ListChecks,
  Mail,
  Phone,
  Sparkles,
  Trash2,
  Upload,
} from "lucide-react";
import {
  runLocalResumeAnalysis,
  type ResumeAnalysisSnapshot,
} from "@/lib/resume-local-analyze";

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
  dataUrl?: string;
  analysis?: ResumeAnalysisSnapshot;
}

function newId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `r_${Date.now()}`;
}

function readStoredFiles(): ResumeFileMeta[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(STORAGE);
    if (!raw) return [];
    return JSON.parse(raw) as ResumeFileMeta[];
  } catch {
    return [];
  }
}

function noteToMessage(
  t: (k: string, o?: Record<string, string | number>) => string,
  note: string | undefined,
  maxKb: number,
): string | null {
  switch (note) {
    case "no_inline_payload":
      return t("resume.note_no_payload", { maxKb });
    case "pdf_text_not_found":
      return t("resume.note_pdf_failed");
    case "format_local_scan_limited":
      return t("resume.note_format");
    case "no_text_extracted":
    case "decode_failed":
      return t("resume.note_no_text");
    default:
      return note ? t("resume.note_no_text") : null;
  }
}

function extractionLabel(
  t: (k: string) => string,
  a: ResumeAnalysisSnapshot | undefined,
): string {
  if (!a) return "";
  if (a.extraction === "txt") return t("resume.extraction_txt");
  if (a.extraction === "pdf-heuristic") return t("resume.extraction_pdf");
  return t("resume.extraction_none");
}

export default function ResumeUploadPage() {
  const { t } = useTranslation();
  const [files, setFiles] = useState<ResumeFileMeta[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [scanningId, setScanningId] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  const maxKbHint = useMemo(() => Math.round(MAX_BYTES / 1024), []);

  useEffect(() => {
    // Browser-only: avoid SSR/localStorage hydration mismatch on initial HTML.
    // eslint-disable-next-line react-hooks/set-state-in-effect -- intentional one-shot restore
    setFiles(readStoredFiles());
  }, []);

  const persist = useCallback(
    (next: ResumeFileMeta[]) => {
      setFiles(next);
      try {
        window.localStorage.setItem(STORAGE, JSON.stringify(next));
      } catch {
        setError(t("resume.storage_quota"));
      }
    },
    [t],
  );

  const onPickSync = async (list: FileList | null) => {
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
        const dataUrl = await new Promise<string | undefined>((resolve, reject) => {
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

  const remove = useCallback(
    (id: string) => {
      setFiles((prev) => {
        const next = prev.filter((x) => x.id !== id);
        try {
          window.localStorage.setItem(STORAGE, JSON.stringify(next));
        } catch {
          setError(t("resume.storage_quota"));
        }
        return next;
      });
      setExpandedId((e) => (e === id ? null : e));
    },
    [t],
  );

  const runScan = useCallback(
    (id: string) => {
      setScanningId(id);
      window.setTimeout(() => {
        setFiles((prev) => {
          const f = prev.find((x) => x.id === id);
          if (!f?.dataUrl) {
            return prev;
          }
          const snapshot = runLocalResumeAnalysis(f.dataUrl, f.type, f.name);
          const next = prev.map((x) => (x.id === id ? { ...x, analysis: snapshot } : x));
          try {
            window.localStorage.setItem(STORAGE, JSON.stringify(next));
          } catch {
            setError(t("resume.storage_quota"));
          }
          return next;
        });
        setScanningId(null);
      }, 0);
    },
    [t],
  );

  return (
    <div className="flex h-full min-h-0 flex-col overflow-y-auto">
      <header className="shrink-0 border-b border-[var(--border)]/60 bg-[var(--card)]/40 px-6 py-5">
        <div className="mx-auto flex max-w-3xl items-start gap-3">
          <div
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl border border-[var(--border)]/60 bg-[var(--background)]"
            style={{ color: ACCENT }}
          >
            <Upload className="h-5 w-5" />
          </div>
          <div className="min-w-0">
            <h1 className="text-lg font-semibold text-[var(--foreground)]">
              {t("resume.page_title")}
            </h1>
            <p className="mt-1 text-sm text-[var(--muted-foreground)]">
              {t("resume.page_subtitle")}
            </p>
            <div className="mt-3 flex flex-wrap gap-2">
              <Link
                href="/career"
                className="inline-flex items-center gap-1.5 rounded-lg border border-[var(--border)] bg-[var(--background)]/60 px-3 py-1.5 text-xs font-medium text-[var(--foreground)] transition hover:border-[#D4734B]/50 hover:bg-[var(--card)]"
              >
                <Briefcase className="h-3.5 w-3.5" aria-hidden />
                {t("resume.open_career")}
              </Link>
              <Link
                href="/profile-cv"
                className="inline-flex items-center gap-1.5 rounded-lg border border-dashed border-[var(--border)] px-3 py-1.5 text-xs font-medium text-[var(--muted-foreground)] transition hover:border-[#D4734B]/40 hover:text-[var(--foreground)]"
              >
                <Sparkles className="h-3.5 w-3.5" aria-hidden />
                {t("profileCv.page_title")}
              </Link>
            </div>
          </div>
        </div>
      </header>

      <div className="mx-auto w-full max-w-3xl space-y-6 px-6 py-8">
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
            onChange={(e) => void onPickSync(e.target.files)}
          />
        </label>

        {error ? (
          <p className="rounded-lg border border-rose-500/30 bg-rose-500/10 px-3 py-2 text-xs text-rose-200">
            {error}
          </p>
        ) : null}

        <section className="rounded-2xl border border-[var(--border)]/60 bg-gradient-to-b from-[var(--card)]/50 to-[var(--card)]/20 p-5">
          <div className="flex items-start gap-3">
            <div
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg border border-[var(--border)]/60 bg-[var(--background)]"
              style={{ color: ACCENT }}
            >
              <ListChecks className="h-5 w-5" aria-hidden />
            </div>
            <div>
              <h2 className="text-sm font-semibold text-[var(--foreground)]">
                {t("resume.insights_title")}
              </h2>
              <p className="mt-1 text-xs leading-relaxed text-[var(--muted-foreground)]">
                {t("resume.insights_subtitle")}
              </p>
              <p className="mt-2 text-xs text-[var(--muted-foreground)]">{t("resume.coach_hint")}</p>
            </div>
          </div>
        </section>

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
            <ul className="mt-3 space-y-3">
              {files.map((f) => {
                const a = f.analysis;
                const expanded = expandedId === f.id;
                const scanning = scanningId === f.id;
                const noteMsg = a ? noteToMessage(t, a.note, maxKbHint) : null;
                return (
                  <li
                    key={f.id}
                    className="overflow-hidden rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/40"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-3 px-3 py-2.5">
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-sm font-medium text-[var(--foreground)]">
                          {f.name}
                        </div>
                        <div className="mt-0.5 text-[11px] text-[var(--muted-foreground)]">
                          <span>{t("resume.file_kb", { kb: (f.size / 1024).toFixed(1) })}</span>
                          <span className="text-[var(--muted-foreground)]/70" aria-hidden>
                            {" \u00b7 "}
                          </span>
                          {!f.dataUrl && f.size > MAX_BYTES ? (
                            <span>{t("resume.meta_only")}</span>
                          ) : f.dataUrl ? (
                            <span>{t("resume.stored_local")}</span>
                          ) : (
                            <span>{t("resume.no_stored_copy")}</span>
                          )}
                        </div>
                        {a?.generatedAt ? (
                          <p className="mt-1 text-[10px] text-[var(--muted-foreground)]">
                            {t("resume.last_scan", {
                              when: new Date(a.generatedAt).toLocaleString(),
                            })}
                          </p>
                        ) : null}
                      </div>
                      <div className="flex shrink-0 items-center gap-1.5">
                        <button
                          type="button"
                          disabled={!f.dataUrl || scanning}
                          onClick={() => runScan(f.id)}
                          className="rounded-md border border-[var(--border)] bg-[var(--card)] px-2.5 py-1.5 text-[11px] font-medium text-[var(--foreground)] transition hover:border-[#D4734B]/50 disabled:cursor-not-allowed disabled:opacity-40"
                        >
                          {scanning
                            ? t("resume.analyzing")
                            : a
                              ? t("resume.reanalyze")
                              : t("resume.analyze")}
                        </button>
                        <button
                          type="button"
                          onClick={() => remove(f.id)}
                          className="rounded-md p-2 text-[var(--muted-foreground)] hover:bg-rose-500/15 hover:text-rose-400"
                          aria-label={t("resume.remove")}
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </div>

                    {a ? (
                      <div className="border-t border-[var(--border)]/40 bg-[var(--card)]/20 px-3 py-3">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="rounded-full border border-[var(--border)]/70 bg-[var(--muted)]/40 px-2 py-0.5 text-[10px] font-medium text-[var(--muted-foreground)]">
                            {extractionLabel(t, a)}
                          </span>
                          {a.wordCount > 0 ? (
                            <>
                              <span className="rounded-full bg-[var(--primary)]/15 px-2 py-0.5 text-[10px] font-semibold text-[var(--primary)]">
                                {a.wordCount} {t("resume.words")}
                              </span>
                              <span className="text-[10px] text-[var(--muted-foreground)]">
                                {t("resume.read_time", { n: a.estimatedReadMinutes })}
                              </span>
                            </>
                          ) : null}
                        </div>
                        {noteMsg ? (
                          <p className="mt-2 text-[11px] leading-relaxed text-amber-200/90">
                            {noteMsg}
                          </p>
                        ) : null}

                        {a.wordCount > 0 ? (
                          <>
                            <p className="mt-3 text-[10px] font-semibold uppercase tracking-wide text-[var(--muted-foreground)]">
                              {t("resume.scan_metrics")}
                            </p>
                            <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-3">
                              <MetricPill
                                label={t("resume.bullet_lines")}
                                value={String(a.bulletLikeLines)}
                              />
                              <MetricPill
                                label={t("resume.date_hints")}
                                value={String(a.dateHints)}
                              />
                              <MetricPill
                                label={t("resume.matched_skills")}
                                value={String(a.matchedSkills.length)}
                              />
                            </div>
                          </>
                        ) : null}

                        <button
                          type="button"
                          className="mt-3 flex w-full items-center justify-center gap-1 text-[11px] font-medium text-[var(--primary)] hover:underline"
                          onClick={() => setExpandedId(expanded ? null : f.id)}
                        >
                          {expanded ? (
                            <>
                              <ChevronUp className="h-3.5 w-3.5" />
                              {t("resume.hide_details")}
                            </>
                          ) : (
                            <>
                              <ChevronDown className="h-3.5 w-3.5" />
                              {t("resume.show_details")}
                            </>
                          )}
                        </button>

                        {expanded && a.wordCount > 0 ? (
                          <div className="mt-3 space-y-4 border-t border-[var(--border)]/30 pt-3">
                            <SectionBlock title={t("resume.sections_detected")}>
                              <div className="flex flex-wrap gap-1.5">
                                <SectionChip on={a.sections.experience} label={t("resume.section_experience")} />
                                <SectionChip on={a.sections.education} label={t("resume.section_education")} />
                                <SectionChip on={a.sections.skills} label={t("resume.section_skills")} />
                                <SectionChip on={a.sections.summary} label={t("resume.section_summary")} />
                                <SectionChip on={a.sections.projects} label={t("resume.section_projects")} />
                              </div>
                            </SectionBlock>

                            {(a.emails.length > 0 || a.phones.length > 0 || a.urls.length > 0) && (
                              <SectionBlock title={t("resume.contacts_found")}>
                                {a.emails.length > 0 ? (
                                  <div className="mt-1 flex flex-wrap items-start gap-1">
                                    <Mail className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[var(--muted-foreground)]" />
                                    <div className="text-[11px] text-[var(--muted-foreground)]">
                                      <span className="font-medium text-[var(--foreground)]">
                                        {t("resume.emails")}:{" "}
                                      </span>
                                      {a.emails.join(", ")}
                                    </div>
                                  </div>
                                ) : null}
                                {a.phones.length > 0 ? (
                                  <div className="mt-2 flex flex-wrap items-start gap-1">
                                    <Phone className="mt-0.5 h-3.5 w-3.5 shrink-0 text-[var(--muted-foreground)]" />
                                    <div className="text-[11px] text-[var(--muted-foreground)]">
                                      <span className="font-medium text-[var(--foreground)]">
                                        {t("resume.phones")}:{" "}
                                      </span>
                                      {a.phones.join(" · ")}
                                    </div>
                                  </div>
                                ) : null}
                                {a.urls.length > 0 ? (
                                  <div className="mt-2 text-[11px]">
                                    <span className="font-medium text-[var(--foreground)]">
                                      {t("resume.urls")}:{" "}
                                    </span>
                                    <span className="break-all text-[var(--muted-foreground)]">
                                      {a.urls.join(" · ")}
                                    </span>
                                  </div>
                                ) : null}
                              </SectionBlock>
                            )}

                            {a.matchedSkills.length > 0 ? (
                              <SectionBlock title={t("resume.matched_skills")}>
                                <div className="flex flex-wrap gap-1">
                                  {a.matchedSkills.map((s) => (
                                    <span
                                      key={s}
                                      className="rounded-md border border-[var(--primary)]/25 bg-[var(--primary)]/10 px-2 py-0.5 text-[10px] font-medium text-[var(--foreground)]"
                                    >
                                      {s}
                                    </span>
                                  ))}
                                </div>
                              </SectionBlock>
                            ) : null}

                            {a.topKeywords.length > 0 ? (
                              <SectionBlock title={t("resume.top_keywords")}>
                                <p className="text-[11px] text-[var(--muted-foreground)]">
                                  {a.topKeywords.join(" · ")}
                                </p>
                              </SectionBlock>
                            ) : null}

                            {a.previewSnippet ? (
                              <SectionBlock title={t("resume.text_preview")}>
                                <pre className="max-h-40 overflow-auto whitespace-pre-wrap rounded-lg border border-[var(--border)]/50 bg-[var(--background)]/80 p-2 font-mono text-[10px] leading-relaxed text-[var(--muted-foreground)]">
                                  {a.previewSnippet}
                                </pre>
                              </SectionBlock>
                            ) : null}
                          </div>
                        ) : null}
                      </div>
                    ) : null}
                  </li>
                );
              })}
            </ul>
          )}
        </section>

        <p className="flex items-start gap-2 text-[11px] leading-relaxed text-[var(--muted-foreground)]">
          <Calendar className="mt-0.5 h-3.5 w-3.5 shrink-0 opacity-70" aria-hidden />
          {t("resume.privacy_note")}
        </p>
      </div>
    </div>
  );
}

function MetricPill({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-[var(--border)]/50 bg-[var(--background)]/60 px-2 py-1.5">
      <div className="text-[9px] font-medium uppercase tracking-wide text-[var(--muted-foreground)]">
        {label}
      </div>
      <div className="text-sm font-semibold tabular-nums text-[var(--foreground)]">{value}</div>
    </div>
  );
}

function SectionBlock({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div>
      <p className="text-[10px] font-semibold uppercase tracking-wide text-[var(--muted-foreground)]">
        {title}
      </p>
      <div className="mt-1.5">{children}</div>
    </div>
  );
}

function SectionChip({ on, label }: { on: boolean; label: string }) {
  return (
    <span
      className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${
        on
          ? "border border-emerald-500/40 bg-emerald-500/15 text-emerald-200"
          : "border border-[var(--border)]/40 bg-[var(--muted)]/20 text-[var(--muted-foreground)] line-through opacity-60"
      }`}
    >
      {label}
    </span>
  );
}
