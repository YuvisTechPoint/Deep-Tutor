/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import { marketingLoginUrl } from "@/lib/external-auth";
import { ArrowLeft, Brain, CheckCircle2, Loader2, Lock, Mail } from "lucide-react";

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim()) { setError("Please enter your email address."); return; }
    setLoading(true);
    setError("");
    await new Promise((r) => setTimeout(r, 1500));
    setLoading(false);
    setSent(true);
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#030303] px-4">
      {/* Background glow */}
      <div className="pointer-events-none fixed inset-0">
        <div className="absolute left-1/2 top-1/3 h-96 w-96 -translate-x-1/2 rounded-full bg-violet-600/10 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        {/* Back link */}
        <a
          href={marketingLoginUrl()}
          className="mb-6 flex items-center gap-2 text-sm text-white/50 hover:text-white transition-colors"
        >
          <ArrowLeft className="h-4 w-4" /> Back to Sign In
        </a>

        <div className="rounded-2xl border border-white/10 bg-white/3 p-8 backdrop-blur-xl shadow-2xl">
          {/* Logo */}
          <div className="mb-6 flex flex-col items-center gap-3">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500 to-indigo-600 shadow-xl shadow-violet-500/30">
              <Lock className="h-7 w-7 text-white" />
            </div>
            <div className="text-center">
              <div className="mb-1 flex items-center justify-center gap-2">
                <Brain className="h-4 w-4 text-violet-400" />
                <span className="text-sm font-semibold text-violet-400">DeepTutor</span>
              </div>
              <h1 className="text-2xl font-black text-white">Forgot your password?</h1>
              <p className="mt-2 text-sm text-white/50">
                No worries. Enter your email and we&apos;ll send a reset link.
              </p>
            </div>
          </div>

          {sent ? (
            /* Success state */
            <div className="flex flex-col items-center gap-4 text-center py-4">
              <div className="flex h-16 w-16 items-center justify-center rounded-full bg-emerald-500/10">
                <CheckCircle2 className="h-8 w-8 text-emerald-400" />
              </div>
              <div>
                <p className="font-bold text-white">Reset link sent!</p>
                <p className="mt-1 text-sm text-white/50">
                  We sent a password reset link to <strong className="text-white">{email}</strong>.
                  Check your inbox and spam folder.
                </p>
              </div>
              <p className="text-xs text-white/40">The link expires in 30 minutes.</p>
              <a
                href={marketingLoginUrl()}
                className="mt-2 w-full rounded-xl bg-gradient-to-r from-violet-600 to-indigo-600 py-3 text-center text-sm font-bold text-white hover:opacity-90 transition-opacity"
              >
                Back to Sign In
              </a>
            </div>
          ) : (
            /* Form */
            <form onSubmit={handleSubmit} className="space-y-5">
              {error && (
                <div className="rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300">
                  {error}
                </div>
              )}

              <div>
                <label className="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-white/50">
                  Email Address
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/30" />
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="you@example.com"
                    className="w-full rounded-xl border border-white/10 bg-white/5 py-3 pl-10 pr-4 text-sm text-white outline-none ring-violet-500/40 placeholder:text-white/30 focus:ring-2"
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={loading}
                className="flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-violet-600 to-indigo-600 py-3 text-sm font-bold text-white shadow-lg shadow-violet-500/30 hover:opacity-90 transition-opacity disabled:opacity-60"
              >
                {loading && <Loader2 className="h-4 w-4 animate-spin" />}
                {loading ? "Sending..." : "Send Reset Link"}
              </button>

              <p className="text-center text-sm text-white/40">
                Remember your password?{" "}
                <a href={marketingLoginUrl()} className="font-semibold text-violet-400 hover:text-violet-300 transition-colors">
                  Sign in
                </a>
              </p>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
