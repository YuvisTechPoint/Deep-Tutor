/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  Bell,
  Brain,
  Check,
  Cpu,
  Globe,
  Key,
  Lock,
  Mail,
  Save,
  Settings,
  Shield,
  Sliders,
  ToggleLeft,
  ToggleRight,
  Users,
} from "lucide-react";

type Tab = "general" | "ai" | "security" | "email" | "integrations";

const TAB_CONFIG: { id: Tab; label: string; icon: React.ReactNode }[] = [
  { id: "general",      label: "General",      icon: <Settings className="h-4 w-4" />  },
  { id: "ai",           label: "AI Models",    icon: <Brain className="h-4 w-4" />     },
  { id: "security",     label: "Security",     icon: <Shield className="h-4 w-4" />    },
  { id: "email",        label: "Email",        icon: <Mail className="h-4 w-4" />      },
  { id: "integrations", label: "Integrations", icon: <Globe className="h-4 w-4" />     },
];

function Toggle({ enabled, onChange }: { enabled: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      onClick={() => onChange(!enabled)}
      className={`relative flex h-6 w-11 items-center rounded-full transition-colors ${enabled ? "bg-violet-600" : "bg-white/20"}`}
    >
      <div className={`absolute h-4 w-4 rounded-full bg-white shadow transition-transform ${enabled ? "translate-x-6" : "translate-x-1"}`} />
    </button>
  );
}

function SettingRow({ label, description, children }: { label: string; description?: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 rounded-xl border border-white/5 bg-white/3 px-5 py-4">
      <div>
        <p className="text-sm font-medium text-[var(--foreground)]">{label}</p>
        {description && <p className="mt-0.5 text-xs text-[var(--muted-foreground)]">{description}</p>}
      </div>
      <div className="shrink-0">{children}</div>
    </div>
  );
}

function TextInput({ label, value, onChange, placeholder }: {
  label: string; value: string; onChange: (v: string) => void; placeholder?: string;
}) {
  return (
    <div>
      <label className="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">{label}</label>
      <input
        value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder}
        className="w-full rounded-xl border border-white/5 bg-[var(--background)]/40 px-4 py-2.5 text-sm text-[var(--foreground)] outline-none ring-violet-500/30 placeholder:text-[var(--muted-foreground)] focus:ring-2"
      />
    </div>
  );
}

