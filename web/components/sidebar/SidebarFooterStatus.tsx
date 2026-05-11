"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { Activity, ChevronDown, ExternalLink } from "lucide-react";
import { useTranslation } from "react-i18next";
import { apiUrl, resolveBase } from "@/lib/api";
import { Tooltip } from "@/components/ui/Tooltip";

type ApiState = "checking" | "online" | "offline";

interface SystemStatusPayload {
  llm?: { status?: string; model?: string | null };
  embeddings?: { status?: string; model?: string | null };
  hidream_image?: { status?: string; endpoint?: string };
}

interface SidebarFooterStatusProps {
  collapsed?: boolean;
}

const POLL_MS = 45_000;

async function fetchJsonQuiet(
  url: string,
  signal: AbortSignal,
): Promise<SystemStatusPayload | null> {
  try {
    const res = await fetch(url, {
      method: "GET",
      credentials: "include",
      signal,
    });
    if (!res.ok) return null;
    return (await res.json()) as SystemStatusPayload;
  } catch {
    return null;
  }
}

async function pingRoot(signal: AbortSignal): Promise<boolean> {
  try {
    const res = await fetch(apiUrl("/"), {
      method: "GET",
      credentials: "include",
      signal,
    });
    return res.ok;
  } catch {
    return false;
  }
}

export function SidebarFooterStatus({
  collapsed = false,
}: SidebarFooterStatusProps) {
  const { t } = useTranslation();
  const [apiState, setApiState] = useState<ApiState>("checking");
  const [systemStatus, setSystemStatus] = useState<SystemStatusPayload | null>(
    null,
  );
  const [devLinksOpen, setDevLinksOpen] = useState(false);

  const refresh = useCallback(async () => {
    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 8_000);
    try {
      const ok = await pingRoot(controller.signal);
      setApiState(ok ? "online" : "offline");
      if (ok) {
        const detail = await fetchJsonQuiet(
          apiUrl("/api/v1/system/status"),
          controller.signal,
        );
        setSystemStatus(detail);
      } else {
        setSystemStatus(null);
      }
    } finally {
      window.clearTimeout(timeout);
    }
  }, []);

  useEffect(() => {
    let cancelled = false;
    const run = async () => {
      if (cancelled) return;
      await refresh();
    };
    void run();
    const id = window.setInterval(run, POLL_MS);
    return () => {
      cancelled = true;
      window.clearInterval(id);
    };
  }, [refresh]);

  const docsHref = `${resolveBase()}/docs`;

  const { summaryLines, dotClass, iconClass } = useMemo(() => {
    const lines: string[] = [];
    if (apiState === "checking") {
      lines.push(t("Checking connection..."));
    } else if (apiState === "online") {
      lines.push(t("Backend connected"));
      const llm = systemStatus?.llm;
      if (llm?.status === "configured") {
        lines.push(
          llm.model
            ? `${t("LLM")}: ${llm.model}`
            : `${t("LLM")}: ${t("Ready")}`,
        );
      } else if (llm?.status === "not_configured") {
        lines.push(`${t("LLM")}: ${t("Not configured")}`);
      }
      const emb = systemStatus?.embeddings;
      if (emb?.status === "configured") {
        lines.push(
          emb.model
            ? `${t("Embedding")}: ${emb.model}`
            : `${t("Embedding")}: ${t("Ready")}`,
        );
      }
      const hd = systemStatus?.hidream_image;
      if (hd?.status === "configured") {
        lines.push(t("HiDream image service linked"));
      }
    } else {
      lines.push(t("Backend unreachable"));
      lines.push(t("Confirm the API server is running."));
    }

    const dot =
      apiState === "online"
        ? "bg-emerald-500/70"
        : apiState === "offline"
          ? "bg-rose-500/65"
          : "bg-[var(--muted-foreground)]/35";

    const icon =
      apiState === "online"
        ? "text-emerald-500/85"
        : apiState === "offline"
          ? "text-rose-500/80"
          : "text-[var(--muted-foreground)]";

    return { summaryLines: lines, dotClass: dot, iconClass: icon };
  }, [apiState, systemStatus, t]);

  if (collapsed) {
    const tipTitle =
      apiState === "checking"
        ? t("Checking connection...")
        : apiState === "online"
          ? t("Backend connected")
          : t("Backend unreachable");
    const tipBody = summaryLines.slice(1).join(" · ");

    return (
      <Tooltip
        label={tipTitle}
        description={tipBody || undefined}
        side="right"
      >
        <div
          className="mt-1 flex h-9 w-9 cursor-default items-center justify-center rounded-xl text-[var(--muted-foreground)] transition-colors hover:bg-[var(--background)]/50"
          role="status"
          aria-live="polite"
          aria-label={summaryLines.join(". ")}
        >
          <Activity size={17} strokeWidth={1.85} className={iconClass} />
        </div>
      </Tooltip>
    );
  }

  return (
    <div
      className="mt-2 space-y-2 rounded-xl border border-[var(--border)]/35 bg-[var(--background)]/30 px-2.5 py-2"
      role="status"
      aria-live="polite"
    >
      <div className="flex items-start gap-2">
        <span
          className={`mt-1 h-1.5 w-1.5 shrink-0 rounded-full ${dotClass}`}
          aria-hidden="true"
        />
        <div className="min-w-0 flex-1 space-y-1">
          {summaryLines.map((line, i) => (
            <p
              key={i}
              className={`text-[11px] leading-snug ${i === 0 ? "font-medium text-[var(--foreground)]/90" : "text-[var(--muted-foreground)]/90"}`}
            >
              {line}
            </p>
          ))}
        </div>
      </div>
      <div className="border-t border-[var(--border)]/25 pt-2">
        <button
          type="button"
          id="sidebar-dev-links-toggle"
          aria-expanded={devLinksOpen}
          aria-controls="sidebar-dev-links-panel"
          title={t("Developer links hint") as string}
          onClick={() => setDevLinksOpen((o) => !o)}
          className="flex w-full items-center justify-between gap-2 rounded-md px-0.5 py-1 text-left text-[10px] font-medium text-[var(--muted-foreground)] transition-colors hover:bg-[var(--muted)]/30 hover:text-[var(--foreground)]"
        >
          <span>{t("Developer links")}</span>
          <ChevronDown
            className={`h-3.5 w-3.5 shrink-0 opacity-70 transition-transform duration-200 ${devLinksOpen ? "rotate-180" : ""}`}
            aria-hidden
          />
        </button>
        {devLinksOpen && (
          <div
            id="sidebar-dev-links-panel"
            role="region"
            aria-labelledby="sidebar-dev-links-toggle"
            className="mt-1.5 flex flex-col gap-y-1.5 text-[10px] font-medium"
          >
            <a
              href={docsHref}
              target="_blank"
              rel="noreferrer noopener"
              className="inline-flex w-fit items-center gap-1 text-[var(--muted-foreground)] transition-colors hover:text-[var(--foreground)]"
            >
              {t("API docs")}
              <ExternalLink size={10} strokeWidth={2} aria-hidden="true" />
            </a>
            <Link
              href="/knowledge"
              className="w-fit text-[var(--muted-foreground)] transition-colors hover:text-[var(--foreground)]"
            >
              {t("Knowledge Bases")}
            </Link>
            <Link
              href="/settings"
              className="w-fit text-[var(--muted-foreground)] transition-colors hover:text-[var(--foreground)]"
            >
              {t("Models & providers")}
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
