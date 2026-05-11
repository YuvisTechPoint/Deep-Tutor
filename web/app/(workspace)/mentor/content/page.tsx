/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useState } from "react";
import {
  BookOpen,
  Brain,
  Calendar,
  ChevronRight,
  Clock,
  FileText,
  Lightbulb,
  Plus,
  Sparkles,
  Tag,
  Trash2,
} from "lucide-react";

type ContentType = "lesson" | "quiz" | "exercise" | "resource";
type DifficultyLevel = "beginner" | "intermediate" | "advanced";

interface ContentItem {
  id: string;
  title: string;
  type: ContentType;
  topic: string;
  difficulty: DifficultyLevel;
  estimatedMin: number;
  assignedTo: string[];
  scheduledDate: string;
  aiGenerated?: boolean;
}

const TYPE_CONFIG: Record<ContentType, { label: string; icon: React.ReactNode; color: string }> = {
  lesson:   { label: "Lesson",   icon: <BookOpen className="h-3.5 w-3.5" />,   color: "text-violet-400 bg-violet-500/10 border-violet-500/30" },
  quiz:     { label: "Quiz",     icon: <Brain className="h-3.5 w-3.5" />,      color: "text-amber-400 bg-amber-500/10 border-amber-500/30" },
  exercise: { label: "Exercise", icon: <FileText className="h-3.5 w-3.5" />,   color: "text-blue-400 bg-blue-500/10 border-blue-500/30" },
  resource: { label: "Resource", icon: <Tag className="h-3.5 w-3.5" />,        color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/30" },
};

const DIFFICULTY_CONFIG: Record<DifficultyLevel, { label: string; color: string }> = {
  beginner:     { label: "Beginner",     color: "text-emerald-400" },
  intermediate: { label: "Intermediate", color: "text-amber-400" },
  advanced:     { label: "Advanced",     color: "text-red-400" },
};

const LEARNERS = ["All Cohort", "David Okafor", "Mei Lin", "Priya Sharma", "Raj Patel", "Aisha Raza", "Marcus Chen"];

const INITIAL_CONTENT: ContentItem[] = [
  { id: "c1", title: "Introduction to React Hooks", type: "lesson",   topic: "React",           difficulty: "intermediate", estimatedMin: 25, assignedTo: ["David Okafor", "Marcus Chen"], scheduledDate: "May 13, 2026", aiGenerated: true },
  { id: "c2", title: "React useState & useEffect Quiz", type: "quiz", topic: "React",           difficulty: "intermediate", estimatedMin: 12, assignedTo: ["David Okafor"],                scheduledDate: "May 14, 2026", aiGenerated: true },
  { id: "c3", title: "Probability & Statistics Review", type: "lesson", topic: "Statistics",   difficulty: "beginner",     estimatedMin: 30, assignedTo: ["Mei Lin"],                     scheduledDate: "May 12, 2026" },
  { id: "c4", title: "Bayes Theorem Practice Set",    type: "exercise", topic: "Statistics",   difficulty: "intermediate", estimatedMin: 20, assignedTo: ["Mei Lin"],                     scheduledDate: "May 13, 2026", aiGenerated: true },
  { id: "c5", title: "PyTorch Fundamentals",          type: "resource", topic: "ML/AI",        difficulty: "intermediate", estimatedMin: 45, assignedTo: ["Priya Sharma"],                scheduledDate: "May 15, 2026" },
  { id: "c6", title: "Neural Network Architecture Quiz", type: "quiz", topic: "ML/AI",         difficulty: "advanced",     estimatedMin: 18, assignedTo: ["All Cohort"],                  scheduledDate: "May 16, 2026", aiGenerated: true },
];

const AI_SUGGESTIONS = [
  { title: "Data Structures Refresher for Weak Learners", topic: "DSA", difficulty: "intermediate" as DifficultyLevel, type: "lesson" as ContentType, reason: "3 learners scored below 55% on last DSA quiz" },
  { title: "5-Day Probability Sprint", topic: "Statistics", difficulty: "beginner" as DifficultyLevel, type: "exercise" as ContentType, reason: "Mei Lin missed 5 days — needs catch-up plan" },
  { title: "System Design Interview Prep", topic: "System Design", difficulty: "advanced" as DifficultyLevel, type: "resource" as ContentType, reason: "Aisha targets FAANG — system design is critical" },
];

export default function ContentPlanningPage() {
  const [content, setContent] = useState<ContentItem[]>(INITIAL_CONTENT);
  const [showForm, setShowForm] = useState(false);
  const [filterTopic, setFilterTopic] = useState("All");
  const [newTitle, setNewTitle] = useState("");
  const [newType, setNewType] = useState<ContentType>("lesson");
  const [newTopic, setNewTopic] = useState("");
  const [newDiff, setNewDiff] = useState<DifficultyLevel>("intermediate");
  const [newMin, setNewMin] = useState(20);
  const [newDate, setNewDate] = useState("");
  const [newLearners, setNewLearners] = useState<string[]>([]);

  const topics = ["All", ...Array.from(new Set(content.map((c) => c.topic)))];

  const filtered = filterTopic === "All" ? content : content.filter((c) => c.topic === filterTopic);

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    const item: ContentItem = {
      id: `c${content.length + 1}`, title: newTitle, type: newType, topic: newTopic,
      difficulty: newDiff, estimatedMin: newMin, assignedTo: newLearners,
      scheduledDate: newDate || "TBD",
    };
    setContent((prev) => [item, ...prev]);
    setShowForm(false);
    setNewTitle(""); setNewTopic(""); setNewLearners([]);
  };

  const addSuggestion = (s: typeof AI_SUGGESTIONS[0]) => {
    const item: ContentItem = {
      id: `c${content.length + 1}`, title: s.title, type: s.type, topic: s.topic,
      difficulty: s.difficulty, estimatedMin: 20, assignedTo: ["All Cohort"],
      scheduledDate: "TBD", aiGenerated: true,
    };
    setContent((prev) => [...prev, item]);
  };

  const toggleLearner = (l: string) =>
    setNewLearners((prev) => prev.includes(l) ? prev.filter((x) => x !== l) : [...prev, l]);

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="mx-auto max-w-5xl flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-blue-500 to-cyan-600 shadow-lg">
              <BookOpen className="h-5 w-5 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">Content Planning</h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">{content.length} items · {content.filter(c=>c.aiGenerated).length} AI-generated</p>
            </div>
          </div>
          <button onClick={() => setShowForm(!showForm)}
            className="flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2 text-sm font-semibold text-white hover:bg-violet-500 transition-colors">
            <Plus className="h-4 w-4" /> Add Content
          </button>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-5xl space-y-5 px-4 py-5 sm:px-6">
          {/* AI suggestions */}
          <div className="rounded-2xl border border-violet-500/20 bg-violet-500/5 p-5">
            <div className="mb-3 flex items-center gap-2">
              <Sparkles className="h-4 w-4 text-violet-400" />
              <span className="text-sm font-bold text-violet-200">AI-Suggested Content</span>
              <span className="text-xs text-[var(--muted-foreground)]">Based on cohort performance gaps</span>
            </div>
            <div className="space-y-2">
              {AI_SUGGESTIONS.map((s, i) => (
                <div key={i} className="flex items-center gap-3 rounded-xl bg-white/5 px-4 py-3">
                  <Lightbulb className="h-4 w-4 shrink-0 text-amber-400" />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-[var(--foreground)]">{s.title}</p>
                    <p className="text-xs text-[var(--muted-foreground)]">{s.reason}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] text-[var(--muted-foreground)]">{s.topic}</span>
                    <button onClick={() => addSuggestion(s)}
                      className="flex items-center gap-1 rounded-lg bg-violet-600/20 px-2 py-1 text-[10px] font-semibold text-violet-300 hover:bg-violet-600/40 transition-colors">
                      <Plus className="h-3 w-3" /> Add
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Create form */}
          {showForm && (
            <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-5">
              <h3 className="mb-4 font-bold text-[var(--foreground)]">New Content Item</h3>
              <form onSubmit={handleCreate} className="space-y-3">
                <input value={newTitle} onChange={(e) => setNewTitle(e.target.value)} placeholder="Content title..."
                  className="w-full rounded-xl border border-white/5 bg-[var(--background)] px-4 py-2.5 text-sm text-[var(--foreground)] outline-none placeholder:text-[var(--muted-foreground)]" />
                <div className="grid grid-cols-3 gap-3">
                  <select value={newType} onChange={(e) => setNewType(e.target.value as ContentType)}
                    className="rounded-xl border border-white/5 bg-[var(--background)] px-3 py-2.5 text-sm text-[var(--foreground)] outline-none">
                    {(["lesson", "quiz", "exercise", "resource"] as const).map(t => <option key={t} className="bg-black">{t}</option>)}
                  </select>
                  <select value={newDiff} onChange={(e) => setNewDiff(e.target.value as DifficultyLevel)}
                    className="rounded-xl border border-white/5 bg-[var(--background)] px-3 py-2.5 text-sm text-[var(--foreground)] outline-none">
                    {(["beginner", "intermediate", "advanced"] as const).map(d => <option key={d} className="bg-black">{d}</option>)}
                  </select>
                  <input type="number" value={newMin} onChange={(e) => setNewMin(Number(e.target.value))} min={5} max={120}
                    placeholder="Est. min"
                    className="rounded-xl border border-white/5 bg-[var(--background)] px-4 py-2.5 text-sm text-[var(--foreground)] outline-none" />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <input value={newTopic} onChange={(e) => setNewTopic(e.target.value)} placeholder="Topic (e.g. React, DSA)"
                    className="rounded-xl border border-white/5 bg-[var(--background)] px-4 py-2.5 text-sm text-[var(--foreground)] outline-none placeholder:text-[var(--muted-foreground)]" />
                  <input type="date" value={newDate} onChange={(e) => setNewDate(e.target.value)}
                    className="rounded-xl border border-white/5 bg-[var(--background)] px-4 py-2.5 text-sm text-[var(--foreground)] outline-none" />
                </div>
                <div>
                  <p className="mb-2 text-xs font-medium text-[var(--muted-foreground)]">Assign to:</p>
                  <div className="flex flex-wrap gap-2">
                    {LEARNERS.map((l) => (
                      <button type="button" key={l} onClick={() => toggleLearner(l)}
                        className={`rounded-full border px-3 py-1 text-xs transition-colors ${
                          newLearners.includes(l) ? "border-violet-500/50 bg-violet-500/15 text-violet-200" : "border-white/10 bg-white/5 text-[var(--muted-foreground)]"
                        }`}>{l}</button>
                    ))}
                  </div>
                </div>
                <div className="flex gap-3 pt-1">
                  <button type="button" onClick={() => setShowForm(false)}
                    className="flex-1 rounded-xl border border-white/5 bg-white/5 py-2 text-sm text-[var(--muted-foreground)] hover:bg-white/10">Cancel</button>
                  <button type="submit"
                    className="flex-1 rounded-xl bg-violet-600 py-2 text-sm font-semibold text-white hover:bg-violet-500">Create</button>
                </div>
              </form>
            </div>
          )}

          {/* Topic filters */}
          <div className="flex flex-wrap gap-2">
            {topics.map((t) => (
              <button key={t} onClick={() => setFilterTopic(t)}
                className={`rounded-full px-3 py-1.5 text-xs font-medium transition-colors ${
                  filterTopic === t ? "bg-violet-600 text-white" : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
                }`}>{t}</button>
            ))}
          </div>

          {/* Content list */}
          <div className="overflow-hidden rounded-2xl border border-white/5 bg-[var(--secondary)]">
            <div className="divide-y divide-white/5">
              {filtered.map((item) => {
                const tc = TYPE_CONFIG[item.type];
                const dc = DIFFICULTY_CONFIG[item.difficulty];
                return (
                  <div key={item.id} className="flex items-center gap-4 px-5 py-4">
                    <div className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-xl border ${tc.color}`}>
                      {tc.icon}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-0.5">
                        <p className="text-sm font-medium text-[var(--foreground)] truncate">{item.title}</p>
                        {item.aiGenerated && (
                          <span className="flex items-center gap-0.5 rounded-full bg-violet-500/10 px-1.5 py-0.5 text-[9px] font-bold text-violet-400">
                            <Sparkles className="h-2.5 w-2.5" /> AI
                          </span>
                        )}
                      </div>
                      <div className="flex flex-wrap items-center gap-3 text-[10px] text-[var(--muted-foreground)]">
                        <span className={`font-semibold ${dc.color}`}>{dc.label}</span>
                        <span className="flex items-center gap-1"><Clock className="h-3 w-3" />{item.estimatedMin}m</span>
                        <span className="flex items-center gap-1"><Calendar className="h-3 w-3" />{item.scheduledDate}</span>
                        <span className="flex items-center gap-1"><Tag className="h-3 w-3" />{item.topic}</span>
                        <span>{item.assignedTo.slice(0, 2).join(", ")}{item.assignedTo.length > 2 ? ` +${item.assignedTo.length - 2}` : ""}</span>
                      </div>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                      <button onClick={() => setContent(prev => prev.filter(c => c.id !== item.id))}
                        className="p-1.5 text-[var(--muted-foreground)] hover:text-red-400 transition-colors">
                        <Trash2 className="h-4 w-4" />
                      </button>
                      <button className="p-1.5 text-[var(--muted-foreground)] hover:text-[var(--foreground)] transition-colors">
                        <ChevronRight className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
