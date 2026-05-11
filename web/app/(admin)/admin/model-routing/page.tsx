/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  Activity,
  AlertCircle,
  Brain,
  CheckCircle2,
  Cpu,
  Eye,
  Mic,
  Shield,
  ScanLine,
  Sliders,
  Volume2,
  Zap,
} from "lucide-react";

interface ModelInfo {
  id: string;
  name: string;
  purpose: string;
  intent: string;
  status: "active" | "standby" | "error";
  requestsToday: number;
  avgLatency: string;
  errorRate: string;
  enabled: boolean;
  icon: React.ReactNode;
  color: string;
}

const MODELS: ModelInfo[] = [
  { id: "qwen3",    name: "Qwen/Qwen3-32B",                    purpose: "Main tutor, reasoning, general Q&A",    intent: "GENERAL / MATH / CAREER / ASSESSMENT", status: "active",  requestsToday: 1842, avgLatency: "2.1s",  errorRate: "0.2%", enabled: true,  icon: <Brain className="h-4 w-4" />,   color: "text-violet-400" },
  { id: "deepseek", name: "DeepSeek-Coder-V2-Instruct",        purpose: "Coding mentor, DSA, debugging",         intent: "CODING",                                status: "active",  requestsToday: 624,  avgLatency: "1.8s",  errorRate: "0.1%", enabled: true,  icon: <Cpu className="h-4 w-4" />,     color: "text-blue-400" },
  { id: "qwen-vl",  name: "Qwen/Qwen2.5-VL-72B-Instruct",     purpose: "Vision Q&A, whiteboard, images",        intent: "VISION",                                status: "active",  requestsToday: 187,  avgLatency: "3.4s",  errorRate: "0.5%", enabled: true,  icon: <Eye className="h-4 w-4" />,     color: "text-pink-400" },
  { id: "whisper",  name: "openai/whisper-large-v3",           purpose: "Speech-to-text, voice input",           intent: "SPEECH",                                status: "active",  requestsToday: 312,  avgLatency: "0.9s",  errorRate: "0.3%", enabled: true,  icon: <Mic className="h-4 w-4" />,     color: "text-emerald-400" },
  { id: "xtts",     name: "coqui/XTTS-v2",                    purpose: "Text-to-speech, AI voice replies",      intent: "TTS",                                   status: "active",  requestsToday: 298,  avgLatency: "1.2s",  errorRate: "0.4%", enabled: true,  icon: <Volume2 className="h-4 w-4" />, color: "text-teal-400" },
  { id: "trocr",    name: "microsoft/trocr-large-handwritten", purpose: "OCR for handwritten notes",             intent: "OCR",                                   status: "standby", requestsToday: 43,   avgLatency: "1.6s",  errorRate: "1.2%", enabled: true,  icon: <ScanLine className="h-4 w-4" />, color: "text-cyan-400" },
  { id: "donut",    name: "naver-clova-ix/donut-base",         purpose: "Document OCR extraction",               intent: "OCR",                                   status: "standby", requestsToday: 28,   avgLatency: "2.0s",  errorRate: "0.8%", enabled: true,  icon: <ScanLine className="h-4 w-4" />, color: "text-sky-400" },
  { id: "bge",      name: "BAAI/bge-large-en-v1.5",           purpose: "Embeddings for RAG",                    intent: "EMBEDDING",                             status: "active",  requestsToday: 2341, avgLatency: "0.1s",  errorRate: "0.0%", enabled: true,  icon: <Zap className="h-4 w-4" />,     color: "text-amber-400" },
  { id: "reranker", name: "BAAI/bge-reranker-large",           purpose: "Re-ranking RAG passages",              intent: "RERANK",                                status: "active",  requestsToday: 1876, avgLatency: "0.3s",  errorRate: "0.0%", enabled: true,  icon: <Sliders className="h-4 w-4" />, color: "text-lime-400" },
  { id: "phi3",     name: "microsoft/Phi-3-mini-4k-instruct",  purpose: "Lightweight mobile fallback",           intent: "FALLBACK",                              status: "standby", requestsToday: 89,   avgLatency: "0.6s",  errorRate: "0.2%", enabled: true,  icon: <Cpu className="h-4 w-4" />,     color: "text-orange-400" },
  { id: "guard",    name: "meta-llama/Llama-Guard-3-8B",       purpose: "Safety & content moderation",           intent: "SAFETY",                                status: "active",  requestsToday: 3421, avgLatency: "0.4s",  errorRate: "0.0%", enabled: true,  icon: <Shield className="h-4 w-4" />,  color: "text-red-400" },
];

