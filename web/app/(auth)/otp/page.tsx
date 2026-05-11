/* eslint-disable i18n/no-literal-ui-text */
"use client";

import Link from "next/link";
import { marketingLoginUrl } from "@/lib/external-auth";
import { useCallback, useEffect, useRef, useState } from "react";
import { ArrowLeft, Brain, CheckCircle2, Loader2, RefreshCw, Shield } from "lucide-react";

const OTP_LENGTH = 6;

export default function OTPPage() {
  const [digits, setDigits] = useState<string[]>(Array(OTP_LENGTH).fill(""));
  const [verifying, setVerifying] = useState(false);
  const [verified, setVerified] = useState(false);
  const [error, setError] = useState("");
  const [countdown, setCountdown] = useState(59);
  const [canResend, setCanResend] = useState(false);
  const inputsRef = useRef<Array<HTMLInputElement | null>>([]);

  useEffect(() => {
    if (countdown <= 0) { setCanResend(true); return; }
    const t = setTimeout(() => setCountdown((c) => c - 1), 1000);
    return () => clearTimeout(t);
  }, [countdown]);

  const handleChange = useCallback((idx: number, value: string) => {
    if (!/^\d*$/.test(value)) return;
    const char = value.slice(-1);
    setDigits((prev) => {
      const next = [...prev];
      next[idx] = char;
      return next;
    });
    setError("");
    if (char && idx < OTP_LENGTH - 1) {
      inputsRef.current[idx + 1]?.focus();
    }
  }, []);

  const handleKeyDown = useCallback((idx: number, e: React.KeyboardEvent) => {
    if (e.key === "Backspace" && !digits[idx] && idx > 0) {
      inputsRef.current[idx - 1]?.focus();
    }
  }, [digits]);

  const handlePaste = useCallback((e: React.ClipboardEvent) => {
    e.preventDefault();
    const pasted = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, OTP_LENGTH);
    if (!pasted) return;
    const next = Array(OTP_LENGTH).fill("");
    pasted.split("").forEach((c, i) => { next[i] = c; });
    setDigits(next);
    inputsRef.current[Math.min(pasted.length, OTP_LENGTH - 1)]?.focus();
  }, []);

  const isFull = digits.every((d) => d !== "");

  const handleVerify = async () => {
    if (!isFull) return;
    setVerifying(true);
    setError("");
    await new Promise((r) => setTimeout(r, 1500));
    const code = digits.join("");
    if (code === "123456") {
      setVerified(true);
    } else {
      setError("Invalid code. Please try again.");
      setDigits(Array(OTP_LENGTH).fill(""));
      inputsRef.current[0]?.focus();
    }
    setVerifying(false);
  };

  const handleResend = () => {
    setCanResend(false);
    setCountdown(59);
    setDigits(Array(OTP_LENGTH).fill(""));
    setError("");
    inputsRef.current[0]?.focus();
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#030303] px-4">
      <div className="pointer-events-none fixed inset-0">
        <div className="absolute left-1/2 top-1/3 h-96 w-96 -translate-x-1/2 rounded-full bg-emerald-600/10 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        <a
          href={marketingLoginUrl()}
          className="mb-6 flex items-center gap-2 text-sm text-white/50 hover:text-white transition-colors"
        >
          <ArrowLeft className="h-4 w-4" /> Back
        </a>

        <div className="rounded-2xl border border-white/10 bg-white/3 p-8 backdrop-blur-xl shadow-2xl">
          <div className="mb-8 flex flex-col items-center gap-3">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 shadow-xl shadow-emerald-500/30">
              <Shield className="h-7 w-7 text-white" />
            </div>
            <div className="text-center">
              <div className="mb-1 flex items-center justify-center gap-2">
                <Brain className="h-4 w-4 text-violet-400" />
                <span className="text-sm font-semibold text-violet-400">DeepTutor</span>
              </div>
              <h1 className="text-2xl font-black text-white">Enter verification code</h1>
              <p className="mt-2 text-sm text-white/50">
                We sent a 6-digit code to <strong className="text-white">a****@example.com</strong>
              </p>
            </div>
          </div>

          {verified ? (
            <div className="flex flex-col items-center gap-4 text-center py-4">
              <div className="flex h-16 w-16 items-center justify-center rounded-full bg-emerald-500/10">
                <CheckCircle2 className="h-8 w-8 text-emerald-400" />
              </div>
              <div>
                <p className="font-bold text-white">Verified successfully!</p>
                <p className="mt-1 text-sm text-white/50">Redirecting you to your account...</p>
              </div>
              <Link
                href="/chat"
                className="mt-2 w-full rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 py-3 text-center text-sm font-bold text-white hover:opacity-90 transition-opacity"
              >
                Continue
              </Link>
            </div>
          ) : (
            <div className="space-y-6">
              {error && (
                <div className="rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-center text-sm text-red-300">
                  {error}
                </div>
              )}

              {/* Digit inputs */}
              <div className="flex justify-center gap-3" onPaste={handlePaste}>
                {digits.map((d, i) => (
                  <input
                    key={i}
                    ref={(el) => { inputsRef.current[i] = el; }}
                    type="text"
                    inputMode="numeric"
                    maxLength={1}
                    value={d}
                    onChange={(e) => handleChange(i, e.target.value)}
                    onKeyDown={(e) => handleKeyDown(i, e)}
                    className={`h-14 w-12 rounded-xl border bg-white/5 text-center text-xl font-black text-white outline-none transition-all ${
                      d ? "border-violet-500 shadow-lg shadow-violet-500/20" : "border-white/10"
                    } focus:border-violet-500 focus:ring-2 focus:ring-violet-500/30`}
                  />
                ))}
              </div>

              <button
                onClick={handleVerify}
                disabled={!isFull || verifying}
                className="flex w-full items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-violet-600 to-indigo-600 py-3 text-sm font-bold text-white shadow-lg shadow-violet-500/30 hover:opacity-90 transition-opacity disabled:opacity-40"
              >
                {verifying && <Loader2 className="h-4 w-4 animate-spin" />}
                {verifying ? "Verifying..." : "Verify Code"}
              </button>

              <div className="text-center text-sm">
                {canResend ? (
                  <button
                    onClick={handleResend}
                    className="flex items-center justify-center gap-1.5 text-violet-400 hover:text-violet-300 transition-colors mx-auto"
                  >
                    <RefreshCw className="h-4 w-4" /> Resend code
                  </button>
                ) : (
                  <p className="text-white/40">
                    Resend code in{" "}
                    <span className="font-mono text-white/60">
                      00:{String(countdown).padStart(2, "0")}
                    </span>
                  </p>
                )}
              </div>

              <p className="text-center text-xs text-white/30">
                Demo: use <span className="font-mono text-white/50">123456</span> to verify
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
