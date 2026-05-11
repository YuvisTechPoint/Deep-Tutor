/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  ArrowRight,
  Building2,
  CheckCircle2,
  Edit3,
  Mail,
  PauseCircle,
  Plus,
  Settings,
  Users,
  X,
} from "lucide-react";

interface Institution {
  id: string;
  name: string;
  adminEmail: string;
  plan: "free" | "pro" | "team" | "enterprise";
  learnerCount: number;
  seatCount: number;
  active: boolean;
  createdAt: string;
  domain: string;
}

const PLAN_CONFIG = {
  free:       { label: "Free",       color: "text-white/50 bg-white/5 border-white/10"        },
  pro:        { label: "Pro",        color: "text-blue-400 bg-blue-500/10 border-blue-500/20"  },
  team:       { label: "Team",       color: "text-violet-400 bg-violet-500/10 border-violet-500/20"},
  enterprise: { label: "Enterprise", color: "text-amber-400 bg-amber-500/10 border-amber-500/20"},
};

const INSTITUTIONS: Institution[] = [
  { id: "i1", name: "Le Wagon Berlin",    adminEmail: "admin@lewagon.com",      plan: "team",       learnerCount: 128, seatCount: 200,  active: true,  createdAt: "Jan 2026", domain: "lewagon.com" },
  { id: "i2", name: "IIT Delhi",          adminEmail: "coordinator@iitd.ac.in", plan: "enterprise", learnerCount: 234, seatCount: 500,  active: true,  createdAt: "Feb 2026", domain: "iitd.ac.in" },
  { id: "i3", name: "NUS Singapore",      adminEmail: "elearning@nus.edu.sg",   plan: "team",       learnerCount: 87,  seatCount: 150,  active: true,  createdAt: "Mar 2026", domain: "nus.edu.sg" },
  { id: "i4", name: "Tech Bootcamp Lagos", adminEmail: "admin@techlagos.io",    plan: "pro",        learnerCount: 34,  seatCount: 50,   active: false, createdAt: "Apr 2026", domain: "techlagos.io" },
];

