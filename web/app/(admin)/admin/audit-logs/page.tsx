/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  AlertTriangle,
  Clock,
  Download,
  Filter,
  Globe,
  Search,
  Shield,
  User,
} from "lucide-react";

type ActionType = "login" | "profile_update" | "kb_create" | "chat_start" | "admin_action" | "model_config" | "file_upload";
type Status = "success" | "failed" | "warning";

interface LogEntry {
  id: string;
  timestamp: string;
  user: string;
  userRole: string;
  action: ActionType;
  resource: string;
  ip: string;
  status: Status;
  detail: string;
}

const ACTION_LABELS: Record<ActionType, { label: string; color: string }> = {
  login:        { label: "Login",         color: "text-blue-400 bg-blue-500/10 border-blue-500/20"     },
  profile_update:{ label: "Profile",      color: "text-violet-400 bg-violet-500/10 border-violet-500/20"},
  kb_create:    { label: "KB Create",     color: "text-teal-400 bg-teal-500/10 border-teal-500/20"     },
  chat_start:   { label: "Chat",          color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/20"},
  admin_action: { label: "Admin",         color: "text-orange-400 bg-orange-500/10 border-orange-500/20"},
  model_config: { label: "Model Config",  color: "text-indigo-400 bg-indigo-500/10 border-indigo-500/20"},
  file_upload:  { label: "File Upload",   color: "text-cyan-400 bg-cyan-500/10 border-cyan-500/20"     },
};

const STATUS_CONFIG: Record<Status, { label: string; color: string }> = {
  success: { label: "Success", color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/20" },
  failed:  { label: "Failed",  color: "text-red-400 bg-red-500/10 border-red-500/20"           },
  warning: { label: "Warning", color: "text-amber-400 bg-amber-500/10 border-amber-500/20"      },
};

const LOGS: LogEntry[] = [
  { id: "l1",  timestamp: "2026-05-11 14:32:18", user: "aisha.raza@example.com",   userRole: "learner", action: "chat_start",    resource: "/api/v1/chat",         ip: "103.21.44.12", status: "success", detail: "Chat session started with intent: CODING" },
  { id: "l2",  timestamp: "2026-05-11 14:28:51", user: "admin@deeptutor.ai",        userRole: "admin",   action: "model_config",  resource: "/admin/model-routing", ip: "172.16.0.1",   status: "success", detail: "Disabled microsoft/trocr-large-handwritten model" },
  { id: "l3",  timestamp: "2026-05-11 14:15:22", user: "unknown@evil.com",          userRole: "—",       action: "login",         resource: "/api/v1/auth/login",   ip: "185.220.101.x",status: "failed",  detail: "Invalid credentials — 5 consecutive failed attempts" },
  { id: "l4",  timestamp: "2026-05-11 13:58:09", user: "julia.novak@lewagon.com",   userRole: "mentor",  action: "profile_update",resource: "/api/v1/users/12",     ip: "87.106.12.33", status: "success", detail: "Updated cohort assignment for learner: priya.sharma" },
  { id: "l5",  timestamp: "2026-05-11 13:45:33", user: "marcus.chen@email.com",     userRole: "learner", action: "file_upload",   resource: "/api/knowledge/upload",ip: "72.34.88.11",  status: "success", detail: "Uploaded: system_design_notes.pdf (2.4MB)" },
  { id: "l6",  timestamp: "2026-05-11 13:30:47", user: "recruiter@techcorp.com",    userRole: "recruiter",action: "login",        resource: "/api/v1/auth/login",   ip: "198.51.100.4", status: "success", detail: "Recruiter login from new IP — email verified" },
  { id: "l7",  timestamp: "2026-05-11 12:55:12", user: "raj.patel@email.com",       userRole: "learner", action: "chat_start",    resource: "/api/v1/chat",         ip: "117.98.33.44", status: "success", detail: "Chat session: 47 messages, intent MATH, 23min" },
  { id: "l8",  timestamp: "2026-05-11 12:22:38", user: "admin@deeptutor.ai",        userRole: "admin",   action: "admin_action",  resource: "/admin/users",         ip: "172.16.0.1",   status: "success", detail: "Suspended user: spam.bot@fake.com — policy violation" },
  { id: "l9",  timestamp: "2026-05-11 11:48:55", user: "sara.kim@university.edu",   userRole: "learner", action: "kb_create",     resource: "/api/v1/knowledge",    ip: "210.22.15.9",  status: "success", detail: "Knowledge base created: ML-Paper-Collection (5 docs)" },
  { id: "l10", timestamp: "2026-05-11 11:15:22", user: "mei.lin@nus.edu.sg",        userRole: "learner", action: "login",         resource: "/api/v1/auth/login",   ip: "137.132.5.10", status: "warning", detail: "Login from new device — 2FA required, completed via OTP" },
  { id: "l11", timestamp: "2026-05-11 10:44:16", user: "ahmed.hassan@email.com",    userRole: "learner", action: "chat_start",    resource: "/api/v1/chat",         ip: "197.210.55.2", status: "success", detail: "Chat session: voice mode enabled, Whisper transcription" },
  { id: "l12", timestamp: "2026-05-11 10:12:09", user: "admin@deeptutor.ai",        userRole: "admin",   action: "model_config",  resource: "/admin/model-routing", ip: "172.16.0.1",   status: "success", detail: "Updated HF_TOKEN — all model connections revalidated" },
  { id: "l13", timestamp: "2026-05-11 09:38:44", user: "probe@attacker.net",        userRole: "—",       action: "login",         resource: "/api/v1/auth/login",   ip: "95.181.182.3", status: "failed",  detail: "Brute force detected — IP blocked for 24h" },
  { id: "l14", timestamp: "2026-05-11 09:05:21", user: "david.okafor@school.ng",    userRole: "learner", action: "kb_create",     resource: "/api/v1/knowledge",    ip: "197.255.20.1", status: "success", detail: "Knowledge base: University Entrance Prep (12 docs)" },
  { id: "l15", timestamp: "2026-05-11 08:32:07", user: "julia.novak@lewagon.com",   userRole: "mentor",  action: "admin_action",  resource: "/mentor/intervention", ip: "87.106.12.33", status: "success", detail: "Intervention plan created for learner: david.okafor" },
];

const SUSPICIOUS_ALERTS = [
  { user: "unknown@evil.com",   action: "5 consecutive failed login attempts", ip: "185.220.101.x", time: "14:15", severity: "high" },
  { user: "probe@attacker.net", action: "Brute force attack detected and blocked", ip: "95.181.182.3", time: "09:38", severity: "critical" },
  { user: "mei.lin@nus.edu.sg", action: "Login from unrecognized device — OTP required", ip: "137.132.5.10", time: "11:15", severity: "low" },
];

export default function AuditLogsPage() {
  const [search, setSearch] = useState("");
  const [actionFilter, setActionFilter] = useState<ActionType | "all">("all");
  const [statusFilter, setStatusFilter] = useState<Status | "all">("all");

  const filtered = LOGS.filter((l) => {
    const matchSearch =
      l.user.toLowerCase().includes(search.toLowerCase()) ||
      l.detail.toLowerCase().includes(search.toLowerCase()) ||
      l.ip.includes(search);
    const matchAction = actionFilter === "all" || l.action === actionFilter;
    const matchStatus = statusFilter === "all" || l.status === statusFilter;
    return matchSearch && matchAction && matchStatus;
  });

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-6xl flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-slate-500 to-gray-600 shadow-lg">
              <Shield className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">Audit Logs</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">{LOGS.length} entries today · 3 security alerts</p>
            </div>
          </div>
          <button className="flex items-center gap-1.5 rounded-lg bg-white/5 px-3 py-1.5 text-xs text-[var(--muted-foreground)] hover:bg-white/10 transition-colors">
            <Download className="h-3.5 w-3.5" /> Export CSV
          </button>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-6xl space-y-5 px-4 py-5 sm:px-6">
          {/* Security alerts */}
          <div className="rounded-xl border border-red-500/20 bg-red-500/5 p-4">
            <div className="mb-3 flex items-center gap-2">
              <AlertTriangle className="h-4 w-4 text-red-400" />
              <span className="text-sm font-semibold text-red-400">Security Alerts ({SUSPICIOUS_ALERTS.length})</span>
            </div>
            <div className="space-y-2">
              {SUSPICIOUS_ALERTS.map((a, i) => (
                <div key={i} className={`flex items-center gap-3 rounded-lg px-3 py-2 text-xs ${
                  a.severity === "critical" ? "bg-red-500/10 border border-red-500/20"
                  : a.severity === "high" ? "bg-orange-500/10 border border-orange-500/20"
                  : "bg-amber-500/10 border border-amber-500/20"
                }`}>
                  <span className={`font-mono text-[10px] font-bold px-1.5 py-0.5 rounded uppercase ${
                    a.severity === "critical" ? "text-red-400"
                    : a.severity === "high" ? "text-orange-400"
                    : "text-amber-400"
                  }`}>{a.severity}</span>
                  <span className="text-[var(--muted-foreground)] flex-1">{a.user}</span>
                  <span className="text-[var(--foreground)]">{a.action}</span>
                  <span className="flex items-center gap-1 text-[var(--muted-foreground)]"><Globe className="h-3 w-3" />{a.ip}</span>
                  <span className="text-[var(--muted-foreground)]"><Clock className="h-3 w-3 inline mr-0.5" />{a.time}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Filters */}
          <div className="flex flex-col gap-3 sm:flex-row">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--muted-foreground)]" />
              <input
                value={search} onChange={(e) => setSearch(e.target.value)}
                placeholder="Search by user, IP, or action..."
                className="w-full rounded-xl border border-white/5 bg-[var(--secondary)] py-2.5 pl-10 pr-4 text-sm text-[var(--foreground)] outline-none ring-violet-500/30 placeholder:text-[var(--muted-foreground)] focus:ring-2"
              />
            </div>
            <div className="flex gap-2">
              <select
                value={actionFilter}
                onChange={(e) => setActionFilter(e.target.value as ActionType | "all")}
                className="rounded-xl border border-white/5 bg-[var(--secondary)] px-3 py-2 text-sm text-[var(--foreground)] outline-none"
              >
                <option value="all">All Actions</option>
                {Object.keys(ACTION_LABELS).map((a) => (
                  <option key={a} value={a} className="bg-black">{ACTION_LABELS[a as ActionType].label}</option>
                ))}
              </select>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value as Status | "all")}
                className="rounded-xl border border-white/5 bg-[var(--secondary)] px-3 py-2 text-sm text-[var(--foreground)] outline-none"
              >
                <option value="all">All Statuses</option>
                <option value="success" className="bg-black">Success</option>
                <option value="failed" className="bg-black">Failed</option>
                <option value="warning" className="bg-black">Warning</option>
              </select>
            </div>
          </div>

          {/* Log table */}
          <div className="overflow-hidden rounded-2xl border border-white/5 bg-[var(--secondary)]">
            <div className="overflow-x-auto">
              <table className="w-full text-xs">
                <thead>
                  <tr className="border-b border-white/5 bg-white/3">
                    <th className="px-4 py-3 text-left font-semibold text-[var(--muted-foreground)]">Timestamp</th>
                    <th className="px-4 py-3 text-left font-semibold text-[var(--muted-foreground)]">User</th>
                    <th className="px-4 py-3 text-left font-semibold text-[var(--muted-foreground)]">Action</th>
                    <th className="hidden px-4 py-3 text-left font-semibold text-[var(--muted-foreground)] sm:table-cell">Resource</th>
                    <th className="hidden px-4 py-3 text-left font-semibold text-[var(--muted-foreground)] md:table-cell">IP</th>
                    <th className="px-4 py-3 text-left font-semibold text-[var(--muted-foreground)]">Status</th>
                    <th className="hidden px-4 py-3 text-left font-semibold text-[var(--muted-foreground)] lg:table-cell">Detail</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map((l, i) => {
                    const ac = ACTION_LABELS[l.action];
                    const sc = STATUS_CONFIG[l.status];
                    return (
                      <tr key={l.id} className={`border-b border-white/5 ${i % 2 === 0 ? "" : "bg-white/1"} ${l.status === "failed" ? "bg-red-500/3" : ""}`}>
                        <td className="px-4 py-2.5 font-mono text-[var(--muted-foreground)] whitespace-nowrap">{l.timestamp.split(" ")[1]}</td>
                        <td className="px-4 py-2.5">
                          <div className="flex items-center gap-1.5">
                            <User className="h-3 w-3 text-[var(--muted-foreground)]" />
                            <div>
                              <p className="text-[var(--foreground)] truncate max-w-[120px]">{l.user.split("@")[0]}</p>
                              <p className="text-[var(--muted-foreground)] text-[10px] capitalize">{l.userRole}</p>
                            </div>
                          </div>
                        </td>
                        <td className="px-4 py-2.5">
                          <span className={`rounded-full border px-2 py-0.5 font-semibold ${ac.color}`}>{ac.label}</span>
                        </td>
                        <td className="hidden px-4 py-2.5 font-mono text-[var(--muted-foreground)] sm:table-cell truncate max-w-[160px]">{l.resource}</td>
                        <td className="hidden px-4 py-2.5 font-mono md:table-cell">
                          <div className="flex items-center gap-1 text-[var(--muted-foreground)]">
                            <Globe className="h-3 w-3" />
                            {l.ip}
                          </div>
                        </td>
                        <td className="px-4 py-2.5">
                          <span className={`rounded-full border px-2 py-0.5 font-semibold ${sc.color}`}>{sc.label}</span>
                        </td>
                        <td className="hidden px-4 py-2.5 text-[var(--muted-foreground)] lg:table-cell truncate max-w-[220px]">{l.detail}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>

          <p className="text-center text-xs text-[var(--muted-foreground)]">
            Showing {filtered.length} of {LOGS.length} log entries · Logs are retained for 90 days
          </p>
        </div>
      </div>
    </div>
  );
}
