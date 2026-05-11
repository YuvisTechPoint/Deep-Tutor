"use client";

import { useState } from "react";
import Link from "next/link";
import { marketingLoginUrl } from "@/lib/external-auth";
import {
  Briefcase,
  Mail,
  Lock,
  User,
  Building2,
  ChevronDown,
  Loader2,
  CheckCircle,
  BadgeCheck,
  BarChart2,
  FileText,
  GitCompare,
} from "lucide-react";

type Tab = "signin" | "signup";

const COMPANY_SIZES = [
  "1–10",
  "11–50",
  "51–200",
  "201–500",
  "501–1,000",
  "1,001–5,000",
  "5,000+",
];

const BENEFITS = [
  {
    icon: BadgeCheck,
    title: "Verified Skills",
    desc: "Candidate skills independently assessed by AI",
  },
  {
    icon: BarChart2,
    title: "Readiness Scores",
    desc: "Role-fit scores powered by real performance data",
  },
  {
    icon: FileText,
    title: "EIP Profiles",
    desc: "Deep learning identity profiles for every candidate",
  },
  {
    icon: GitCompare,
    title: "Skill Comparisons",
    desc: "Side-by-side candidate benchmarking",
  },
];

export default function RecruiterLoginPage() {
  const [tab, setTab] = useState<Tab>("signin");

  /* Sign-in state */
  const [siEmail, setSiEmail] = useState("");
  const [siPassword, setSiPassword] = useState("");
  const [siLoading, setSiLoading] = useState(false);
  const [siError, setSiError] = useState("");

  /* Sign-up state */
  const [suName, setSuName] = useState("");
  const [suEmail, setSuEmail] = useState("");
  const [suCompany, setSuCompany] = useState("");
  const [suSize, setSuSize] = useState("");
  const [suUseCase, setSuUseCase] = useState("");
  const [suLoading, setSuLoading] = useState(false);
  const [suError, setSuError] = useState("");
  const [suSubmitted, setSuSubmitted] = useState(false);

  async function handleSignIn(e: React.FormEvent) {
    e.preventDefault();
    setSiError("");
    setSiLoading(true);
    try {
      await new Promise((r) => setTimeout(r, 1200));
    } catch {
      setSiError("Sign in failed. Please check your credentials.");
    } finally {
      setSiLoading(false);
    }
  }

  async function handleSignUp(e: React.FormEvent) {
    e.preventDefault();
    setSuError("");
    setSuLoading(true);
    try {
      await new Promise((r) => setTimeout(r, 1400));
      setSuSubmitted(true);
    } catch {
      setSuError("Something went wrong. Please try again.");
    } finally {
      setSuLoading(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--background)] px-4 py-10">
      <div className="w-full max-w-md">
        <div className="w-full rounded-2xl border border-white/5 bg-[var(--secondary)] p-8">
          {/* Header */}
          <div className="mb-6 flex flex-col items-center text-center">
            <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-amber-500/15 ring-1 ring-amber-500/30">
              <Briefcase size={24} className="text-amber-400" />
            </div>
            <h1 className="mb-1 text-xl font-semibold text-[var(--foreground)]">
              Recruiter Access
            </h1>
            <p className="text-sm text-[var(--muted-foreground)]">
              Hire smarter with AI-verified candidate intelligence.
            </p>
          </div>

          {/* Tabs */}
          <div className="mb-6 flex rounded-xl border border-[var(--border)]/60 bg-[var(--background)]/50 p-1">
            {(["signin", "signup"] as Tab[]).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setTab(t)}
                className={`flex-1 rounded-lg py-2 text-sm font-medium transition-all ${
                  tab === t
                    ? "bg-amber-500/15 text-amber-300 shadow-sm"
                    : "text-[var(--muted-foreground)] hover:text-[var(--foreground)]"
                }`}
              >
                {t === "signin" ? "Sign In" : "Sign Up"}
              </button>
            ))}
          </div>

          {/* Sign In */}
          {tab === "signin" && (
            <form onSubmit={handleSignIn} className="space-y-4">
              <div>
                <label
                  htmlFor="si-email"
                  className="mb-1.5 block text-sm font-medium text-[var(--foreground)]"
                >
                  Work email
                </label>
                <div className="relative">
                  <Mail
                    size={15}
                    className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--muted-foreground)]"
                  />
                  <input
                    id="si-email"
                    type="email"
                    autoComplete="email"
                    required
                    value={siEmail}
                    onChange={(e) => setSiEmail(e.target.value)}
                    placeholder="you@company.com"
                    className="w-full rounded-lg border border-[var(--border)] bg-[var(--background)] py-2.5 pl-9 pr-3.5 text-sm text-[var(--foreground)] placeholder:text-[var(--muted-foreground)] focus:border-transparent focus:outline-none focus:ring-2 focus:ring-amber-500 transition-shadow"
                  />
                </div>
              </div>

              <div>
                <label
                  htmlFor="si-password"
                  className="mb-1.5 block text-sm font-medium text-[var(--foreground)]"
                >
                  Password
                </label>
                <div className="relative">
                  <Lock
                    size={15}
                    className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--muted-foreground)]"
                  />
                  <input
                    id="si-password"
                    type="password"
                    autoComplete="current-password"
                    required
                    value={siPassword}
                    onChange={(e) => setSiPassword(e.target.value)}
                    placeholder="••••••••"
                    className="w-full rounded-lg border border-[var(--border)] bg-[var(--background)] py-2.5 pl-9 pr-3.5 text-sm text-[var(--foreground)] placeholder:text-[var(--muted-foreground)] focus:border-transparent focus:outline-none focus:ring-2 focus:ring-amber-500 transition-shadow"
                  />
                </div>
              </div>

              {siError && (
                <p className="rounded-lg bg-red-500/10 px-3 py-2 text-sm text-red-400">
                  {siError}
                </p>
              )}

              <button
                type="submit"
                disabled={siLoading}
                className="flex w-full items-center justify-center gap-2 rounded-lg bg-amber-500 py-2.5 text-sm font-medium text-amber-950 transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
              >
                {siLoading ? (
                  <Loader2 size={15} className="animate-spin" />
                ) : (
                  "Sign In"
                )}
              </button>

              <p className="text-center text-xs text-[var(--muted-foreground)]">
                <Link
                  href="/forgot-password"
                  className="underline-offset-2 hover:underline hover:text-[var(--foreground)]"
                >
                  Forgot your password?
                </Link>
              </p>
            </form>
          )}

          {/* Sign Up */}
          {tab === "signup" && (
            <>
              {suSubmitted ? (
                <div className="flex flex-col items-center text-center">
                  <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-emerald-500/15 ring-1 ring-emerald-500/30">
                    <CheckCircle size={22} className="text-emerald-400" />
                  </div>
                  <h2 className="mb-2 text-lg font-semibold text-[var(--foreground)]">
                    Application submitted!
                  </h2>
                  <p className="mb-4 text-sm text-[var(--muted-foreground)]">
                    Your recruiter account request is under review. We&apos;ll
                    reach out within 24 hours.
                  </p>
                  <a
                    href={marketingLoginUrl()}
                    className="text-sm font-medium text-amber-400 underline-offset-2 hover:underline"
                  >
                    Back to sign in
                  </a>
                </div>
              ) : (
                <form onSubmit={handleSignUp} className="space-y-4">
                  {/* Full name */}
                  <div>
                    <label
                      htmlFor="su-name"
                      className="mb-1.5 block text-sm font-medium text-[var(--foreground)]"
                    >
                      Full name
                    </label>
                    <div className="relative">
                      <User
                        size={15}
                        className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--muted-foreground)]"
                      />
                      <input
                        id="su-name"
                        type="text"
                        required
                        value={suName}
                        onChange={(e) => setSuName(e.target.value)}
                        placeholder="Alex Johnson"
                        className="w-full rounded-lg border border-[var(--border)] bg-[var(--background)] py-2.5 pl-9 pr-3.5 text-sm text-[var(--foreground)] placeholder:text-[var(--muted-foreground)] focus:border-transparent focus:outline-none focus:ring-2 focus:ring-amber-500 transition-shadow"
                      />
                    </div>
                  </div>

                  {/* Work email */}
                  <div>
                    <label
                      htmlFor="su-email"
                      className="mb-1.5 block text-sm font-medium text-[var(--foreground)]"
                    >
                      Work email
                    </label>
                    <div className="relative">
                      <Mail
                        size={15}
                        className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--muted-foreground)]"
                      />
                      <input
                        id="su-email"
                        type="email"
                        autoComplete="email"
                        required
                        value={suEmail}
                        onChange={(e) => setSuEmail(e.target.value)}
                        placeholder="recruiter@company.com"
                        className="w-full rounded-lg border border-[var(--border)] bg-[var(--background)] py-2.5 pl-9 pr-3.5 text-sm text-[var(--foreground)] placeholder:text-[var(--muted-foreground)] focus:border-transparent focus:outline-none focus:ring-2 focus:ring-amber-500 transition-shadow"
                      />
                    </div>
                  </div>

                  {/* Company name */}
                  <div>
                    <label
                      htmlFor="su-company"
                      className="mb-1.5 block text-sm font-medium text-[var(--foreground)]"
                    >
                      Company name
                    </label>
                    <div className="relative">
                      <Building2
                        size={15}
                        className="pointer-events-none absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--muted-foreground)]"
                      />
                      <input
                        id="su-company"
                        type="text"
                        required
                        value={suCompany}
                        onChange={(e) => setSuCompany(e.target.value)}
                        placeholder="Acme Corp"
                        className="w-full rounded-lg border border-[var(--border)] bg-[var(--background)] py-2.5 pl-9 pr-3.5 text-sm text-[var(--foreground)] placeholder:text-[var(--muted-foreground)] focus:border-transparent focus:outline-none focus:ring-2 focus:ring-amber-500 transition-shadow"
                      />
                    </div>
                  </div>

                  {/* Company size */}
                  <div>
                    <label
                      htmlFor="su-size"
                      className="mb-1.5 block text-sm font-medium text-[var(--foreground)]"
                    >
                      Company size
                    </label>
                    <div className="relative">
                      <select
                        id="su-size"
                        required
                        value={suSize}
                        onChange={(e) => setSuSize(e.target.value)}
                        className="w-full appearance-none rounded-lg border border-[var(--border)] bg-[var(--background)] py-2.5 pl-3.5 pr-9 text-sm text-[var(--foreground)] focus:border-transparent focus:outline-none focus:ring-2 focus:ring-amber-500 transition-shadow"
                      >
                        <option value="" disabled>
                          Select company size
                        </option>
                        {COMPANY_SIZES.map((s) => (
                          <option key={s} value={s}>
                            {s} employees
                          </option>
                        ))}
                      </select>
                      <ChevronDown
                        size={15}
                        className="pointer-events-none absolute right-3.5 top-1/2 -translate-y-1/2 text-[var(--muted-foreground)]"
                      />
                    </div>
                  </div>

                  {/* Use case */}
                  <div>
                    <label
                      htmlFor="su-usecase"
                      className="mb-1.5 block text-sm font-medium text-[var(--foreground)]"
                    >
                      How do you plan to use DeepTutor?
                    </label>
                    <textarea
                      id="su-usecase"
                      required
                      rows={3}
                      value={suUseCase}
                      onChange={(e) => setSuUseCase(e.target.value)}
                      placeholder="e.g. Screening engineering candidates for backend roles…"
                      className="w-full resize-none rounded-lg border border-[var(--border)] bg-[var(--background)] px-3.5 py-2.5 text-sm text-[var(--foreground)] placeholder:text-[var(--muted-foreground)] focus:border-transparent focus:outline-none focus:ring-2 focus:ring-amber-500 transition-shadow"
                    />
                  </div>

                  {suError && (
                    <p className="rounded-lg bg-red-500/10 px-3 py-2 text-sm text-red-400">
                      {suError}
                    </p>
                  )}

                  <button
                    type="submit"
                    disabled={suLoading}
                    className="flex w-full items-center justify-center gap-2 rounded-lg bg-amber-500 py-2.5 text-sm font-medium text-amber-950 transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {suLoading ? (
                      <Loader2 size={15} className="animate-spin" />
                    ) : (
                      "Apply for Recruiter Access"
                    )}
                  </button>

                  {/* Approval note */}
                  <p className="rounded-lg border border-amber-500/20 bg-amber-500/10 px-3.5 py-3 text-xs leading-relaxed text-amber-300/80">
                    <span className="font-medium text-amber-300">Approval required.</span>{" "}
                    Recruiter accounts are manually reviewed. You&apos;ll hear from
                    us within 24 hours.
                  </p>
                </form>
              )}
            </>
          )}
        </div>

        {/* Benefits */}
        <div className="mt-6 grid grid-cols-2 gap-3">
          {BENEFITS.map((b) => (
            <div
              key={b.title}
              className="rounded-xl border border-white/5 bg-[var(--secondary)] p-3.5"
            >
              <b.icon size={16} className="mb-2 text-amber-400" />
              <p className="mb-0.5 text-xs font-semibold text-[var(--foreground)]">
                {b.title}
              </p>
              <p className="text-[11px] leading-relaxed text-[var(--muted-foreground)]">
                {b.desc}
              </p>
            </div>
          ))}
        </div>

        <p className="mt-6 text-center text-sm text-[var(--muted-foreground)]">
          Not a recruiter?{" "}
          <a
            href={marketingLoginUrl()}
            className="font-medium text-amber-400 underline-offset-2 hover:underline"
          >
            Sign in to your learner account
          </a>
        </p>
      </div>
    </div>
  );
}
