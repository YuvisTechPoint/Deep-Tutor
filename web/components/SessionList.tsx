"use client";

import { Pencil, Trash2 } from "lucide-react";
import { useId, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { normalizeLanguage, appLanguageToBcp47Locale } from "@/lib/app-language";
import { type SessionSummary } from "@/lib/session-api";
import { normalizeMessageContent, truncateText } from "@/lib/message-content";
import { AppModal } from "@/components/ui/AppModal";

type SessionRuntimeStatus =
  | "idle"
  | "running"
  | "completed"
  | "failed"
  | "cancelled"
  | "rejected";

interface SessionListProps {
  sessions: SessionSummary[];
  activeSessionId: string | null;
  loading?: boolean;
  compact?: boolean;
  onSelect: (sessionId: string) => void | Promise<void>;
  onRename: (sessionId: string, title: string) => void | Promise<void>;
  onDelete: (sessionId: string) => void | Promise<void>;
}

function statusColor(status?: SessionRuntimeStatus): string {
  switch (status) {
    case "running":
      return "bg-blue-500";
    case "completed":
      return "bg-emerald-400";
    case "failed":
      return "bg-rose-500";
    case "rejected":
      return "bg-fuchsia-500";
    case "cancelled":
      return "bg-amber-500";
    default:
      return "bg-[var(--muted-foreground)]/25";
  }
}

function StatusIndicator({ status }: { status?: SessionRuntimeStatus }) {
  if (!status || status === "idle") return null;

  if (status === "running") {
    return (
      <span className="relative ml-1.5 inline-flex shrink-0">
        <span className="session-pulse absolute inline-flex h-2 w-2 rounded-full bg-blue-400/60" />
        <span className="relative inline-flex h-2 w-2 rounded-full bg-blue-500" />
      </span>
    );
  }

  if (status === "completed") {
    return (
      <span className="ml-1.5 inline-flex h-2 w-2 shrink-0 rounded-full bg-emerald-400/50 ring-1 ring-emerald-400/10" />
    );
  }

  if (status === "failed") {
    return (
      <span className="ml-1.5 inline-flex h-2 w-2 shrink-0 rounded-full bg-rose-500/80 ring-1 ring-rose-500/20" />
    );
  }

  if (status === "rejected") {
    return (
      <span className="ml-1.5 inline-flex h-2 w-2 shrink-0 rounded-full bg-fuchsia-500/80 ring-1 ring-fuchsia-500/20" />
    );
  }

  if (status === "cancelled") {
    return (
      <span className="ml-1.5 inline-flex h-2 w-2 shrink-0 rounded-full bg-amber-500/70 ring-1 ring-amber-500/20" />
    );
  }

  return null;
}

/** i18n keys — render with ``t(...)`` in the UI. */
function groupLabelKey(timestamp: number): string {
  const now = new Date();
  const date = new Date(timestamp * 1000);
  const startOfToday = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
  ).getTime();
  const startOfItemDay = new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
  ).getTime();
  const diffDays = Math.floor((startOfToday - startOfItemDay) / 86400000);
  if (diffDays <= 0) return "Today";
  if (diffDays === 1) return "Yesterday";
  if (diffDays < 7) return "Last 7 days";
  return "Earlier";
}

function relativeTime(timestamp: number, localeTag: string): string {
  const diffSeconds = Math.round(timestamp - Date.now() / 1000);
  const formatter = new Intl.RelativeTimeFormat(localeTag, { numeric: "auto" });
  const abs = Math.abs(diffSeconds);
  if (abs < 60) return formatter.format(diffSeconds, "second");
  if (abs < 3600)
    return formatter.format(Math.round(diffSeconds / 60), "minute");
  if (abs < 86400)
    return formatter.format(Math.round(diffSeconds / 3600), "hour");
  return formatter.format(Math.round(diffSeconds / 86400), "day");
}

