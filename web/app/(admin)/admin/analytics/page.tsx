/* eslint-disable i18n/no-literal-ui-text */
"use client";

import {
  Activity,
  Brain,
  Clock,
  MessageSquare,
  Server,
  Shield,
  Star,
  TrendingUp,
  Users,
  Zap,
} from "lucide-react";

const DAU_DATA = [420, 510, 490, 580, 640, 720, 810, 760, 830, 910, 870, 950, 1020, 1100];
const LATENCY_DATA = [180, 165, 210, 170, 155, 188, 162, 145, 170, 158, 140, 163, 148, 135];
const MODEL_USAGE = [
  { name: "Qwen3-32B",         usage: 62, color: "#8b5cf6", queries: 48200 },
  { name: "DeepSeek-Coder",    usage: 22, color: "#3b82f6", queries: 17100 },
  { name: "Qwen2.5-VL",        usage: 9,  color: "#10b981", queries: 7000 },
  { name: "Phi-3-mini",        usage: 5,  color: "#f59e0b", queries: 3900 },
  { name: "Llama Guard 3",     usage: 2,  color: "#ef4444", queries: 1560 },
];
const TOP_TOPICS = [
  { name: "Data Structures & Algorithms", sessions: 14200 },
  { name: "System Design",                sessions: 9800 },
  { name: "Python Programming",           sessions: 8600 },
  { name: "Machine Learning",             sessions: 7100 },
  { name: "SQL & Databases",              sessions: 5400 },
  { name: "React & Frontend",             sessions: 4700 },
];
const SAFETY_EVENTS = [
  { label: "Auto-blocked",    value: 142, color: "text-red-400" },
  { label: "Flagged",         value: 58,  color: "text-amber-400" },
  { label: "Approved",        value: 23,  color: "text-emerald-400" },
];