const STATUS_CONFIG = {
  active:  { label: "Active",  color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/30" },
  standby: { label: "Standby", color: "text-amber-400 bg-amber-500/10 border-amber-500/30" },
  error:   { label: "Error",   color: "text-red-400 bg-red-500/10 border-red-500/30" },
};

const INTENT_ROUTING = [
  { intent: "GENERAL",    model: "Qwen/Qwen3-32B",                    volume: 1842, color: "bg-violet-500" },
  { intent: "CODING",     model: "DeepSeek-Coder-V2-Instruct",        volume: 624,  color: "bg-blue-500" },
  { intent: "MATH",       model: "Qwen/Qwen3-32B (reasoning pathway)", volume: 431,  color: "bg-amber-500" },
  { intent: "VISION",     model: "Qwen2.5-VL-72B-Instruct",           volume: 187,  color: "bg-pink-500" },
  { intent: "CAREER",     model: "Qwen/Qwen3-32B",                    volume: 298,  color: "bg-emerald-500" },
  { intent: "ASSESSMENT", model: "Qwen/Qwen3-32B",                    volume: 412,  color: "bg-cyan-500" },
  { intent: "SAFETY",     model: "Llama-Guard-3-8B",                  volume: 3421, color: "bg-red-500" },
  { intent: "SPEECH",     model: "Whisper large-v3",                  volume: 312,  color: "bg-teal-500" },
];

const maxVolume = Math.max(...INTENT_ROUTING.map(r => r.volume));

export default function ModelRoutingPage() {
  const [models, setModels] = useState<ModelInfo[]>(MODELS);

  const toggleModel = (id: string) =>
    setModels((prev) => prev.map((m) => m.id === id ? { ...m, enabled: !m.enabled } : m));

  const totalRequests = models.reduce((s, m) => s + m.requestsToday, 0);
  const activeCount = models.filter((m) => m.status === "active" && m.enabled).length;

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-6xl flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600 shadow-lg">
            <Cpu className="h-5 w-5 text-white" />
          </div>
          <div>
            <h1 className="text-sm font-bold text-[var(--foreground)]">Model Routing & AI Configuration</h1>
            <p className="text-[11px] text-[var(--muted-foreground)]">
              {activeCount} active models · {totalRequests.toLocaleString()} requests today
            </p>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-6xl space-y-6 px-4 py-6 sm:px-6">
          {/* HF Token status */}
          <div className="flex items-center gap-3 rounded-xl border border-emerald-500/20 bg-emerald-500/5 px-4 py-3">
            <CheckCircle2 className="h-5 w-5 text-emerald-400" />
            <div>
              <p className="text-sm font-semibold text-emerald-400">HF_TOKEN configured</p>
              <p className="text-xs text-[var(--muted-foreground)]">All models routing through Hugging Face Inference API (router.huggingface.co/v1)</p>
            </div>
          </div>

          {/* Model cards */}
          <div>
            <h2 className="mb-4 text-sm font-semibold text-[var(--foreground)]">Active Models ({models.length})</h2>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {models.map((m) => {
                const sc = STATUS_CONFIG[m.status];
                return (
                  <div
                    key={m.id}
                    className={`rounded-xl border border-white/5 bg-[var(--secondary)] p-4 transition-opacity ${!m.enabled ? "opacity-50" : ""}`}
                  >
                    <div className="mb-3 flex items-start justify-between gap-2">
                      <div className="flex items-center gap-2">
                        <div className={`${m.color}`}>{m.icon}</div>
                        <div>
                          <p className="text-xs font-mono font-semibold text-[var(--foreground)] truncate max-w-[160px]">{m.name.split("/").pop()}</p>
                          <p className="text-[10px] text-[var(--muted-foreground)]">{m.purpose}</p>
                        </div>
                      </div>
                      <button
                        onClick={() => toggleModel(m.id)}
                        className={`relative flex h-5 w-9 shrink-0 items-center rounded-full transition-colors ${m.enabled ? "bg-violet-600" : "bg-white/20"}`}
                      >
                        <div className={`absolute h-3.5 w-3.5 rounded-full bg-white shadow transition-transform ${m.enabled ? "translate-x-4" : "translate-x-0.5"}`} />
                      </button>
                    </div>
                    <div className="mb-3 flex items-center gap-1.5">
                      <span className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${sc.color}`}>{sc.label}</span>
                      <span className="text-[10px] font-mono text-violet-400 truncate">{m.intent}</span>
                    </div>
                    <div className="grid grid-cols-3 gap-2 text-center">
                      <div>
                        <p className="text-xs font-bold text-[var(--foreground)]">{m.requestsToday.toLocaleString()}</p>
                        <p className="text-[9px] text-[var(--muted-foreground)]">Requests</p>
                      </div>
                      <div>
                        <p className="text-xs font-bold text-blue-400">{m.avgLatency}</p>
                        <p className="text-[9px] text-[var(--muted-foreground)]">Latency</p>
                      </div>
                      <div>
                        <p className={`text-xs font-bold ${parseFloat(m.errorRate) > 1 ? "text-red-400" : "text-emerald-400"}`}>{m.errorRate}</p>
                        <p className="text-[9px] text-[var(--muted-foreground)]">Errors</p>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Intent routing table */}
          <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
            <h2 className="mb-5 text-sm font-semibold text-[var(--foreground)]">Intent → Model Routing</h2>
            <div className="space-y-3">
              {INTENT_ROUTING.map((r) => (
                <div key={r.intent} className="flex items-center gap-4">
                  <span className="w-24 shrink-0 text-xs font-mono font-semibold text-[var(--foreground)]">{r.intent}</span>
                  <div className="flex-1">
                    <div className="mb-1 text-xs text-[var(--muted-foreground)]">{r.model}</div>
                    <div className="h-2 overflow-hidden rounded-full bg-white/10">
                      <div className={`h-full rounded-full ${r.color} opacity-70`} style={{ width: `${(r.volume / maxVolume) * 100}%` }} />
                    </div>
                  </div>
                  <div className="flex items-center gap-1 text-xs text-[var(--muted-foreground)]">
                    <Activity className="h-3 w-3" />
                    {r.volume.toLocaleString()}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Warning */}
          <div className="flex items-center gap-3 rounded-xl border border-amber-500/20 bg-amber-500/5 px-4 py-3">
            <AlertCircle className="h-5 w-5 text-amber-400" />
            <div>
              <p className="text-sm font-semibold text-amber-400">Fallback active</p>
              <p className="text-xs text-[var(--muted-foreground)]">
                Phi-3-mini is set as mobile fallback for slow connections. Error rate above threshold triggers automatic fallback.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
