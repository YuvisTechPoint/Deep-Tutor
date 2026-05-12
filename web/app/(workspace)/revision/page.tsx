"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { Loader2, RefreshCw } from "lucide-react";
import { useTranslation } from "react-i18next";
import {
  fetchRevisionQueue,
  postRevisionReview,
  type RevisionCardItem,
} from "@/lib/workspace-api";

export default function RevisionPage() {
  const { t } = useTranslation();
  const [items, setItems] = useState<RevisionCardItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const r = await fetchRevisionQueue(40);
      setItems(r.items);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load queue");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const review = async (id: string, grade: "again" | "good" | "easy") => {
    setBusy(id + grade);
    setError(null);
    try {
      await postRevisionReview(id, grade);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Review failed");
    } finally {
      setBusy(null);
    }
  };

  return (
    <div className="mx-auto flex h-full max-w-2xl flex-col gap-4 overflow-y-auto p-6">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-lg font-semibold text-[var(--foreground)]">
            {t("revision.title", { defaultValue: "Revision queue" })}
          </h1>
          <p className="text-sm text-[var(--muted-foreground)]">
            {t("revision.subtitle", {
              defaultValue: "Topics seeded from practice mistakes — spaced reviews.",
            })}
          </p>
        </div>
        <button
          type="button"
          onClick={() => void load()}
          className="inline-flex items-center gap-1 rounded-lg border border-[var(--border)] px-3 py-1.5 text-xs text-[var(--foreground)] hover:bg-[var(--secondary)]"
        >
          <RefreshCw className="h-3.5 w-3.5" />
          {t("Refresh", { defaultValue: "Refresh" })}
        </button>
      </div>

      {error && (
        <div className="rounded-lg border border-red-500/40 bg-red-500/10 px-3 py-2 text-sm text-red-200">
          {error}
        </div>
      )}

      {loading ? (
        <div className="flex items-center gap-2 text-[var(--muted-foreground)]">
          <Loader2 className="h-5 w-5 animate-spin" />
          {t("Loading…")}
        </div>
      ) : items.length === 0 ? (
        <p className="text-sm text-[var(--muted-foreground)]">
          {t("revision.empty", {
            defaultValue: "Nothing due right now. Miss a few practice questions to seed cards.",
          })}
        </p>
      ) : (
        <ul className="space-y-3">
          {items.map((c) => (
            <li
              key={c.id}
              className="rounded-xl border border-[var(--border)]/60 bg-[var(--background)]/50 p-4"
            >
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="font-medium text-[var(--foreground)]">{c.topic}</span>
                <span className="text-[10px] uppercase text-[var(--muted-foreground)]">
                  reps {c.repetitions}
                </span>
              </div>
              <div className="mt-3 flex flex-wrap gap-2">
                {(["again", "good", "easy"] as const).map((g) => (
                  <button
                    key={g}
                    type="button"
                    disabled={busy !== null}
                    onClick={() => void review(c.id, g)}
                    className="rounded-lg bg-violet-600/90 px-3 py-1.5 text-xs font-medium text-white capitalize disabled:opacity-50"
                  >
                    {busy === c.id + g ? (
                      <Loader2 className="h-3.5 w-3.5 animate-spin" />
                    ) : (
                      g
                    )}
                  </button>
                ))}
              </div>
            </li>
          ))}
        </ul>
      )}

      <Link
        href="/practice"
        className="text-center text-sm text-violet-400 underline-offset-2 hover:underline"
      >
        {t("revision.goto_practice", { defaultValue: "Go to practice" })}
      </Link>
    </div>
  );
}