export default function AdminSettingsPage() {
  const [tab, setTab] = useState<Tab>("general");
  const [saved, setSaved] = useState(false);

  // General
  const [appName, setAppName] = useState("DeepTutor");
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [voiceMode, setVoiceMode] = useState(true);
  const [recruiterAccess, setRecruiterAccess] = useState(true);
  const [mentorMode, setMentorMode] = useState(true);
  const [maxUpload, setMaxUpload] = useState("50");
  const [sessionTimeout, setSessionTimeout] = useState("24");

  // AI
  const [defaultProvider, setDefaultProvider] = useState("huggingface");
  const [safetyThreshold, setSafetyThreshold] = useState(75);
  const [freeRateLimit, setFreeRateLimit] = useState("5");
  const [proRateLimit, setProRateLimit] = useState("unlimited");

  // Security
  const [jwtExpiry, setJwtExpiry] = useState("24");
  const [mfaRequired, setMfaRequired] = useState(false);
  const [ipAllowlist, setIpAllowlist] = useState("");
  const [rateLimit, setRateLimit] = useState("100");

  // Email
  const [smtpHost, setSmtpHost] = useState("smtp.sendgrid.net");
  const [smtpPort, setSmtpPort] = useState("587");
  const [fromEmail, setFromEmail] = useState("noreply@deeptutor.ai");

  const handleSave = async () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  };

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-5xl flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-gray-500 to-slate-600 shadow-lg">
              <Settings className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">System Settings</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">Platform configuration & feature flags</p>
            </div>
          </div>
          <button
            onClick={handleSave}
            className={`flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-semibold transition-all ${
              saved
                ? "bg-emerald-600 text-white"
                : "bg-violet-600 text-white hover:bg-violet-500"
            }`}
          >
            {saved ? <Check className="h-4 w-4" /> : <Save className="h-4 w-4" />}
            {saved ? "Saved!" : "Save Changes"}
          </button>
        </div>
      </header>

      <div className="flex-1 overflow-hidden flex">
        {/* Sidebar tabs */}
        <div className="w-48 shrink-0 border-r border-white/5 bg-[var(--secondary)] p-4">
          <div className="space-y-1">
            {TAB_CONFIG.map((t) => (
              <button
                key={t.id}
                onClick={() => setTab(t.id)}
                className={`flex w-full items-center gap-2.5 rounded-xl px-3 py-2.5 text-sm font-medium transition-colors ${
                  tab === t.id
                    ? "bg-violet-600/20 text-violet-300"
                    : "text-[var(--muted-foreground)] hover:bg-white/5 hover:text-[var(--foreground)]"
                }`}
              >
                {t.icon} {t.label}
              </button>
            ))}
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          <div className="mx-auto max-w-2xl space-y-4">
            {tab === "general" && (
              <>
                <TextInput label="Platform Name" value={appName} onChange={setAppName} placeholder="DeepTutor" />
                <TextInput label="Max Upload Size (MB)" value={maxUpload} onChange={setMaxUpload} placeholder="50" />
                <TextInput label="Session Timeout (hours)" value={sessionTimeout} onChange={setSessionTimeout} placeholder="24" />
                <div className="space-y-3 pt-2">
                  <p className="text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Feature Flags</p>
                  <SettingRow label="Voice Tutor Mode" description="Enable Whisper + XTTS voice learning features">
                    <Toggle enabled={voiceMode} onChange={setVoiceMode} />
                  </SettingRow>
                  <SettingRow label="Recruiter Access" description="Allow recruiter accounts to view learner profiles">
                    <Toggle enabled={recruiterAccess} onChange={setRecruiterAccess} />
                  </SettingRow>
                  <SettingRow label="Mentor Dashboard" description="Enable cohort management for mentors">
                    <Toggle enabled={mentorMode} onChange={setMentorMode} />
                  </SettingRow>
                  <SettingRow label="Maintenance Mode" description="Show maintenance banner to all users">
                    <Toggle enabled={maintenanceMode} onChange={setMaintenanceMode} />
                  </SettingRow>
                </div>
              </>
            )}

            {tab === "ai" && (
              <>
                <div>
                  <label className="mb-1.5 block text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Default LLM Provider</label>
                  <select
                    value={defaultProvider} onChange={(e) => setDefaultProvider(e.target.value)}
                    className="w-full rounded-xl border border-white/5 bg-[var(--background)]/40 px-4 py-2.5 text-sm text-[var(--foreground)] outline-none"
                  >
                    <option value="huggingface" className="bg-black">Hugging Face (router.huggingface.co)</option>
                    <option value="openai" className="bg-black">OpenAI API</option>
                    <option value="local" className="bg-black">Local (Ollama / vLLM)</option>
                  </select>
                </div>

                <div>
                  <label className="mb-2 block text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
                    Safety Threshold: {safetyThreshold}%
                  </label>
                  <input
                    type="range" min={50} max={99} value={safetyThreshold}
                    onChange={(e) => setSafetyThreshold(Number(e.target.value))}
                    className="w-full accent-violet-500"
                  />
                  <div className="mt-1 flex justify-between text-[10px] text-[var(--muted-foreground)]">
                    <span>Permissive (50%)</span>
                    <span>Strict (99%)</span>
                  </div>
                </div>

                <TextInput label="Free Tier: AI Requests / Day" value={freeRateLimit} onChange={setFreeRateLimit} placeholder="5" />
                <TextInput label="Pro Tier: AI Requests / Day" value={proRateLimit} onChange={setProRateLimit} placeholder="unlimited" />

                <div className="rounded-xl border border-violet-500/20 bg-violet-500/5 p-4 text-sm text-violet-300">
                  <Cpu className="mb-1 h-4 w-4" />
                  Current active provider: <strong>huggingface</strong> · Model: <strong>Qwen/Qwen3-32B</strong>
                </div>
              </>
            )}

            {tab === "security" && (
              <>
                <TextInput label="JWT Token Expiry (hours)" value={jwtExpiry} onChange={setJwtExpiry} placeholder="24" />
                <TextInput label="API Rate Limit (req/min)" value={rateLimit} onChange={setRateLimit} placeholder="100" />
                <TextInput label="IP Allowlist (comma-separated)" value={ipAllowlist} onChange={setIpAllowlist} placeholder="192.168.1.0/24, 10.0.0.0/8" />
                <SettingRow label="Require MFA for Admin" description="Force multi-factor authentication for admin accounts">
                  <Toggle enabled={mfaRequired} onChange={setMfaRequired} />
                </SettingRow>
                <div className="rounded-xl border border-white/5 bg-white/3 p-4">
                  <p className="mb-3 text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Enabled Auth Methods</p>
                  <div className="space-y-2">
                    {[
                      { label: "Email + Password", icon: <Key className="h-3.5 w-3.5" />, active: true },
                      { label: "Google OAuth", icon: <Globe className="h-3.5 w-3.5" />, active: true },
                      { label: "GitHub OAuth", icon: <Globe className="h-3.5 w-3.5" />, active: true },
                      { label: "Institution SSO", icon: <Users className="h-3.5 w-3.5" />, active: true },
                      { label: "Magic Link", icon: <Mail className="h-3.5 w-3.5" />, active: false },
                    ].map((m) => (
                      <div key={m.label} className="flex items-center gap-2 text-sm">
                        <div className={`flex h-5 w-5 items-center justify-center ${m.active ? "text-emerald-400" : "text-white/30"}`}>{m.icon}</div>
                        <span className={m.active ? "text-[var(--foreground)]" : "text-[var(--muted-foreground)]"}>{m.label}</span>
                        <span className={`ml-auto text-xs font-semibold ${m.active ? "text-emerald-400" : "text-white/30"}`}>{m.active ? "Enabled" : "Disabled"}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </>
            )}

            {tab === "email" && (
              <>
                <TextInput label="SMTP Host" value={smtpHost} onChange={setSmtpHost} placeholder="smtp.sendgrid.net" />
                <TextInput label="SMTP Port" value={smtpPort} onChange={setSmtpPort} placeholder="587" />
                <TextInput label="From Email" value={fromEmail} onChange={setFromEmail} placeholder="noreply@deeptutor.ai" />
                <div className="space-y-3">
                  <p className="text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Email Notifications</p>
                  {[
                    { label: "Streak reminders", desc: "Daily reminder when streak is at risk" },
                    { label: "Achievement unlocks", desc: "Email when a new badge is earned" },
                    { label: "Mentor messages", desc: "Forward mentor notes to email" },
                    { label: "Weekly digest", desc: "Weekly performance summary email" },
                  ].map((n) => (
                    <SettingRow key={n.label} label={n.label} description={n.desc}>
                      <Toggle enabled={true} onChange={() => {}} />
                    </SettingRow>
                  ))}
                </div>
              </>
            )}

            {tab === "integrations" && (
              <div className="space-y-3">
                {[
                  { name: "Hugging Face Hub", status: "Connected", desc: "LLM inference via HF router", color: "text-emerald-400" },
                  { name: "Qdrant Vector DB", status: "Connected", desc: "Knowledge base embeddings", color: "text-emerald-400" },
                  { name: "PostgreSQL", status: "Connected", desc: "Primary user/session data", color: "text-emerald-400" },
                  { name: "Redis Cache", status: "Connected", desc: "Session + rate limiting cache", color: "text-emerald-400" },
                  { name: "AWS S3", status: "Connected", desc: "File storage & uploads", color: "text-emerald-400" },
                  { name: "Neo4j", status: "Disconnected", desc: "Knowledge graph (optional)", color: "text-amber-400" },
                  { name: "ClickHouse", status: "Disconnected", desc: "Analytics events (optional)", color: "text-amber-400" },
                  { name: "Slack Webhooks", status: "Not configured", desc: "Team alerts & notifications", color: "text-white/40" },
                ].map((int) => (
                  <div key={int.name} className="flex items-center gap-4 rounded-xl border border-white/5 bg-white/3 px-5 py-4">
                    <div className="flex-1">
                      <p className="text-sm font-medium text-[var(--foreground)]">{int.name}</p>
                      <p className="text-xs text-[var(--muted-foreground)]">{int.desc}</p>
                    </div>
                    <span className={`text-xs font-semibold ${int.color}`}>{int.status}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
