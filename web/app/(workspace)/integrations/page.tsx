"use client";

import { useEffect, useMemo, useState } from "react";
import { CheckCircle2, Plug, XCircle } from "lucide-react";
import { useTranslation } from "react-i18next";
import { AUTH_ENABLED } from "@/lib/auth";
import { isFirebaseConfigured } from "@/lib/firebase-client";
import { getSupabaseBrowser, isSupabaseConfigured } from "@/lib/supabase-browser";

type Row = { name: string; ok: boolean; detail: string };

export default function IntegrationsPage() {
  const { t } = useTranslation();
  const [supabaseSessionRow, setSupabaseSessionRow] = useState<Row | null>(null);

  const staticRows = useMemo((): Row[] => {
    const fb = isFirebaseConfigured();
    const sb = isSupabaseConfigured();
    return [
      {
        name: t("integrations.row.firebase_client"),
        ok: fb,
        detail: fb
          ? t("integrations.detail.firebase_ok")
          : t("integrations.detail.firebase_missing"),
      },
      {
        name: t("integrations.row.supabase_browser"),
        ok: sb,
        detail: sb
          ? t("integrations.detail.supabase_ok")
          : t("integrations.detail.supabase_missing"),
      },
      {
        name: t("integrations.row.dt_auth"),
        ok: AUTH_ENABLED,
        detail: AUTH_ENABLED
          ? t("integrations.detail.dt_auth_on")
          : t("integrations.detail.dt_auth_off"),
      },
    ];
  }, [t]);

  useEffect(() => {
    if (!isSupabaseConfigured()) return;
    const client = getSupabaseBrowser();
    if (!client) return;
    let cancelled = false;
    void client.auth.getSession().then(({ data, error }) => {
      if (cancelled) return;
      setSupabaseSessionRow({
        name: t("integrations.row.supabase_session"),
        ok: !error,
        detail: error
          ? error.message
          : data.session
            ? t("integrations.detail.supabase_signed_in", {
                id: data.session.user.email ?? data.session.user.id,
              })
            : t("integrations.detail.supabase_no_session"),
      });
    });
    return () => {
      cancelled = true;
    };
  }, [t]);

  const rows = supabaseSessionRow ? [...staticRows, supabaseSessionRow] : staticRows;

  return (
    <div className="flex h-full flex-col overflow-auto bg-[var(--background)]">
      <header className="shrink-0 border-b border-[var(--border)] bg-[var(--card)] px-6 py-5">
        <div className="mx-auto max-w-2xl">
          <div className="flex items-center gap-2 text-xs font-medium uppercase tracking-wider text-[var(--primary)]">
            <Plug className="h-3.5 w-3.5" aria-hidden />
            {t("Integrations")}
          </div>
          <h1 className="mt-1 text-xl font-semibold tracking-tight text-[var(--foreground)]">
            {t("integrations.title")}
          </h1>
          <p className="mt-2 max-w-2xl text-sm text-[var(--muted-foreground)]">
            {t("integrations.blurb")}
          </p>
        </div>
      </header>

      <div className="mx-auto w-full max-w-2xl flex-1 px-6 py-8">
        <ul className="space-y-3">
          {rows.map((r) => (
            <li
              key={r.name}
              className="flex gap-3 rounded-xl border border-[var(--border)] bg-[var(--card)] px-4 py-3"
            >
              {r.ok ? (
                <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-emerald-500" aria-hidden />
              ) : (
                <XCircle className="mt-0.5 h-5 w-5 shrink-0 text-amber-500" aria-hidden />
              )}
              <div>
                <p className="text-sm font-medium text-[var(--foreground)]">{r.name}</p>
                <p className="mt-0.5 text-xs text-[var(--muted-foreground)]">{r.detail}</p>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