export default function InstitutionsPage() {
  const [showForm, setShowForm] = useState(false);
  const [institutions, setInstitutions] = useState<Institution[]>(INSTITUTIONS);

  // Form state
  const [formName, setFormName] = useState("");
  const [formEmail, setFormEmail] = useState("");
  const [formPlan, setFormPlan] = useState<Institution["plan"]>("team");
  const [formSeats, setFormSeats] = useState("100");

  const totalLearners = institutions.reduce((s, i) => s + i.learnerCount, 0);
  const totalSeats = institutions.reduce((s, i) => s + i.seatCount, 0);
  const activeCount = institutions.filter((i) => i.active).length;

  const toggleActive = (id: string) =>
    setInstitutions((prev) => prev.map((i) => i.id === id ? { ...i, active: !i.active } : i));

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const newInst: Institution = {
      id: `i${institutions.length + 1}`,
      name: formName || "New Institution",
      adminEmail: formEmail || "admin@example.com",
      plan: formPlan,
      learnerCount: 0,
      seatCount: Number(formSeats),
      active: true,
      createdAt: "May 2026",
      domain: formEmail.split("@")[1] || "example.com",
    };
    setInstitutions((prev) => [newInst, ...prev]);
    setShowForm(false);
    setFormName(""); setFormEmail(""); setFormSeats("100");
  };

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-5xl flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 shadow-lg">
              <Building2 className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">Institution Management</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">
                {institutions.length} institutions · {totalLearners} learners · {totalSeats} seats
              </p>
            </div>
          </div>
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2 text-sm font-semibold text-white hover:bg-violet-500 transition-colors"
          >
            <Plus className="h-4 w-4" /> Add Institution
          </button>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-5xl space-y-6 px-4 py-6 sm:px-6">
          {/* Stats */}
          <div className="grid grid-cols-3 gap-4">
            {[
              { label: "Total Institutions", value: institutions.length,  icon: <Building2 className="h-5 w-5" />, color: "text-violet-400" },
              { label: "Active Learners",    value: totalLearners,        icon: <Users className="h-5 w-5" />,    color: "text-emerald-400" },
              { label: "Total Seats",        value: totalSeats,           icon: <CheckCircle2 className="h-5 w-5" />, color: "text-blue-400" },
            ].map((s) => (
              <div key={s.label} className="rounded-xl border border-white/5 bg-[var(--secondary)] p-4">
                <div className={`mb-1 ${s.color}`}>{s.icon}</div>
                <p className={`text-2xl font-black ${s.color}`}>{s.value}</p>
                <p className="text-[10px] text-[var(--muted-foreground)]">{s.label}</p>
              </div>
            ))}
          </div>

          {/* Institution cards */}
          <div className="space-y-4">
            {institutions.map((inst) => {
              const pc = PLAN_CONFIG[inst.plan];
              const fillPct = Math.round((inst.learnerCount / inst.seatCount) * 100);
              return (
                <div
                  key={inst.id}
                  className={`rounded-2xl border bg-[var(--secondary)] p-6 transition-all ${
                    inst.active ? "border-white/5" : "border-white/3 opacity-60"
                  }`}
                >
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div className="flex items-center gap-4">
                      <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-indigo-600 text-xl font-bold text-white shadow-lg">
                        {inst.name.charAt(0)}
                      </div>
                      <div>
                        <div className="mb-1 flex items-center gap-2">
                          <h3 className="font-bold text-[var(--foreground)]">{inst.name}</h3>
                          <span className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${pc.color}`}>{pc.label}</span>
                          {inst.active
                            ? <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-semibold text-emerald-400">Active</span>
                            : <span className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] font-semibold text-white/40">Suspended</span>}
                        </div>
                        <div className="flex items-center gap-3 text-xs text-[var(--muted-foreground)]">
                          <span className="flex items-center gap-1"><Mail className="h-3 w-3" />{inst.adminEmail}</span>
                          <span className="flex items-center gap-1"><Building2 className="h-3 w-3" />{inst.domain}</span>
                          <span>Since {inst.createdAt}</span>
                        </div>
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-2">
                      <button className="flex items-center gap-1.5 rounded-lg bg-white/5 px-3 py-1.5 text-xs text-[var(--muted-foreground)] hover:bg-white/10 transition-colors">
                        <Edit3 className="h-3.5 w-3.5" /> Edit
                      </button>
                      <button className="flex items-center gap-1.5 rounded-lg bg-white/5 px-3 py-1.5 text-xs text-[var(--muted-foreground)] hover:bg-white/10 transition-colors">
                        <Settings className="h-3.5 w-3.5" /> Manage
                      </button>
                      <button
                        onClick={() => toggleActive(inst.id)}
                        className={`flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs transition-colors ${
                          inst.active
                            ? "bg-red-500/10 text-red-400 hover:bg-red-500/20"
                            : "bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20"
                        }`}
                      >
                        {inst.active ? <PauseCircle className="h-3.5 w-3.5" /> : <CheckCircle2 className="h-3.5 w-3.5" />}
                        {inst.active ? "Suspend" : "Activate"}
                      </button>
                    </div>
                  </div>

                  {/* Seat usage */}
                  <div className="mt-4">
                    <div className="mb-1.5 flex items-center justify-between text-xs">
                      <span className="text-[var(--muted-foreground)]">Seat utilization</span>
                      <span className="font-semibold text-[var(--foreground)]">{inst.learnerCount} / {inst.seatCount} ({fillPct}%)</span>
                    </div>
                    <div className="h-2 overflow-hidden rounded-full bg-white/10">
                      <div
                        className={`h-full rounded-full ${fillPct > 90 ? "bg-red-400" : fillPct > 70 ? "bg-amber-400" : "bg-violet-400"}`}
                        style={{ width: `${fillPct}%` }}
                      />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Add Institution panel */}
      {showForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm px-4">
          <div className="w-full max-w-md rounded-2xl border border-white/10 bg-[var(--secondary)] p-6 shadow-2xl">
            <div className="mb-5 flex items-center justify-between">
              <h2 className="font-bold text-[var(--foreground)]">Add New Institution</h2>
              <button onClick={() => setShowForm(false)} className="text-[var(--muted-foreground)] hover:text-[var(--foreground)]">
                <X className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="mb-1 block text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Institution Name</label>
                <input value={formName} onChange={(e) => setFormName(e.target.value)} placeholder="University / Bootcamp name"
                  className="w-full rounded-xl border border-white/5 bg-white/5 px-4 py-2.5 text-sm text-[var(--foreground)] outline-none ring-violet-500/30 focus:ring-2 placeholder:text-[var(--muted-foreground)]" />
              </div>
              <div>
                <label className="mb-1 block text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Admin Email</label>
                <input value={formEmail} onChange={(e) => setFormEmail(e.target.value)} type="email" placeholder="admin@institution.edu"
                  className="w-full rounded-xl border border-white/5 bg-white/5 px-4 py-2.5 text-sm text-[var(--foreground)] outline-none ring-violet-500/30 focus:ring-2 placeholder:text-[var(--muted-foreground)]" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="mb-1 block text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Plan</label>
                  <select value={formPlan} onChange={(e) => setFormPlan(e.target.value as Institution["plan"])}
                    className="w-full rounded-xl border border-white/5 bg-white/5 px-3 py-2.5 text-sm text-[var(--foreground)] outline-none">
                    <option value="pro" className="bg-black">Pro</option>
                    <option value="team" className="bg-black">Team</option>
                    <option value="enterprise" className="bg-black">Enterprise</option>
                  </select>
                </div>
                <div>
                  <label className="mb-1 block text-xs font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">Seat Count</label>
                  <input value={formSeats} onChange={(e) => setFormSeats(e.target.value)} type="number" min="10" placeholder="100"
                    className="w-full rounded-xl border border-white/5 bg-white/5 px-4 py-2.5 text-sm text-[var(--foreground)] outline-none ring-violet-500/30 focus:ring-2" />
                </div>
              </div>
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => setShowForm(false)}
                  className="flex-1 rounded-xl border border-white/5 bg-white/5 py-2.5 text-sm font-medium text-[var(--muted-foreground)] hover:bg-white/10 transition-colors">
                  Cancel
                </button>
                <button type="submit"
                  className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-violet-600 py-2.5 text-sm font-semibold text-white hover:bg-violet-500 transition-colors">
                  Add Institution <ArrowRight className="h-4 w-4" />
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
