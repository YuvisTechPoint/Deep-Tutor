"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useTranslation } from "react-i18next";
import {
  AlertCircle,
  CheckCircle2,
  ChevronRight,
  Clock,
  Filter,
  Lightbulb,
  Loader2,
  RefreshCw,
  Sparkles,
  Target,
  Trophy,
  XCircle,
  Zap,
} from "lucide-react";

import {
  checkPracticeAnswer,
  fetchPracticeQuestions,
  fetchPracticeTopics,
  submitPracticeQuiz,
  type PracticeQuestion,
} from "@/lib/workspace-api";
import { OfflineQueuedError } from "@/lib/offline-queue";

type QuizState = "idle" | "in_progress" | "show_result" | "completed";
type Difficulty = "easy" | "medium" | "hard";

const DIFF_STYLE: Record<
  Difficulty,
  { color: string; bg: string }
> = {
  easy: { color: "text-emerald-400", bg: "bg-emerald-500/15 border-emerald-500/30" },
  medium: {
    color: "text-[#D4734B]",
    bg: "bg-[#D4734B]/15 border-[#D4734B]/30",
  },
  hard: {
    color: "text-[#D4734B]",
    bg: "bg-[#D4734B]/15 border-[#D4734B]/30",
  },
};

function practiceTagKey(raw: string): string {
  return raw.replace(/\s+/g, "_").replace(/[^a-zA-Z0-9_]/g, "");
}