export default function SessionList({
  sessions,
  activeSessionId,
  loading = false,
  compact = false,
  onSelect,
  onRename,
  onDelete,
}: SessionListProps) {
  const { t, i18n } = useTranslation();
  const [deleteTarget, setDeleteTarget] = useState<SessionSummary | null>(null);
  const [renameTarget, setRenameTarget] = useState<SessionSummary | null>(null);
  const [renameDraft, setRenameDraft] = useState("");
  const [deleteBusy, setDeleteBusy] = useState(false);
  const [renameBusy, setRenameBusy] = useState(false);

  const deleteTitleId = useId();
  const deleteDescId = useId();
  const renameTitleId = useId();
  const renameDescId = useId();

  const intlLocale = appLanguageToBcp47Locale(
    normalizeLanguage(i18n.resolvedLanguage || i18n.language),
  );

  const grouped = useMemo(() => {
    const buckets = new Map<string, SessionSummary[]>();
    for (const session of sessions) {
      const label = groupLabelKey(session.updated_at);
      const current = buckets.get(label) ?? [];
      current.push(session);
      buckets.set(label, current);
    }
    return Array.from(buckets.entries());
  }, [sessions]);

  const deleteDisplayTitle = deleteTarget
    ? deleteTarget.title?.trim() || t("Untitled chat")
    : "";

  const closeDeleteModal = () => {
    if (!deleteBusy) setDeleteTarget(null);
  };

  const confirmDelete = async () => {
    if (!deleteTarget) return;
    setDeleteBusy(true);
    try {
      await onDelete(deleteTarget.session_id);
      setDeleteTarget(null);
    } finally {
      setDeleteBusy(false);
    }
  };

  const openRenameModal = (session: SessionSummary) => {
    setRenameTarget(session);
    setRenameDraft(session.title || "");
  };

  const closeRenameModal = () => {
    if (!renameBusy) {
      setRenameTarget(null);
      setRenameDraft("");
    }
  };

  const confirmRename = async () => {
    if (!renameTarget) return;
    const next = renameDraft.trim();
    if (!next) return;
    setRenameBusy(true);
    try {
      await onRename(renameTarget.session_id, next);
      setRenameTarget(null);
      setRenameDraft("");
    } finally {
      setRenameBusy(false);
    }
  };

  const sessionModals = (
    <>
      <AppModal
        open={!!deleteTarget}
        onClose={closeDeleteModal}
        dialogTitleId={deleteTitleId}
        dialogDescriptionId={deleteDescId}
        backdropAriaLabel={t("Close")}
      >
        <div className="p-6 sm:p-7">
          <div className="flex gap-4">
            <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-[var(--destructive)]/12 text-[var(--destructive)] ring-1 ring-[var(--destructive)]/15">
              <Trash2 className="h-5 w-5" strokeWidth={2} />
            </div>
            <div className="min-w-0 flex-1 space-y-2">
              <h2
                id={deleteTitleId}
                className="text-lg font-semibold leading-snug tracking-tight text-[var(--foreground)]"
              >
                {t("chat.modal.delete_title")}
              </h2>
              <p
                id={deleteDescId}
                className="text-[13px] leading-relaxed text-[var(--muted-foreground)]"
              >
                {t("chat.modal.delete_body", { title: deleteDisplayTitle })}
              </p>
            </div>
          </div>
          <div className="mt-6 flex flex-col-reverse gap-2 border-t border-[var(--border)]/80 pt-5 sm:flex-row sm:justify-end">
            <button
              type="button"
              disabled={deleteBusy}
              onClick={closeDeleteModal}
              className="rounded-xl border border-[var(--border)] bg-transparent px-4 py-2.5 text-sm font-medium text-[var(--muted-foreground)] transition-colors hover:bg-[var(--accent)] hover:text-[var(--accent-foreground)] disabled:opacity-50"
            >
              {t("Cancel")}
            </button>
            <button
              type="button"
              disabled={deleteBusy}
              onClick={() => void confirmDelete()}
              className="rounded-xl bg-[var(--destructive)] px-4 py-2.5 text-sm font-semibold text-[var(--destructive-foreground)] shadow-sm transition-opacity hover:opacity-95 disabled:opacity-50"
            >
              {deleteBusy ? t("Loading") : t("chat.modal.confirm_delete")}
            </button>
          </div>
        </div>
      </AppModal>

      <AppModal
        open={!!renameTarget}
        onClose={closeRenameModal}
        dialogTitleId={renameTitleId}
        dialogDescriptionId={renameDescId}
        backdropAriaLabel={t("Close")}
      >
        <div className="p-6 sm:p-7">
          <div className="flex gap-4">
            <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-[var(--primary)]/12 text-[var(--primary)] ring-1 ring-[var(--primary)]/20">
              <Pencil className="h-5 w-5" strokeWidth={2} />
            </div>
            <div className="min-w-0 flex-1 space-y-1">
              <h2
                id={renameTitleId}
                className="text-lg font-semibold leading-snug tracking-tight text-[var(--foreground)]"
              >
                {t("chat.modal.rename_title")}
              </h2>
              <p
                id={renameDescId}
                className="text-[13px] leading-relaxed text-[var(--muted-foreground)]"
              >
                {t("chat.modal.rename_description")}
              </p>
            </div>
          </div>
          <label className="mt-5 block">
            <span className="sr-only">{t("chat.modal.rename_placeholder")}</span>
            <input
              value={renameDraft}
              autoFocus
              disabled={renameBusy}
              placeholder={t("chat.modal.rename_placeholder")}
              onChange={(e) => setRenameDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") void confirmRename();
                if (e.key === "Escape") closeRenameModal();
              }}
              className="w-full rounded-xl border border-[var(--border)] bg-[var(--background)] px-3.5 py-2.5 text-sm text-[var(--foreground)] outline-none transition-shadow placeholder:text-[var(--muted-foreground)]/50 focus:border-[var(--primary)]/40 focus:ring-2 focus:ring-[var(--ring)]/35 disabled:opacity-50"
            />
          </label>
          <div className="mt-6 flex flex-col-reverse gap-2 border-t border-[var(--border)]/80 pt-5 sm:flex-row sm:justify-end">
            <button
              type="button"
              disabled={renameBusy}
              onClick={closeRenameModal}
              className="rounded-xl border border-[var(--border)] bg-transparent px-4 py-2.5 text-sm font-medium text-[var(--muted-foreground)] transition-colors hover:bg-[var(--accent)] hover:text-[var(--accent-foreground)] disabled:opacity-50"
            >
              {t("Cancel")}
            </button>
            <button
              type="button"
              disabled={renameBusy || !renameDraft.trim()}
              onClick={() => void confirmRename()}
              className="rounded-xl bg-[var(--primary)] px-4 py-2.5 text-sm font-semibold text-[var(--primary-foreground)] shadow-sm transition-opacity hover:opacity-95 disabled:opacity-50"
            >
              {renameBusy ? t("Loading") : t("Save title")}
            </button>
          </div>
        </div>
      </AppModal>
    </>
  );

  if (loading) {
    if (compact) {
      return (
        <>
          <div className="ml-5 space-y-1.5 border-l border-[var(--border)]/30 py-1 pl-3">
            {[1, 2, 3].map((i) => (
              <div
                key={i}
                className="h-4 w-3/4 animate-pulse rounded bg-[var(--muted)]/40"
              />
            ))}
          </div>
          {sessionModals}
        </>
      );
    }
    return (
      <>
        <div className="space-y-2 px-1.5 py-2">
          {[1, 2, 3].map((i) => (
            <div
              key={i}
              className="h-10 animate-pulse rounded-md bg-[var(--muted)]/60"
            />
          ))}
        </div>
        {sessionModals}
      </>
    );
  }

  if (sessions.length === 0) {
    if (compact)
      return <>{sessionModals}</>;
    return (
      <>
        <div className="px-3 py-4 text-center text-[11px] text-[var(--muted-foreground)]/70">
          {t("No conversations yet")}
        </div>
        {sessionModals}
      </>
    );
  }

  /* ---- Compact tree-line style (under Chat nav item) ---- */
  if (compact) {
    return (
      <>
        <div className="ml-5 border-l border-[var(--border)]/30 py-1">
          {grouped.map(([label, items], groupIdx) => (
            <div key={label}>
              {groupIdx > 0 && (
                <div className="my-1 ml-3 mr-2 border-t border-[var(--border)]/20" />
              )}
              <div className="px-3 py-0.5 text-[10px] font-medium uppercase tracking-wider text-[var(--muted-foreground)]/40">
                {t(label)}
              </div>
              {items.map((session) => {
                const active = activeSessionId === session.session_id;
                return (
                  <div
                    key={session.session_id}
                    onClick={() => void onSelect(session.session_id)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === " ") {
                        event.preventDefault();
                        void onSelect(session.session_id);
                      }
                    }}
                    role="button"
                    tabIndex={0}
                    className={`group flex items-center gap-2 rounded-r-lg py-1 pl-3 pr-2 transition-colors ${
                      active
                        ? "bg-[var(--background)]/50 text-[var(--foreground)]"
                        : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/40 hover:text-[var(--foreground)]"
                    }`}
                  >
                    <span
                      className={`block h-1.5 w-1.5 shrink-0 rounded-full ${
                        active
                          ? "bg-[var(--foreground)]/60"
                          : statusColor(session.status)
                      }`}
                    />
                    <span
                      className={`min-w-0 flex-1 truncate text-[13px] ${active ? "font-medium" : ""}`}
                    >
                      {session.title || t("Untitled chat")}
                    </span>
                    <div className="flex shrink-0 items-center gap-px opacity-0 transition-opacity group-hover:opacity-100">
                      <button
                        type="button"
                        onClick={(event) => {
                          event.stopPropagation();
                          openRenameModal(session);
                        }}
                        className="rounded p-0.5 text-[var(--muted-foreground)] hover:text-[var(--foreground)]"
                        aria-label={t("Rename chat")}
                      >
                        <Pencil size={10} />
                      </button>
                      <button
                        type="button"
                        onClick={(event) => {
                          event.stopPropagation();
                          setDeleteTarget(session);
                        }}
                        className="rounded p-0.5 text-[var(--muted-foreground)] hover:text-[var(--destructive)]"
                        aria-label={t("Delete chat")}
                      >
                        <Trash2 size={10} />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          ))}
        </div>
        {sessionModals}
      </>
    );
  }

  /* ---- Classic style ---- */
  return (
    <>
      <div className="space-y-4">
        {grouped.map(([label, items]) => (
          <div key={label}>
            <div className="mb-1.5 px-2 text-[11px] font-semibold uppercase tracking-widest text-[var(--muted-foreground)]">
              {t(label)}
            </div>
            <div className="divide-y divide-[var(--border)]/45 overflow-hidden rounded-lg border border-[var(--border)]/45 bg-[var(--card)]/50">
              {items.map((session) => {
                const active = activeSessionId === session.session_id;
                return (
                  <div
                    key={session.session_id}
                    onClick={() => void onSelect(session.session_id)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter" || event.key === " ") {
                        event.preventDefault();
                        void onSelect(session.session_id);
                      }
                    }}
                    role="button"
                    tabIndex={0}
                    className={`group relative w-full px-3 py-2.5 text-left transition-colors duration-150 ${
                      active
                        ? "bg-[var(--background)]/70 text-[var(--foreground)]"
                        : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/50 hover:text-[var(--foreground)]"
                    }`}
                  >
                    {active && (
                      <span className="absolute left-0 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-r-full bg-[var(--primary)]" />
                    )}
                    <div className="flex items-start gap-1.5">
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center">
                          <span
                            className={`line-clamp-1 min-w-0 flex-1 text-[12px] leading-snug ${
                              active ? "font-medium" : "font-normal"
                            }`}
                          >
                            {session.title || t("Untitled chat")}
                          </span>
                          <StatusIndicator status={session.status} />
                        </div>
                        <div className="mt-0.5 line-clamp-1 text-[11px] leading-tight text-[var(--muted-foreground)]">
                          {truncateText(
                            normalizeMessageContent(session.last_message),
                            120,
                          ) || relativeTime(session.updated_at, intlLocale)}
                        </div>
                      </div>
                      <div className="flex shrink-0 items-center gap-0.5 pt-px opacity-0 transition-opacity group-hover:opacity-100">
                        <button
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            openRenameModal(session);
                          }}
                          className="rounded p-0.5 text-[var(--muted-foreground)] hover:bg-[var(--background)] hover:text-[var(--foreground)]"
                          aria-label={t("Rename chat")}
                        >
                          <Pencil size={11} />
                        </button>
                        <button
                          type="button"
                          onClick={(event) => {
                            event.stopPropagation();
                            setDeleteTarget(session);
                          }}
                          className="rounded p-0.5 text-[var(--muted-foreground)] hover:bg-[var(--background)] hover:text-[var(--destructive)]"
                          aria-label={t("Delete chat")}
                        >
                          <Trash2 size={11} />
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        ))}
      </div>
      {sessionModals}
    </>
  );
}
