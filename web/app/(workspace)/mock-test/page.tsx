/* eslint-disable i18n/no-literal-ui-text */
"use client";

import { useEffect, useRef, useState } from "react";
import {
  AlertCircle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Clock,
  Flag,
  Target,
  XCircle,
} from "lucide-react";

interface Question {
  id: number;
  text: string;
  options: string[];
  correct: number;
  topic: string;
  difficulty: "easy" | "medium" | "hard";
}

const QUESTIONS: Question[] = [
  { id: 1, text: "What is the time complexity of binary search on a sorted array of n elements?", options: ["O(n)", "O(log n)", "O(n log n)", "O(1)"], correct: 1, topic: "DSA", difficulty: "easy" },
  { id: 2, text: "Which data structure uses FIFO (First In First Out) ordering?", options: ["Stack", "Queue", "Tree", "Graph"], correct: 1, topic: "DSA", difficulty: "easy" },
  { id: 3, text: "In Python, what is the output of `type(lambda x: x)`?", options: ["<class 'function'>", "<class 'lambda'>", "<class 'method'>", "SyntaxError"], correct: 0, topic: "Python", difficulty: "medium" },
  { id: 4, text: "Which sorting algorithm has O(n²) worst case but O(n) best case?", options: ["Merge Sort", "Quick Sort", "Bubble Sort", "Heap Sort"], correct: 2, topic: "DSA", difficulty: "medium" },
  { id: 5, text: "What does the CAP theorem state about distributed systems?", options: ["A system can guarantee Consistency, Availability, and Partition tolerance simultaneously", "A system can only guarantee at most two of: Consistency, Availability, Partition tolerance", "Partition tolerance is always optional", "Consistency and Availability always trade off equally"], correct: 1, topic: "System Design", difficulty: "hard" },
  { id: 6, text: "In SQL, which clause is used to filter groups after aggregation?", options: ["WHERE", "HAVING", "GROUP BY", "FILTER"], correct: 1, topic: "SQL", difficulty: "medium" },
  { id: 7, text: "What is a hash collision?", options: ["When two keys produce the same hash value", "When a hash table is full", "A cryptographic attack", "When hashing is slower than expected"], correct: 0, topic: "DSA", difficulty: "medium" },
  { id: 8, text: "Which HTTP status code represents 'Not Found'?", options: ["400", "401", "403", "404"], correct: 3, topic: "System Design", difficulty: "easy" },
  { id: 9, text: "What is the space complexity of merge sort?", options: ["O(1)", "O(log n)", "O(n)", "O(n²)"], correct: 2, topic: "DSA", difficulty: "hard" },
  { id: 10, text: "What does 'idempotent' mean in the context of REST APIs?", options: ["The request has side effects", "Multiple identical requests have the same effect as one", "The request cannot be repeated", "The API uses HTTP/2"], correct: 1, topic: "System Design", difficulty: "hard" },
];

type TestPhase = "setup" | "active" | "review";
type DifficultyFilter = "all" | "easy" | "medium" | "hard";

const DIFFICULTY_COLORS = { easy: "text-emerald-400", medium: "text-amber-400", hard: "text-red-400" };