export default function PracticePage() {
  const { t } = useTranslation();
  const tr = useCallback(
    (key: string, fallback: string) => t(key, { defaultValue: fallback }),
    [t],
  );
  const searchParams = useSearchParams();
  const milestoneParam = searchParams?.get("milestone") ?? null;

  const [topics, setTopics] = useState<string[]>([]);
  const [topicFilter, setTopicFilter] = useState<string>("all");
  const [diffFilter, setDiffFilter] = useState<Difficulty | "all">("all");
  const [pool, setPool] = useState<PracticeQuestion[]>([]);
  const [quizId, setQuizId] = useState<string | null>(null);
  const [state, setState] = useState<QuizState>("idle");
  const [currentIdx, setCurrentIdx] = useState(0);
  const [selected, setSelected] = useState<string | null>(null);
  const [answers, setAnswers] = useState<{ question_id: string; answer: string }[]>([]);
  /**
   * Per-question feedback once the learner has committed an answer.
   * Reveals come from the server `/practice/check` call (the GET response
   * never includes the answer key). Keyed by ``question_id`` so the result
   * panel can render correctness + the model-generated explanation.
   */
  const [reveals, setReveals] = useState<
    Record<string, { correct: string; is_correct: boolean; explanation: string }>
  >({});
  const [timer, setTimer] = useState(0);
  const [timerInterval, setTimerInterval] = useState<ReturnType<typeof setInterval> | null>(
    null,
  );
  const [showHint, setShowHint] = useState(false);
  const [loading, setLoading] = useState(true);
  const [generating, setGenerating] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [checking, setChecking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [score, setScore] = useState<{
    correct: number;
    total: number;
    awarded_xp: number;
    percentage: number;
  } | null>(null);

  const loadFreshQuiz = useCallback(
    async (opts?: { silent?: boolean }) => {
      const silent = opts?.silent ?? false;
      if (!silent) setGenerating(true);
      setError(null);
      try {
        const qs = await fetchPracticeQuestions({
          topic: topicFilter === "all" ? undefined : topicFilter,
          difficulty: diffFilter === "all" ? undefined : diffFilter,
          limit: 5,
          milestone: milestoneParam ?? undefined,
        });
        setPool(qs.items);
        setQuizId(qs.quiz_id);
        setReveals({});
      } catch (e) {
        setPool([]);
        setQuizId(null);
        setError(
          e instanceof Error
            ? e.message
            : t("practice.err_questions", {
                defaultValue: "Failed to generate a fresh quiz.",
              }),
        );
      } finally {
        if (!silent) setGenerating(false);
      }
    },
    [diffFilter, milestoneParam, t, topicFilter],
  );

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const res = await fetchPracticeTopics();
        if (cancelled) return;
        setTopics(res.topics);
      } catch (e) {
        if (!cancelled) {
          setError(
            e instanceof Error ? e.message : t("practice.err_load", {
              defaultValue: "Failed to load practice topics.",
            }),
          );
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [t]);

  // Re-generate the quiz whenever filters / milestone change AND we're on the
  // idle landing screen. Generation is *always* a live LLM call — there is no
  // pre-fetched bank, so this is the only place quizzes are minted.
  useEffect(() => {
    if (state !== "idle" || loading) return;
    void loadFreshQuiz();
  }, [topicFilter, diffFilter, state, loading, loadFreshQuiz]);

  const current = pool[currentIdx];

  const startQuiz = useCallback(() => {
    setCurrentIdx(0);
    setSelected(null);
    setAnswers([]);
    setShowHint(false);
    setState("in_progress");
    setTimer(0);
    setScore(null);
    setError(null);
    const iv = setInterval(() => setTimer((x) => x + 1), 1000);
    setTimerInterval(iv);
  }, []);

  const stopTimer = useCallback(() => {
    if (timerInterval) {
      clearInterval(timerInterval);
      setTimerInterval(null);
    }
  }, [timerInterval]);

  const submitAnswer = useCallback(async () => {
    if (!selected || !current || !quizId) return;
    setChecking(true);
    setError(null);
    try {
      const reveal = await checkPracticeAnswer({
        quiz_id: quizId,
        question_id: current.id,
        answer: selected,
      });
      setReveals((prev) => ({
        ...prev,
        [current.id]: {
          correct: reveal.correct,
          is_correct: reveal.is_correct,
          explanation: reveal.explanation,
        },
      }));
      setAnswers((prev) => [...prev, { question_id: current.id, answer: selected }]);
      setState("show_result");
      stopTimer();
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : t("practice.err_check", {
              defaultValue: "Could not validate that answer — please retry.",
            }),
      );
    } finally {
      setChecking(false);
    }
  }, [selected, current, quizId, stopTimer, t]);

  const nextQuestion = useCallback(async () => {
    const next = currentIdx + 1;
    if (next >= pool.length) {
      if (!quizId) return;
      setSubmitting(true);
      try {
        const result = await submitPracticeQuiz({
          quiz_id: quizId,
          answers,
          duration_seconds: timer,
        });
        setScore({
          correct: result.score.correct,
          total: result.score.total,
          awarded_xp: result.awarded_xp,
          percentage: result.score.percentage,
        });
        setState("completed");
      } catch (e) {
        if (e instanceof OfflineQueuedError) {
          setError(
            t("practice.offline_queued", {
              defaultValue:
                "You appear offline — your score was queued and will sync when you are back online.",
            }),
          );
          setState("completed");
        } else {
          setError(
            e instanceof Error
              ? e.message
              : t("practice.err_submit", {
                  defaultValue: "Failed to submit quiz.",
                }),
          );
          setState("idle");
        }
      } finally {
        setSubmitting(false);
      }
    } else {
      setCurrentIdx(next);
      setSelected(null);
      setState("in_progress");
      setShowHint(false);
      setTimer(0);
      const iv = setInterval(() => setTimer((x) => x + 1), 1000);
      setTimerInterval(iv);
    }
  }, [currentIdx, pool.length, quizId, answers, timer, t]);

  const formatTime = (s: number) =>
    `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

  const filterTopics = useMemo(() => ["all", ...topics], [topics]);

  const diffLabel = useCallback(
    (d: Difficulty | "all") =>
      d === "all" ? t("practice.all_difficulties") : t(`practice.diff.${d}`),
    [t],
  );

  const topicLabel = useCallback(
    (tid: string) =>
      tid === "all"
        ? t("practice.all_topics")
        : t(`practice.topic.${tid}`, { defaultValue: tid }),
    [t],
  );

  const tagLabel = useCallback(
    (tag: string) =>
      t(`practice.tag.${practiceTagKey(tag)}`, { defaultValue: tag }),
    [t],
  );

  const roleLabel = useCallback(
    (role: string) => t(`practice.role.${role}`, { defaultValue: role }),
    [t],
  );

  const qText = useCallback(
    (q: PracticeQuestion, field: "question" | "explanation") =>
      tr(`practice.q.${q.id}.${field}`, field === "question" ? q.question : q.explanation),
    [tr],
  );

  const optText = useCallback(
    (q: PracticeQuestion, key: string, fallback: string) =>
      tr(`practice.q.${q.id}.opt.${key}`, fallback),
    [tr],
  );

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center gap-2 text-[var(--muted-foreground)]">
        <Loader2 className="h-5 w-5 animate-spin" />
        <span>{t("practice.loading")}</span>
      </div>
    );
  }

  if (state === "completed" && score) {
    const pct = score.percentage;
    return (
      <div className="flex h-screen flex-col items-center justify-center bg-[var(--background)] px-4">
        <div className="w-full max-w-md rounded-2xl border border-white/5 bg-[var(--secondary)] p-8 text-center">
          <Trophy className="mx-auto mb-4 h-12 w-12 text-[#D4734B]" />
          <h2 className="mb-1 text-2xl font-bold text-[var(--foreground)]">
            {t("practice.session_complete")}
          </h2>
          <p className="mb-6 text-[var(--muted-foreground)]">
            {t("practice.correct_ratio", {
              correct: score.correct,
              total: score.total,
            })}
          </p>
          <div className="mb-6 flex items-center justify-center gap-4">
            <div className="text-center">
              <p
                className={`text-4xl font-black ${
                  pct >= 80 ? "text-emerald-400" : "text-[#D4734B]"
                }`}
              >
                {pct}%
              </p>
              <p className="text-xs text-[var(--muted-foreground)]">
                {t("practice.score_label")}
              </p>
            </div>
            <div className="text-center">
              <p className="text-4xl font-black text-[#D4734B]">+{score.awarded_xp}</p>
              <p className="text-xs text-[var(--muted-foreground)]">
                {t("practice.xp_earned")}
              </p>
            </div>
          </div>
          <div className="mb-6 h-3 overflow-hidden rounded-full bg-white/10">
            <div
              className={`h-full rounded-full transition-all ${
                pct >= 80 ? "bg-emerald-400" : "bg-[#D4734B]"
              }`}
              style={{ width: `${pct}%` }}
            />
          </div>
          <div className="flex gap-3">
            <button
              type="button"
              onClick={() => setState("idle")}
              className="flex-1 rounded-xl bg-white/10 py-2.5 text-sm font-semibold text-[var(--foreground)] hover:bg-white/15"
            >
              {t("practice.back")}
            </button>
            <button
              type="button"
              onClick={startQuiz}
              className="flex-1 rounded-xl bg-[#D4734B] py-2.5 text-sm font-semibold text-white hover:bg-[#c26244]"
            >
              {t("practice.retry")}
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (state === "idle") {
    return (
      <div className="flex h-screen flex-col bg-[var(--background)]">
        <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
          <div className="mx-auto flex max-w-3xl items-center gap-3">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-[#D4734B] to-[#b85a3a] shadow-lg shadow-[#D4734B]/30">
              <Target className="h-4 w-4 text-white" />
            </div>
            <div>
              <h1 className="text-sm font-bold text-[var(--foreground)]">
                {t("practice.page_title")}
              </h1>
              <p className="text-[11px] text-[var(--muted-foreground)]">
                {t("practice.page_subtitle")}
              </p>
            </div>
          </div>
        </header>

        <div className="flex-1 overflow-y-auto px-4 py-6 sm:px-6">
          <div className="mx-auto max-w-3xl space-y-6">
            {error && (
              <div className="rounded-xl border border-[#D4734B]/30 bg-[#D4734B]/10 px-4 py-3 text-sm text-[#f0c4b8]">
                {error}
              </div>
            )}

            <div className="space-y-3">
              <div className="flex flex-wrap gap-2">
                <Filter className="h-4 w-4 shrink-0 self-center text-[var(--muted-foreground)]" />
                {filterTopics.map((tid) => (
                  <button
                    key={tid}
                    type="button"
                    onClick={() => setTopicFilter(tid)}
                    className={`rounded-full px-3 py-1 text-xs font-medium transition-colors capitalize ${
                      topicFilter === tid
                        ? "bg-[#D4734B] text-white"
                        : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
                    }`}
                  >
                    {topicLabel(tid)}
                  </button>
                ))}
              </div>
              <div className="flex flex-wrap gap-2">
                {(["all", "easy", "medium", "hard"] as const).map((d) => (
                  <button
                    key={d}
                    type="button"
                    onClick={() => setDiffFilter(d)}
                    className={`rounded-full px-3 py-1 text-xs font-medium transition-colors capitalize ${
                      diffFilter === d
                        ? "bg-[#D4734B] text-white"
                        : "bg-white/5 text-[var(--muted-foreground)] hover:bg-white/10"
                    }`}
                  >
                    {diffLabel(d)}
                  </button>
                ))}
              </div>
            </div>

            <div className="flex items-center justify-between gap-3 rounded-xl border border-[#D4734B]/25 bg-[#D4734B]/8 px-4 py-2.5">
              <div className="flex items-center gap-2 text-[11px] text-[#f0c4b8]">
                <Sparkles className="h-3.5 w-3.5" />
                <span>
                  {t("practice.live_generated", {
                    defaultValue:
                      "Every quiz is generated live by the AI tutor. Nothing is stored.",
                  })}
                </span>
              </div>
              <button
                type="button"
                onClick={() => void loadFreshQuiz()}
                disabled={generating}
                className="inline-flex items-center gap-1.5 rounded-lg border border-[#D4734B]/40 bg-[#D4734B]/20 px-2.5 py-1 text-[11px] font-medium text-[#f0c4b8] transition-colors hover:bg-[#D4734B]/30 disabled:opacity-50"
              >
                <RefreshCw className={`h-3 w-3 ${generating ? "animate-spin" : ""}`} />
                {generating
                  ? t("practice.regenerating", { defaultValue: "Generating…" })
                  : t("practice.regenerate", { defaultValue: "New questions" })}
              </button>
            </div>

            <div className="space-y-3">
              {generating && pool.length === 0 ? (
                <div className="flex flex-col items-center justify-center gap-3 rounded-2xl border border-white/5 bg-[var(--secondary)] px-4 py-12 text-center">
                  <Loader2 className="h-6 w-6 animate-spin text-[#D4734B]" />
                  <p className="text-sm font-medium text-[var(--foreground)]">
                    {t("practice.generating_title", {
                      defaultValue: "Asking the AI tutor for fresh questions…",
                    })}
                  </p>
                  <p className="text-xs text-[var(--muted-foreground)]">
                    {t("practice.generating_body", {
                      defaultValue:
                        "Five new questions are being authored just for you. This is not a pre-saved bank.",
                    })}
                  </p>
                </div>
              ) : (
                pool.map((q, i) => {
                  const dc = DIFF_STYLE[q.difficulty];
                  return (
                    <div
                      key={q.id}
                      className="flex items-center gap-4 rounded-xl border border-white/5 bg-[var(--secondary)] px-4 py-3"
                    >
                      <span className="w-5 text-sm font-bold text-[var(--muted-foreground)]">
                        {i + 1}
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="line-clamp-1 text-sm font-medium text-[var(--foreground)]">
                          {qText(q, "question")}
                        </p>
                        <div className="mt-1 flex flex-wrap gap-1.5">
                          <span className="text-[10px] capitalize text-[#D4734B]">
                            {topicLabel(q.topic)}
                          </span>
                          {q.tags.slice(0, 2).map((tag) => (
                            <span
                              key={tag}
                              className="rounded-full border border-[#D4734B]/25 bg-[#D4734B]/12 px-1.5 text-[10px] text-[#f0b8a6]"
                            >
                              {tagLabel(tag)}
                            </span>
                          ))}
                          <span className="rounded-full border border-[#D4734B]/30 bg-[#D4734B]/10 px-1.5 text-[10px] text-[#f0b8a6]">
                            {roleLabel(q.model_role)}
                          </span>
                        </div>
                      </div>
                      <span
                        className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${dc.bg} ${dc.color}`}
                      >
                        {diffLabel(q.difficulty)}
                      </span>
                    </div>
                  );
                })
              )}
              {!generating && pool.length === 0 && !error && (
                <p className="rounded-xl border border-white/5 bg-white/5 px-4 py-6 text-center text-sm text-[var(--muted-foreground)]">
                  {t("practice.no_match", {
                    defaultValue:
                      "No questions yet — pick a topic / difficulty and we'll generate a fresh set.",
                  })}
                </p>
              )}
            </div>

            <button
              type="button"
              onClick={startQuiz}
              disabled={pool.length === 0 || generating || !quizId}
              className="flex w-full items-center justify-center gap-2 rounded-xl bg-[#D4734B] py-3 text-sm font-semibold text-white shadow-lg shadow-[#D4734B]/25 transition-colors hover:bg-[#c26244] disabled:cursor-not-allowed disabled:opacity-40"
            >
              <Zap className="h-4 w-4" />
              {t("practice.start_quiz", {
                count: pool.length,
                defaultValue: `Start ${pool.length}-question quiz`,
              })}
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (!current) return null;
  const dc = DIFF_STYLE[current.difficulty];
  const isAnswered = state === "show_result";
  const reveal = reveals[current.id];
  const correctKey = reveal?.correct ?? null;
  const explanationText = reveal?.explanation ?? "";
  const isCorrect = isAnswered && !!reveal && reveal.is_correct;

  return (
    <div className="flex h-screen flex-col bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-3">
        <div className="mx-auto flex max-w-3xl items-center gap-4">
          <div className="min-w-0 flex-1">
            <div className="mb-1 flex flex-wrap items-center gap-2">
              <span className="text-xs text-[var(--muted-foreground)]">
                {t("practice.progress_label", {
                  current: currentIdx + 1,
                  total: pool.length,
                })}
              </span>
              <span
                className={`rounded-full border px-2 py-0.5 text-[10px] font-semibold ${dc.bg} ${dc.color}`}
              >
                {diffLabel(current.difficulty)}
              </span>
              <span className="text-[10px] capitalize text-[#D4734B]">
                {topicLabel(current.topic)}
              </span>
              <span className="rounded-full border border-[#D4734B]/30 bg-[#D4734B]/10 px-2 py-0.5 text-[10px] font-semibold text-[#f0b8a6]">
                {roleLabel(current.model_role)}
              </span>
            </div>
            <div className="h-1.5 overflow-hidden rounded-full bg-white/10">
              <div
                className="h-full rounded-full bg-gradient-to-r from-[#D4734B] to-[#b85a3a] transition-all"
                style={{ width: `${(currentIdx / pool.length) * 100}%` }}
              />
            </div>
          </div>
          <div className="flex shrink-0 items-center gap-1.5 rounded-lg bg-white/5 px-3 py-1.5">
            <Clock className="h-3.5 w-3.5 text-[var(--muted-foreground)]" />
            <span className="font-mono text-xs text-[var(--foreground)]">
              {formatTime(timer)}
            </span>
          </div>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto px-4 py-6 sm:px-6">
        <div className="mx-auto max-w-3xl space-y-6">
          <div className="rounded-2xl border border-white/5 bg-[var(--secondary)] p-6">
            <h2 className="text-base font-semibold leading-relaxed text-[var(--foreground)]">
              {qText(current, "question")}
            </h2>
            <div className="mt-2 flex flex-wrap gap-1.5">
              {current.tags.map((tag) => (
                <span
                  key={tag}
                  className="rounded-full border border-[#D4734B]/25 bg-[#D4734B]/12 px-2 py-0.5 text-[10px] text-[#f0b8a6]"
                >
                  {tagLabel(tag)}
                </span>
              ))}
            </div>
          </div>

          <div className="space-y-2.5">
            {current.options.map((opt) => {
              let cls =
                "border-white/5 bg-[var(--secondary)] hover:border-[#D4734B]/30 hover:bg-[#D4734B]/5";
              if (isAnswered) {
                if (correctKey && opt.key === correctKey)
                  cls = "border-emerald-500/50 bg-emerald-500/10";
                else if (opt.key === selected)
                  cls = "border-[#D4734B]/50 bg-[#D4734B]/12";
                else cls = "border-white/5 bg-[var(--secondary)] opacity-50";
              } else if (selected === opt.key) {
                cls = "border-[#D4734B]/50 bg-[#D4734B]/15";
              }
              return (
                <button
                  key={opt.key}
                  type="button"
                  disabled={isAnswered}
                  onClick={() => setSelected(opt.key)}
                  className={`flex w-full items-center gap-3 rounded-xl border px-5 py-3.5 text-left transition-all ${cls}`}
                >
                  <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full border border-current text-xs font-bold text-[var(--muted-foreground)]">
                    {opt.key}
                  </span>
                  <span className="text-sm text-[var(--foreground)]">
                    {optText(current, opt.key, opt.text)}
                  </span>
                  {isAnswered && correctKey && opt.key === correctKey && (
                    <CheckCircle2 className="ml-auto h-4 w-4 text-emerald-400" />
                  )}
                  {isAnswered && correctKey && opt.key === selected && opt.key !== correctKey && (
                    <XCircle className="ml-auto h-4 w-4 text-[#D4734B]" />
                  )}
                </button>
              );
            })}
          </div>

          {!isAnswered && (
            <button
              type="button"
              onClick={() => setShowHint((v) => !v)}
              className="flex items-center gap-2 text-xs text-[#D4734B] transition-colors hover:text-[#e88a68]"
            >
              <Lightbulb className="h-3.5 w-3.5" />
              {showHint ? t("practice.hide_hint") : t("practice.show_hint")}
            </button>
          )}
          {showHint && !isAnswered && (
            <div className="rounded-xl border border-[#D4734B]/25 bg-[#D4734B]/10 px-4 py-3 text-sm text-[#f0c4b8]">
              {t("practice.hint_body")}
            </div>
          )}

          {isAnswered && (
            <div
              className={`rounded-xl border px-5 py-4 ${
                isCorrect
                  ? "border-emerald-500/30 bg-emerald-500/10"
                  : "border-[#D4734B]/30 bg-[#D4734B]/10"
              }`}
            >
              <div className="mb-2 flex items-center gap-2">
                {isCorrect ? (
                  <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                ) : (
                  <AlertCircle className="h-4 w-4 text-[#D4734B]" />
                )}
                <span
                  className={`text-sm font-semibold ${
                    isCorrect ? "text-emerald-400" : "text-[#D4734B]"
                  }`}
                >
                  {isCorrect
                    ? t("practice.result_correct")
                    : t("practice.result_incorrect", { answer: correctKey ?? "?" })}
                </span>
              </div>
              <p className="text-sm leading-relaxed text-[var(--foreground)]">
                {explanationText || qText(current, "explanation")}
              </p>
              <p className="mt-2 text-[10px] text-[#D4734B]">
                {t("practice.tutor_role", { role: roleLabel(current.model_role) })}
              </p>
            </div>
          )}

          <div className="flex gap-3">
            {!isAnswered ? (
              <>
                <button
                  type="button"
                  onClick={() => {
                    setState("idle");
                    stopTimer();
                  }}
                  className="rounded-xl bg-white/5 px-4 py-2.5 text-sm font-medium text-[var(--muted-foreground)] transition-colors hover:bg-white/10"
                >
                  {t("practice.quit")}
                </button>
                <button
                  type="button"
                  onClick={() => void submitAnswer()}
                  disabled={!selected || checking}
                  className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-[#D4734B] py-2.5 text-sm font-semibold text-white transition-colors hover:bg-[#c26244] disabled:cursor-not-allowed disabled:opacity-40"
                >
                  {checking ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    t("practice.submit_answer")
                  )}
                </button>
              </>
            ) : (
              <button
                type="button"
                onClick={() => void nextQuestion()}
                disabled={submitting}
                className="flex w-full items-center justify-center gap-2 rounded-xl bg-[#D4734B] py-2.5 text-sm font-semibold text-white transition-colors hover:bg-[#c26244] disabled:opacity-60"
              >
                {submitting ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : currentIdx + 1 < pool.length ? (
                  <>
                    <ChevronRight className="h-4 w-4" />
                    {t("practice.next_question")}
                  </>
                ) : (
                  <>
                    <Trophy className="h-4 w-4" />
                    {t("practice.submit_results")}
                  </>
                )}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
