/* eslint-disable i18n/no-literal-ui-text */
"use client";

import Link from "next/link";
import { marketingLoginUrl } from "@/lib/external-auth";
import { useState } from "react";
import { ArrowLeft, ArrowRight, Brain, Building2, Globe, Loader2, Lock, Mail } from "lucide-react";

export default function InstitutionLoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [domain, setDomain] = useState("");
  const [loading, setLoading] = useState(false);
  const [ssoLoading, setSsoLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    await new Promise((r) => setTimeout(r, 1500));
    setLoading(false);
  };

  const handleSSO = async () => {
    setSsoLoading(true);
    await new Promise((r) => setTimeout(r, 1000));
    setSsoLoading(false);
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#030303] px-4">
      <div className="pointer-events-none fixed inset-0">
        <div className="absolute left-1/4 top-1/3 h-80 w-80 rounded-full bg-blue-600/10 blur-3xl" />
        <div className="absolute right-1/4 top-1/4 h-64 w-64 rounded-full bg-violet-600/10 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        <a
          href={marketingLoginUrl()}
          className="mb-6 flex items-center gap-2 text-sm text-white/50 hover:text-white transition-colors"
        >
          <ArrowLeft className="h-4 w-4" /> Back to Sign In
        </a>

        <div className="rounded-2xl border border-white/10 bg-white/3 p-8 backdrop-blur-xl shadow-2xl">
          {/* Logo */}
          <div className="mb-6 flex flex-col items-center gap-3">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-600 shadow-xl shadow-blue-500/30">
              <Building2 className="h-7 w-7 text-white" />
            </div>
            <div className="text-center">
              <div className="mb-1 flex items-center justify-center gap-2">
                <Brain className="h-4 w-4 text-violet-400" />
                <span className="text-sm font-semibold text-violet-400">DeepTutor</span>
              </div>
              <h1 className="text-2xl font-black text-white">Institution Login</h1>
              <p className="mt-2 text-sm text-white/50">
                Sign in with your institution&apos;s credentials or SSO
              </p>
            </div>
          </div>

          {/* SSO button */}
          <button
            onClick={handleSSO}
            disabled={ssoLoading}
            className="mb-6 flex w-full items-center justify-center gap-2.5 rounded-xl border border-white/10 bg-white/5 py-3 text-sm font-semibold text-white hover:bg-white/10 transition-colors disabled:opacity-60"
          >
            {ssoLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Globe className="h-4 w-4 text-blue-400" />}
            Sign in with SSO
          </button>

          <div className="relative mb-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-white/10" />
            </div>
            <div className="relative flex justify-center">
              <span className="bg-[#030303] px-3 text-xs text-white/30">or use credentials</span>
            </div>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-white/50">Institution Domain</label>
              <div className="relative">
                <Globe className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/30" />
                <input
                  type="text"
                  value={domain}
                  onChange={(e) => setDomain(e.target.value)}
                  placeholder="university.edu or company.com"
                  className="w-full rounded-xl border border-white/10 bg-white/5 py-3 pl-10 pr-4 text-sm text-white outline-none ring-blue-500/40 placeholder:text-white/30 focus:ring-2"
                />
              </div>
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-white/50">Email Address</label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/30" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@university.edu"
                  className="w-full rounded-xl border border-white/10 bg-white/5 py-3 pl-10 pr-4 text-sm text-white outline-none ring-blue-500/40 placeholder:text-white/30 focus:ring-2"
                />
              </div>
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-white/50">Password</label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-white/30" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full rounded-xl border border-white/10 bg-white/5 py-3 pl-10 pr-4 text-sm text-white outline-none ring-blue-500/40 placeholder:text-white/30 focus:ring-2"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 py-3 text-sm font-bold text-white shadow-lg shadow-blue-500/30 hover:opacity-90 transition-opacity disabled:opacity-60"
            >
              {loading && <Loader2 className="h-4 w-4 animate-spin" />}
              {loading ? "Signing in..." : "Sign In"}
              {!loading && <ArrowRight className="h-4 w-4" />}
            </button>
          </form>

          <div className="mt-6 rounded-xl border border-white/5 bg-white/3 px-4 py-3 text-center">
            <p className="text-xs text-white/40">
              Need help? Contact your institution&apos;s IT administrator or{" "}
              <a
                href="https://github.com/HKUDS/DeepTutor"
                target="_blank"
                rel="noopener noreferrer"
                className="text-blue-400 hover:text-blue-300 transition-colors"
              >
                DeepTutor on GitHub
              </a>
            </p>
          </div>

          <p className="mt-4 text-center text-sm text-white/40">
            Not an institution user?{" "}
            <a href={marketingLoginUrl()} className="font-semibold text-violet-400 hover:text-violet-300 transition-colors">
              Personal login
            </a>
          </p>
        </div>
      </div>
    </div>
  );
}