function Sparkline({ data, color = "#8b5cf6", height = 40 }: { data: number[]; color?: string; height?: number }) {
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const w = 200;
  const h = height;
  const points = data.map((v, i) => `${(i / (data.length - 1)) * w},${h - ((v - min) / range) * h * 0.85}`).join(" ");
  return (
    <svg width="100%" height={height} viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none">
      <polyline points={points} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function DonutChart({ data }: { data: typeof MODEL_USAGE }) {
  const total = data.reduce((s, d) => s + d.usage, 0);
  let cumulative = 0;
  const r = 50;
  const cx = 70;
  const cy = 70;
  const circumference = 2 * Math.PI * r;
  const segments = data.map((d) => {
    const offset = cumulative;
    cumulative += d.usage / total;
    return { ...d, offset, length: d.usage / total };
  });

  return (
    <svg width="140" height="140" viewBox="0 0 140 140">
      {segments.map((seg, i) => (
        <circle key={i} cx={cx} cy={cy} r={r}
          fill="none" stroke={seg.color} strokeWidth="18"
          strokeDasharray={`${seg.length * circumference} ${circumference}`}
          strokeDashoffset={-seg.offset * circumference}
          style={{ transform: "rotate(-90deg)", transformOrigin: `${cx}px ${cy}px` }}
        />
      ))}
      <text x={cx} y={cy - 6} textAnchor="middle" fill="white" fontSize="14" fontWeight="bold">77K</text>
      <text x={cx} y={cy + 10} textAnchor="middle" fill="#6b7280" fontSize="8">queries</text>
    </svg>
  );
}

export default function AdminAnalyticsPage() {
  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-6xl flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-violet-500 to-indigo-600 shadow-lg">
            <Activity className="h-5 w-5 text-white" />
          </div>
          <div>
            <h1 className="text-sm font-bold text-[var(--foreground)]">Platform Analytics</h1>
            <p className="text-[11px] text-[var(--muted-foreground)]">Last 14 days · Updated 2 minutes ago</p>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-6xl space-y-5 px-4 py-5 sm:px-6">
          {/* KPI cards */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              { label: "Daily Active Users",   value: "1,100",  delta: "+18%",  color: "text-violet-400",  icon: <Users className="h-5 w-5" />,          data: DAU_DATA,     lineColor: "#8b5cf6" },
              { label: "Avg. Session (min)",   value: "38",     delta: "+5%",   color: "text-blue-400",    icon: <Clock className="h-5 w-5" />,           data: [22,26,24,28,30,32,35,34,36,37,38,38,38,38], lineColor: "#3b82f6" },
              { label: "AI Queries / Day",     value: "5,520",  delta: "+22%",  color: "text-emerald-400", icon: <MessageSquare className="h-5 w-5" />,   data: [1800,2100,2000,2400,2800,3100,3600,3400,3900,4200,4600,4900,5200,5520], lineColor: "#10b981" },
              { label: "Total XP Awarded",     value: "284K",   delta: "+31%",  color: "text-amber-400",   icon: <Star className="h-5 w-5" />,            data: [8,12,10,15,18,22,25,24,28,32,35,38,40,43].map(v => v * 1000), lineColor: "#f59e0b" },
            ].map((kpi) => (
              <div key={kpi.label} className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-4">
                <div className={`mb-2 flex items-center justify-between ${kpi.color}`}>
                  {kpi.icon}
                  <span className="text-[10px] font-bold text-emerald-400">{kpi.delta}</span>
                </div>
                <p className={`text-2xl font-black ${kpi.color}`}>{kpi.value}</p>
                <p className="mb-2 text-[10px] text-[var(--muted-foreground)]">{kpi.label}</p>
                <Sparkline data={kpi.data} color={kpi.lineColor} height={32} />
              </div>
            ))}
          </div>

          <div className="grid grid-cols-3 gap-5">
            {/* DAU Chart */}
            <div className="col-span-2 rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
              <h3 className="mb-4 flex items-center gap-2 text-sm font-semibold text-[var(--foreground)]">
                <TrendingUp className="h-4 w-4 text-violet-400" /> Daily Active Users — 14 Day Trend
              </h3>
              <div className="relative h-40">
                <svg width="100%" height="100%" viewBox="0 0 560 160" preserveAspectRatio="none">
                  <defs>
                    <linearGradient id="dauGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#8b5cf6" stopOpacity="0.3" />
                      <stop offset="100%" stopColor="#8b5cf6" stopOpacity="0" />
                    </linearGradient>
                  </defs>
                  {(() => {
                    const max = Math.max(...DAU_DATA);
                    const min = Math.min(...DAU_DATA);
                    const range = max - min;
                    const pts = DAU_DATA.map((v, i) => `${(i / (DAU_DATA.length - 1)) * 560},${140 - ((v - min) / range) * 120}`).join(" ");
                    const fillPts = `0,140 ${pts} 560,140`;
                    return (
                      <>
                        <polygon points={fillPts} fill="url(#dauGrad)" />
                        <polyline points={pts} fill="none" stroke="#8b5cf6" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
                        {DAU_DATA.map((v, i) => {
                          const x = (i / (DAU_DATA.length - 1)) * 560;
                          const y = 140 - ((v - min) / range) * 120;
                          return <circle key={i} cx={x} cy={y} r="3" fill="#8b5cf6" />;
                        })}
                      </>
                    );
                  })()}
                </svg>
                <div className="absolute bottom-0 left-0 right-0 flex justify-between text-[9px] text-[var(--muted-foreground)]">
                  {["Apr 28", "", "Apr 30", "", "May 2", "", "May 4", "", "May 6", "", "May 8", "", "May 10", "Today"].map((l, i) => (
                    <span key={i}>{l}</span>
                  ))}
                </div>
              </div>
            </div>

            {/* Model usage donut */}
            <div className="col-span-1 rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
              <h3 className="mb-4 text-sm font-semibold text-[var(--foreground)]">Model Usage Split</h3>
              <div className="flex justify-center mb-3">
                <DonutChart data={MODEL_USAGE} />
              </div>
              <div className="space-y-2">
                {MODEL_USAGE.map((m) => (
                  <div key={m.name} className="flex items-center gap-2">
                    <div className="h-2 w-2 rounded-full shrink-0" style={{ background: m.color }} />
                    <span className="flex-1 text-[10px] text-[var(--muted-foreground)] truncate">{m.name}</span>
                    <span className="text-[10px] font-bold text-[var(--foreground)]">{m.usage}%</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="grid grid-cols-3 gap-5">
            {/* Inference latency */}
            <div className="col-span-1 rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
              <h3 className="mb-1 flex items-center gap-2 text-sm font-semibold text-[var(--foreground)]">
                <Zap className="h-4 w-4 text-amber-400" /> P95 Latency (ms)
              </h3>
              <p className="mb-3 text-3xl font-black text-amber-400">135ms</p>
              <Sparkline data={LATENCY_DATA} color="#f59e0b" height={52} />
              <div className="mt-2 flex items-center gap-1 text-xs text-emerald-400">
                <TrendingUp className="h-3.5 w-3.5 rotate-180" /> 25% faster vs last month
              </div>
            </div>

            {/* Top topics */}
            <div className="col-span-1 rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
              <h3 className="mb-4 flex items-center gap-2 text-sm font-semibold text-[var(--foreground)]">
                <Brain className="h-4 w-4 text-violet-400" /> Top Learning Topics
              </h3>
              <div className="space-y-2.5">
                {TOP_TOPICS.map((t, i) => {
                  const max = TOP_TOPICS[0].sessions;
                  return (
                    <div key={t.name}>
                      <div className="mb-1 flex justify-between text-[10px]">
                        <span className="text-[var(--muted-foreground)] truncate">{t.name}</span>
                        <span className="font-bold text-[var(--foreground)] ml-2">{(t.sessions / 1000).toFixed(1)}K</span>
                      </div>
                      <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
                        <div className="h-full rounded-full bg-gradient-to-r from-violet-500 to-indigo-500" style={{ width: `${(t.sessions / max) * 100}%` }} />
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Safety stats */}
            <div className="col-span-1 rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
              <h3 className="mb-4 flex items-center gap-2 text-sm font-semibold text-[var(--foreground)]">
                <Shield className="h-4 w-4 text-red-400" /> Safety Events (Today)
              </h3>
              <div className="space-y-3">
                {SAFETY_EVENTS.map((s) => (
                  <div key={s.label} className="flex items-center justify-between">
                    <span className="text-xs text-[var(--muted-foreground)]">{s.label}</span>
                    <span className={`text-xl font-black ${s.color}`}>{s.value}</span>
                  </div>
                ))}
              </div>
              <div className="mt-4 rounded-xl bg-white/5 px-3 py-2 text-xs text-[var(--muted-foreground)]">
                <Server className="mb-1 h-3.5 w-3.5 inline text-violet-400" /> Llama Guard 3 processed <strong className="text-[var(--foreground)]">77,760</strong> messages today
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