export default function MockTestPage() {
  const [phase, setPhase] = useState<TestPhase>("setup");
  const [selected, setSelected] = useState<Record<number, number>>({});
  const [flagged, setFlagged] = useState<Set<number>>(new Set());
  const [current, setCurrent] = useState(0);
  const [timeLeft, setTimeLeft] = useState(20 * 60); // 20 minutes
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const [diffFilter] = useState<DifficultyFilter>("all");

  const questions = diffFilter === "all" ? QUESTIONS : QUESTIONS.filter(q => q.difficulty === diffFilter);

  useEffect(() => {
    if (phase === "active") {
      timerRef.current = setInterval(() => {
        setTimeLeft((t) => {
          if (t <= 1) { clearInterval(timerRef.current!); setPhase("review"); return 0; }
          return t - 1;
        });
      }, 1000);
    }
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, [phase]);

  const minutes = String(Math.floor(timeLeft / 60)).padStart(2, "0");
  const seconds = String(timeLeft % 60).padStart(2, "0");

  const answeredCount = Object.keys(selected).length;
  const correctCount = questions.filter((q) => selected[q.id] === q.correct).length;
  const score = questions.length > 0 ? Math.round((correctCount / questions.length) * 100) : 0;

  const toggleFlag = (id: number) => {
    setFlagged((prev) => {
      const n = new Set(prev);
      n.has(id) ? n.delete(id) : n.add(id);
      return n;
    });
  };

  if (phase === "setup") {
    return (
      <div className="flex h-screen items-center justify-center bg-[var(--background)] p-6">
        <div className="w-full max-w-lg">
          <div className="mb-6 flex h-16 w-16 items-center justify-center rounded-2xl border border-[var(--border)] bg-[var(--secondary)] shadow-sm">
            <Target className="h-8 w-8 text-[var(--foreground)]" strokeWidth={2} />
          </div>
          <h1 className="mb-2 text-2xl font-black text-[var(--foreground)]">DSA + System Design Mock Test</h1>
          <p className="mb-6 text-sm text-[var(--muted-foreground)]">AI-generated assessment powered by the Assessment Agent · 10 questions · 20 minutes</p>
          <div className="mb-6 grid grid-cols-3 gap-3">
            {[{ label: "Questions", value: "10" }, { label: "Time Limit", value: "20 min" }, { label: "Topics", value: "3 topics" }].map((s) => (
              <div key={s.label} className="rounded-xl border border-white/5 bg-[var(--secondary)] p-4 text-center">
                <p className="text-xl font-black text-[var(--foreground)]">{s.value}</p>
                <p className="text-xs text-[var(--muted-foreground)]">{s.label}</p>
              </div>
            ))}
          </div>
          <div className="mb-6 rounded-xl border border-amber-500/20 bg-amber-500/5 p-4">
            <div className="flex items-start gap-2">
              <AlertCircle className="mt-0.5 h-4 w-4 shrink-0 text-amber-400" />
              <div className="text-xs text-amber-200">
                <strong>Instructions:</strong> Select one answer per question. You can flag questions to review later. Timer starts when you click Begin Test. Submitting is final.
              </div>
            </div>
          </div>
          <button
            type="button"
            onClick={() => setPhase("active")}
            className="w-full rounded-2xl border border-[var(--border)] bg-[var(--foreground)] py-4 text-sm font-bold text-[var(--background)] shadow-sm transition-opacity hover:opacity-90"
          >
            Begin Test →
          </button>
        </div>
      </div>
    );
  }

  if (phase === "review") {
    return (
      <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
        <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
          <div className="mx-auto max-w-3xl flex items-center justify-between">
            <h1 className="font-bold text-[var(--foreground)]">Test Results</h1>
            <div className={`text-2xl font-black ${score >= 70 ? "text-emerald-400" : "text-red-400"}`}>{score}%</div>
          </div>
        </header>
        <div className="flex-1 overflow-y-auto">
          <div className="mx-auto max-w-3xl space-y-4 px-4 py-6 sm:px-6">
            {/* Score card */}
            <div className={`rounded-2xl border p-6 text-center ${score >= 70 ? "border-emerald-500/20 bg-emerald-500/5" : "border-red-500/20 bg-red-500/5"}`}>
              <p className={`text-6xl font-black mb-2 ${score >= 70 ? "text-emerald-400" : "text-red-400"}`}>{score}%</p>
              <p className="text-sm text-[var(--foreground)] font-medium">{score >= 80 ? "Excellent! You're on track for FAANG." : score >= 60 ? "Good effort! Focus on the areas below." : "Needs improvement. Review weak topics."}</p>
              <div className="mt-4 grid grid-cols-3 gap-3">
                {[
                  { label: "Correct",    value: correctCount,                  color: "text-emerald-400" },
                  { label: "Incorrect",  value: answeredCount - correctCount,  color: "text-red-400" },
                  { label: "Skipped",    value: questions.length - answeredCount, color: "text-amber-400" },
                ].map((s) => (
                  <div key={s.label} className="rounded-xl bg-white/5 p-3">
                    <p className={`text-2xl font-black ${s.color}`}>{s.value}</p>
                    <p className="text-xs text-[var(--muted-foreground)]">{s.label}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* Question review */}
            <div className="space-y-3">
              {questions.map((q) => {
                const userAns = selected[q.id];
                const isCorrect = userAns === q.correct;
                const skipped = userAns === undefined;
                return (
                  <div key={q.id} className={`rounded-2xl border p-5 ${isCorrect ? "border-emerald-500/15 bg-emerald-500/3" : skipped ? "border-white/5 bg-[var(--secondary)]" : "border-red-500/15 bg-red-500/3"}`}>
                    <div className="mb-3 flex items-start gap-3">
                      {isCorrect ? <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-emerald-400" /> : skipped ? <AlertCircle className="mt-0.5 h-5 w-5 shrink-0 text-amber-400" /> : <XCircle className="mt-0.5 h-5 w-5 shrink-0 text-red-400" />}
                      <p className="text-sm text-[var(--foreground)]"><span className="font-bold">Q{q.id}.</span> {q.text}</p>
                    </div>
                    <div className="ml-8 space-y-1.5">
                      {q.options.map((opt, i) => {
                        const isCorrectOpt = i === q.correct;
                        const isUserOpt = i === userAns;
                        return (
                          <div key={i} className={`rounded-lg px-3 py-2 text-xs ${
                            isCorrectOpt ? "bg-emerald-500/15 text-emerald-200 font-medium" :
                            isUserOpt && !isCorrect ? "bg-red-500/15 text-red-200" :
                            "text-[var(--muted-foreground)]"
                          }`}>
                            {String.fromCharCode(65 + i)}. {opt}
                            {isCorrectOpt && <span className="ml-2 font-bold text-emerald-400">✓ Correct</span>}
                            {isUserOpt && !isCorrect && <span className="ml-2 text-red-400">✗ Your answer</span>}
                          </div>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </div>

            <button
              type="button"
              onClick={() => {
                setPhase("setup");
                setSelected({});
                setFlagged(new Set());
                setCurrent(0);
                setTimeLeft(20 * 60);
              }}
              className="w-full rounded-2xl border border-[var(--border)] bg-[var(--foreground)] py-3 text-sm font-bold text-[var(--background)] shadow-sm transition-opacity hover:opacity-90"
            >
              Retake Test
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Active test
  const q = questions[current];
  const progress = (answeredCount / questions.length) * 100;

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      {/* Header */}
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-4 py-3">
        <div className="mx-auto max-w-3xl flex items-center gap-4">
          <div className={`flex items-center gap-1.5 font-mono text-sm font-bold ${timeLeft < 120 ? "text-red-400" : "text-[var(--foreground)]"}`}>
            <Clock className="h-4 w-4" /> {minutes}:{seconds}
          </div>
          <div className="flex-1">
            <div className="h-1.5 overflow-hidden rounded-full bg-[var(--muted)]">
              <div
                className="h-full rounded-full bg-[var(--foreground)] transition-all"
                style={{ width: `${progress}%` }}
              />
            </div>
            <p className="mt-1 text-[10px] text-[var(--muted-foreground)]">{answeredCount}/{questions.length} answered</p>
          </div>
          <button
            type="button"
            onClick={() => {
              clearInterval(timerRef.current!);
              setPhase("review");
            }}
            className="rounded-lg border border-[var(--border)] bg-[var(--foreground)] px-3 py-1.5 text-xs font-bold text-[var(--background)] shadow-sm transition-opacity hover:opacity-90"
          >
            Submit
          </button>
        </div>
      </header>

      {/* Question navigator */}
      <div className="shrink-0 overflow-x-auto border-b border-white/5 bg-[var(--secondary)] px-4 py-2">
        <div className="flex gap-1.5">
          {questions.map((qu, i) => (
            <button key={qu.id} onClick={() => setCurrent(i)}
              className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-lg text-xs font-bold transition-colors ${
                i === current
                  ? "border border-[var(--border)] bg-[var(--foreground)] text-[var(--background)]"
                  : selected[qu.id] !== undefined
                    ? "bg-emerald-600/20 text-emerald-400"
                    : flagged.has(qu.id)
                      ? "bg-amber-500/20 text-amber-400"
                      : "bg-[var(--muted)]/50 text-[var(--muted-foreground)]"
              }`}>
              {i + 1}
            </button>
          ))}
        </div>
      </div>

      {/* Question area */}
      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto max-w-3xl px-4 py-6 sm:px-6">
          <div className="mb-4 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="rounded-full bg-white/5 px-2.5 py-0.5 text-xs text-[var(--muted-foreground)]">{q.topic}</span>
              <span className={`text-xs font-semibold ${DIFFICULTY_COLORS[q.difficulty]}`}>{q.difficulty}</span>
            </div>
            <button onClick={() => toggleFlag(q.id)}
              className={`flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-xs transition-colors ${
                flagged.has(q.id) ? "bg-amber-500/20 text-amber-400" : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
              }`}>
              <Flag className="h-3.5 w-3.5" /> {flagged.has(q.id) ? "Flagged" : "Flag"}
            </button>
          </div>

          <h2 className="mb-6 text-lg font-bold text-[var(--foreground)] leading-relaxed">
            Q{current + 1}. {q.text}
          </h2>

          <div className="space-y-3">
            {q.options.map((opt, i) => {
              const isSelected = selected[q.id] === i;
              return (
                <button key={i} onClick={() => setSelected((prev) => ({ ...prev, [q.id]: i }))}
                  className={`flex w-full items-center gap-4 rounded-2xl border p-4 text-left transition-all ${
                    isSelected
                      ? "border-[var(--foreground)]/35 bg-[var(--muted)] shadow-sm"
                      : "border-[var(--border)] bg-[var(--secondary)] hover:border-[var(--border)] hover:bg-[var(--muted)]/40"
                  }`}>
                  <div
                    className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full border text-sm font-bold ${
                      isSelected
                        ? "border-[var(--foreground)]/50 bg-[var(--foreground)] text-[var(--background)]"
                        : "border-[var(--border)] text-[var(--muted-foreground)]"
                    }`}
                  >
                    {String.fromCharCode(65 + i)}
                  </div>
                  <span
                    className={`text-sm ${isSelected ? "font-medium text-[var(--foreground)]" : "text-[var(--muted-foreground)]"}`}
                  >
                    {opt}
                  </span>
                  {isSelected && (
                    <CheckCircle2 className="ml-auto h-5 w-5 text-[var(--foreground)]" />
                  )}
                </button>
              );
            })}
          </div>

          {/* Navigation */}
          <div className="mt-6 flex items-center justify-between">
            <button onClick={() => setCurrent((c) => Math.max(0, c - 1))} disabled={current === 0}
              className="flex items-center gap-2 rounded-xl border border-white/5 bg-white/5 px-4 py-2.5 text-sm font-medium text-[var(--muted-foreground)] hover:bg-white/10 disabled:opacity-40 transition-colors">
              <ChevronLeft className="h-4 w-4" /> Previous
            </button>
            <span className="text-sm text-[var(--muted-foreground)]">{current + 1} / {questions.length}</span>
            <button
              type="button"
              onClick={() =>
                setCurrent((c) => Math.min(questions.length - 1, c + 1))
              }
              disabled={current === questions.length - 1}
              className="flex items-center gap-2 rounded-xl border border-[var(--border)] bg-[var(--foreground)] px-4 py-2.5 text-sm font-medium text-[var(--background)] shadow-sm transition-opacity hover:opacity-90 disabled:opacity-40"
            >
              Next <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
