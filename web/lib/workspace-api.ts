/**
 * Workspace API clients — typed wrappers around FastAPI surfaces for learner UI.
 *
 * GET helpers treat HTTP **404** as “endpoint unavailable” (older backend image,
 * wrong NEXT_PUBLIC_API_BASE pointing at the Next dev server, or reverse-proxy
 * miss) and return typed empty defaults instead of throwing. That avoids scary
 * `Exchange failed (404)` banners on EIP/Dashboard/etc. Mutating endpoints still
 * surface errors normally.
 */

import { apiFetch, apiUrl, summarizeHttpErrorBody } from "@/lib/api";
import {
  OfflineQueuedError,
  enqueueOfflineMutation,
} from "@/lib/offline-queue";

const FALLBACK_WARN_PREFIX = "dt_workspace_api_fallback_warned:";

function warn404Once(kind: string): void {
  if (typeof window === "undefined") return;
  try {
    const key = `${FALLBACK_WARN_PREFIX}${kind}`;
    if (sessionStorage.getItem(key)) return;
    sessionStorage.setItem(key, "1");
    console.warn(
      `[DeepTutor] ${kind} returned 404 — using local defaults. ` +
        `Ensure the FastAPI backend is running and NEXT_PUBLIC_API_BASE targets ` +
        `that server (not this Next.js port). Restart backend after upgrades.`,
    );
  } catch {
    /* ignore storage quota / privacy mode */
  }
}

async function workspaceGetJson<T>(path: string, fallback404: T, kind: string): Promise<T> {
  const res = await apiFetch(apiUrl(path), { cache: "no-store" });
  if (res.status === 404) {
    warn404Once(kind);
    return fallback404;
  }
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(summarizeHttpErrorBody(res.status, text));
  }
  return (await res.json()) as T;
}

async function sendJson<T>(
  path: string,
  body: unknown,
  method: "POST" | "PUT" | "PATCH" | "DELETE" = "POST",
): Promise<T> {
  const res = await apiFetch(apiUrl(path), {
    method,
    headers: { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(summarizeHttpErrorBody(res.status, text));
  }
  return (await res.json()) as T;
}

// ─── Empty payloads (mirror backend shapes) ─────────────────────────────────

export const EMPTY_LEVEL: LevelInfo = {
  level: 1,
  xp_into_level: 0,
  xp_for_next_level: 1000,
  total_xp: 0,
  progress_pct: 0,
};

function emptyGamificationState(): GamificationState {
  const ts = new Date().toISOString();
  return {
    total_xp: 0,
    streak_current: 0,
    streak_max: 0,
    event_count: 0,
    xp_per_day: {},
    xp_per_source: {},
    active_days: [],
    badges_unlocked: {},
    mission_completions: {},
    level: { ...EMPTY_LEVEL },
    last_synced_at: ts,
  };
}

function emptyLearningPlan(): LearningPlan {
  return {
    plan_id: "offline",
    title: "Learning roadmap",
    summary:
      "Your roadmap API returned 404. Start the DeepTutor backend on BACKEND_PORT and confirm NEXT_PUBLIC_API_BASE.",
    is_preview: true,
    weekly_hours: 0,
    experience_level: "",
    totals: {
      milestones_total: 0,
      milestones_completed: 0,
      xp_completed: 0,
      progress_pct: 0,
    },
    phases: [],
    generated_at: new Date().toISOString(),
    profile_summary: {
      target_path: "",
      goals: [],
      weekly_hours: null,
      experience_level: "",
    },
  };
}

function emptyMissionsToday(): MissionsToday {
  const today = new Date().toISOString().slice(0, 10);
  return {
    date: today,
    missions: [],
    bonus: {
      id: "bonus-offline",
      title: "Bonus XP block",
      description: "Backend roadmap unavailable — open Practice after fixing API routing.",
      xp: 25,
      duration: "15 min",
      cta_href: "/practice",
      model_roles: ["general"],
    },
    totals: { completed: 0, total: 0, xp_earned: 0, xp_target: 0 },
  };
}

function emptyAnalyticsSummary(window: "7d" | "30d" | "90d"): AnalyticsSummary {
  return {
    range: window,
    sessions: 0,
    accuracy: 0,
    problems: 0,
    hours: 0,
    streak_current: 0,
    streak_max: 0,
    total_xp: 0,
    level: { ...EMPTY_LEVEL },
    xp_per_day: {},
    preview: true,
  };
}

function emptyXPTrend(window: "7d" | "30d" | "90d"): { range: string; series: XPTrendPoint[] } {
  const days = window === "7d" ? 7 : window === "90d" ? 90 : 30;
  const today = new Date();
  const series: XPTrendPoint[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    series.push({ date: d.toISOString().slice(0, 10), xp: 0 });
  }
  return { range: window, series };
}

const FALLBACK_PRACTICE_TOPICS = [
  "algorithms",
  "dp",
  "python",
  "system_design",
  "math",
  "aptitude",
];

// ─── Gamification ─────────────────────────────────────────────────────────────

export interface LevelInfo {
  level: number;
  xp_into_level: number;
  xp_for_next_level: number;
  total_xp: number;
  progress_pct: number;
}

export interface GamificationState {
  total_xp: number;
  streak_current: number;
  streak_max: number;
  event_count: number;
  xp_per_day: Record<string, number>;
  xp_per_source: Record<string, number>;
  active_days: string[];
  badges_unlocked: Record<string, string>;
  mission_completions: Record<string, string>;
  level: LevelInfo;
  last_synced_at: string;
}

export interface XPHistoryItem {
  event_id: string;
  action: string;
  xp: number;
  source: string;
  timestamp: string;
  metadata?: Record<string, unknown>;
}

export function fetchGamificationState() {
  return workspaceGetJson<GamificationState>(
    "/api/v1/gamification/state",
    emptyGamificationState(),
    "GET /api/v1/gamification/state",
  );
}

export function fetchXPHistory(limit = 20) {
  return workspaceGetJson<{ items: XPHistoryItem[] }>(
    `/api/v1/gamification/xp-history?limit=${limit}`,
    { items: [] },
    "GET /api/v1/gamification/xp-history",
  );
}

export interface BadgeStatus {
  badge_id: string;
  icon: string;
  title: string;
  description: string;
  xp_reward: number;
  condition: string;
  rare: boolean;
  status: "unlocked" | "in-progress" | "locked";
  unlocked_at?: string | null;
  progress?: number | null;
  progress_max?: number | null;
}

export function fetchBadges() {
  return workspaceGetJson<{ badges: BadgeStatus[]; catalog_size: number }>(
    "/api/v1/gamification/badges",
    { badges: [], catalog_size: 0 },
    "GET /api/v1/gamification/badges",
  );
}

export interface AwardEvent {
  event: XPHistoryItem;
  state: GamificationState;
}

export function awardXP(payload: {
  action: string;
  xp: number;
  source: string;
  metadata?: Record<string, unknown>;
}) {
  return sendJson<AwardEvent>("/api/v1/gamification/award", payload);
}

// ─── Achievements ─────────────────────────────────────────────────────────────

export interface AchievementsBundle {
  total_xp: number;
  level: LevelInfo;
  achievements: BadgeStatus[];
  catalog_size: number;
}

export function fetchAchievements() {
  return workspaceGetJson<AchievementsBundle>(
    "/api/v1/achievements",
    {
      total_xp: 0,
      level: { ...EMPTY_LEVEL },
      achievements: [],
      catalog_size: 0,
    },
    "GET /api/v1/achievements",
  );
}

export function fetchLeaderboard() {
  return workspaceGetJson<{
    preview: boolean;
    label: string;
    rows: {
      rank: number;
      name: string;
      level: number;
      xp: number;
      you: boolean;
    }[];
  }>(
    "/api/v1/achievements/leaderboard",
    {
      preview: true,
      label: "offline-fallback",
      rows: [{ rank: 1, name: "You", level: 1, xp: 0, you: true }],
    },
    "GET /api/v1/achievements/leaderboard",
  );
}

// ─── Notifications ────────────────────────────────────────────────────────────

export type NotificationType =
  | "streak_reminder"
  | "achievement_unlocked"
  | "mentor_message"
  | "system_update"
  | "quiz_available"
  | "new_roadmap_item";

export interface NotificationItem {
  id: string;
  type: string;
  title: string;
  message: string;
  created_at: string;
  read: boolean;
  read_at?: string | null;
  is_mention: boolean;
  is_system: boolean;
  action_label?: string | null;
  action_href?: string | null;
  metadata?: Record<string, unknown>;
}

export function fetchNotifications() {
  return workspaceGetJson<{
    items: NotificationItem[];
    counts: {
      total: number;
      unread: number;
      mentions: number;
      system: number;
    };
  }>(
    "/api/v1/notifications",
    {
      items: [],
      counts: { total: 0, unread: 0, mentions: 0, system: 0 },
    },
    "GET /api/v1/notifications",
  );
}

export function markNotificationRead(id: string) {
  return sendJson<{ id: string; read: boolean }>(
    `/api/v1/notifications/${encodeURIComponent(id)}/read`,
    undefined,
  );
}

export function markAllNotificationsRead() {
  return sendJson<{ updated: number }>(
    "/api/v1/notifications/mark-all-read",
    undefined,
  );
}

export function dismissNotification(id: string) {
  return sendJson<{ id: string; dismissed: boolean }>(
    `/api/v1/notifications/${encodeURIComponent(id)}`,
    undefined,
    "DELETE",
  );
}

// ─── Learning plan (Roadmap) ──────────────────────────────────────────────────

export interface RoadmapResource {
  title: string;
  type: "video" | "article" | "exercise" | "project";
  duration: string;
  url?: string;
}

export interface RoadmapMilestone {
  id: string;
  title: string;
  description: string;
  xp: number;
  estimated_days: number;
  skills: string[];
  model_roles: string[];
  resources: RoadmapResource[];
  status: "completed" | "active" | "locked" | "available";
  auto_completed: boolean;
  trigger_actions: string[];
}

export interface RoadmapPhase {
  id: string;
  title: string;
  subtitle: string;
  status: "completed" | "active" | "locked";
  milestones: RoadmapMilestone[];
}

export interface LearningPlan {
  plan_id: string;
  title: string;
  summary: string;
  is_preview: boolean;
  weekly_hours: number;
  experience_level: string;
  totals: {
    milestones_total: number;
    milestones_completed: number;
    xp_completed: number;
    progress_pct: number;
  };
  phases: RoadmapPhase[];
  generated_at: string;
  profile_summary?: {
    target_path: string;
    goals: string[];
    weekly_hours: number | null;
    experience_level: string;
  };
}

export function fetchLearningPlan() {
  return workspaceGetJson<LearningPlan>(
    "/api/v1/learning-plan",
    emptyLearningPlan(),
    "GET /api/v1/learning-plan",
  );
}

export function updateMilestoneStatus(milestoneId: string, status: string) {
  return sendJson<{
    milestone_id: string;
    status_record: { status: string; updated_at: string };
  }>(
    `/api/v1/learning-plan/milestones/${encodeURIComponent(milestoneId)}`,
    { status },
    "PATCH",
  );
}

// ─── Missions ─────────────────────────────────────────────────────────────────

export interface MissionItem {
  id: string;
  title: string;
  description: string;
  category: string;
  xp: number;
  duration: string;
  icon: string;
  color: string;
  cta_href: string;
  model_roles: string[];
  status: "available" | "completed";
  requires_feature?: string;
}

export interface MissionsToday {
  date: string;
  missions: MissionItem[];
  bonus: {
    id: string;
    title: string;
    description: string;
    xp: number;
    duration: string;
    cta_href: string;
    model_roles: string[];
  };
  totals: {
    completed: number;
    total: number;
    xp_earned: number;
    xp_target: number;
  };
}

export function fetchMissionsToday() {
  return workspaceGetJson<MissionsToday>(
    "/api/v1/missions/today",
    emptyMissionsToday(),
    "GET /api/v1/missions/today",
  );
}

export async function completeMission(missionId: string, xpReward?: number) {
  const path = `/api/v1/missions/${encodeURIComponent(missionId)}/complete`;
  const body = { mission_id: missionId, xp_reward: xpReward };
  if (typeof navigator !== "undefined" && !navigator.onLine) {
    await enqueueOfflineMutation("POST", path, body);
    throw new OfflineQueuedError("mission_complete");
  }
  return sendJson<{
    mission_id: string;
    already_completed: boolean;
    event?: XPHistoryItem;
  }>(path, body);
}

// ─── Career ──────────────────────────────────────────────────────────────────

export type CareerSkillLevel = "none" | "beginner" | "intermediate" | "advanced";

export interface CareerSkill {
  name: string;
  required: CareerSkillLevel;
  current: CareerSkillLevel;
  weight: number;
}

export interface CareerPath {
  id: string;
  title: string;
  description: string;
  company_types: string[];
  avg_salary: string;
  demand: "high" | "medium" | "low";
  timeline: string;
  projects: string[];
  skills: CareerSkill[];
  model_roles: string[];
  readiness: number;
}

export function fetchCareerPaths() {
  return workspaceGetJson<{
    preview: boolean;
    rationale: string;
    paths: CareerPath[];
    profile_summary: {
      target_path: string;
      experience_level: string;
      goals: string[];
    };
  }>(
    "/api/v1/career/paths",
    {
      preview: true,
      rationale: "Career API unavailable (404). Check backend version and NEXT_PUBLIC_API_BASE.",
      paths: [],
      profile_summary: { target_path: "", experience_level: "", goals: [] },
    },
    "GET /api/v1/career/paths",
  );
}

// ─── Analytics ───────────────────────────────────────────────────────────────

export interface AnalyticsSummary {
  range: string;
  sessions: number;
  accuracy: number;
  problems: number;
  hours: number;
  streak_current: number;
  streak_max: number;
  total_xp: number;
  level: LevelInfo;
  xp_per_day: Record<string, number>;
  preview: boolean;
}

export function fetchAnalyticsSummary(window: "7d" | "30d" | "90d") {
  return workspaceGetJson<AnalyticsSummary>(
    `/api/v1/analytics/summary?window=${window}`,
    emptyAnalyticsSummary(window),
    "GET /api/v1/analytics/summary",
  );
}

export interface TopicMastery {
  topic: string;
  mastery: number;
  answers: number;
}

export function fetchTopicMastery() {
  return workspaceGetJson<{ items: TopicMastery[] }>(
    "/api/v1/analytics/topic-mastery",
    { items: [] },
    "GET /api/v1/analytics/topic-mastery",
  );
}

export interface XPTrendPoint {
  date: string;
  xp: number;
}

export function fetchXPTrend(window: "7d" | "30d" | "90d") {
  return workspaceGetJson<{ range: string; series: XPTrendPoint[] }>(
    `/api/v1/analytics/xp-trend?window=${window}`,
    emptyXPTrend(window),
    "GET /api/v1/analytics/xp-trend",
  );
}

export function fetchTimeDistribution() {
  return workspaceGetJson<{ items: { label: string; pct: number; xp: number }[] }>(
    "/api/v1/analytics/time-distribution",
    { items: [] },
    "GET /api/v1/analytics/time-distribution",
  );
}

export interface WeakArea {
  topic: string;
  mastery: number;
  answers: number;
  action: string;
  recommended_model_role: string;
}

export function fetchWeakAreas() {
  return workspaceGetJson<{ items: WeakArea[]; preview: boolean }>(
    "/api/v1/analytics/weak-areas",
    { items: [], preview: true },
    "GET /api/v1/analytics/weak-areas",
  );
}

// ─── Practice ────────────────────────────────────────────────────────────────

export interface PracticeQuestion {
  id: string;
  topic: string;
  difficulty: "easy" | "medium" | "hard";
  question: string;
  options: { key: string; text: string }[];
  /**
   * The server strips the answer key (`correct`) and `explanation` from the
   * GET /questions response so they never leave the backend until the learner
   * has answered. Both are optional client-side and only ever populated after
   * the page transitions into local "answered" state from cached question
   * data the client itself stored. Treat as defensive — the server response
   * will not include them.
   */
  correct?: string;
  explanation?: string;
  tags: string[];
  model_role: string;
}

export interface PracticeQuestionsResponse {
  quiz_id: string;
  items: PracticeQuestion[];
  generated: boolean;
  filters: {
    topic: string | null;
    difficulty: string | null;
    limit: number;
    milestone: string | null;
  };
}

export function fetchPracticeTopics() {
  return workspaceGetJson<{ topics: string[] }>(
    "/api/v1/practice/topics",
    { topics: [...FALLBACK_PRACTICE_TOPICS] },
    "GET /api/v1/practice/topics",
  );
}

export async function fetchPracticeQuestions(params: {
  topic?: string;
  difficulty?: string;
  limit?: number;
  milestone?: string;
}): Promise<PracticeQuestionsResponse> {
  const search = new URLSearchParams();
  if (params.topic && params.topic !== "all") search.set("topic", params.topic);
  if (params.difficulty && params.difficulty !== "all")
    search.set("difficulty", params.difficulty);
  if (params.limit) search.set("limit", String(params.limit));
  if (params.milestone) search.set("milestone", params.milestone);
  const qs = search.toString();
  const path = `/api/v1/practice/questions${qs ? `?${qs}` : ""}`;

  // We intentionally do NOT use the silent-404 fallback path here — the
  // realtime generator must surface 503 / 410 errors so the UI can show a
  // "couldn't reach the LLM, retry" state instead of a phantom empty quiz.
  const res = await apiFetch(apiUrl(path), { cache: "no-store" });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(summarizeHttpErrorBody(res.status, text));
  }
  return (await res.json()) as PracticeQuestionsResponse;
}

export interface QuizScore {
  correct: number;
  incorrect: number;
  total: number;
  percentage: number;
  per_topic: Record<string, { correct: number; incorrect: number }>;
}

export type QuizSubmitResponse = {
  score: QuizScore;
  awarded_xp: number;
  events: XPHistoryItem[];
};

export async function submitPracticeQuiz(payload: {
  quiz_id: string;
  answers: { question_id: string; answer: string }[];
  duration_seconds?: number;
}) {
  if (typeof navigator !== "undefined" && !navigator.onLine) {
    await enqueueOfflineMutation("POST", "/api/v1/practice/submit", payload);
    throw new OfflineQueuedError("practice_submit");
  }
  return sendJson<QuizSubmitResponse>("/api/v1/practice/submit", payload);
}

export interface DiagnosticStartResponse {
  quiz_id: string;
  items: Array<{
    id: string;
    topic: string;
    difficulty: string;
    question: string;
    options: { key: string; text: string }[];
    tags: string[];
    model_role: string;
  }>;
  num_questions: number;
}

export async function diagnosticStart(): Promise<DiagnosticStartResponse> {
  return sendJson<DiagnosticStartResponse>("/api/v1/diagnostic/start", {});
}

export async function diagnosticFinish(payload: {
  quiz_id: string;
  answers: { question_id: string; answer: string }[];
  duration_seconds?: number;
}): Promise<QuizSubmitResponse> {
  return sendJson<QuizSubmitResponse>("/api/v1/diagnostic/finish", payload);
}

export interface RevisionCardItem {
  id: string;
  topic: string;
  due_at_ms: number;
  ease: number;
  repetitions: number;
  state: string;
}

export async function fetchRevisionQueue(limit = 20) {
  return workspaceGetJson<{ items: RevisionCardItem[]; count: number }>(
    `/api/v1/revision/queue?limit=${encodeURIComponent(String(limit))}`,
    { items: [], count: 0 },
    "GET /api/v1/revision/queue",
  );
}

export async function postRevisionReview(
  cardId: string,
  grade: "again" | "good" | "easy",
) {
  return sendJson<{ card: RevisionCardItem }>("/api/v1/revision/review", {
    card_id: cardId,
    grade,
  });
}

export interface PracticeCheckResponse {
  question_id: string;
  correct: string;
  is_correct: boolean;
  explanation: string;
}

export function checkPracticeAnswer(payload: {
  quiz_id: string;
  question_id: string;
  answer: string;
}): Promise<PracticeCheckResponse> {
  return sendJson<PracticeCheckResponse>("/api/v1/practice/check", payload);
}

// ─── Model routing (canonical OSS catalogue) ─────────────────────────────────

export interface ModelCatalogEntry {
  intent: string;
  model: string;
  description: string;
  env_override: string;
  backend: string;
  self_hosted: boolean;
  api_base: string;
  auxiliary?: boolean;
}

export function fetchModelCatalog() {
  return workspaceGetJson<{ entries: ModelCatalogEntry[] }>(
    "/api/v1/model-routing/catalog",
    { entries: [] },
    "GET /api/v1/model-routing/catalog",
  );
}

export interface FeatureSurface {
  surface: string;
  primary_role: string | null;
  primary_model: string | null;
  supporting: { role: string; model: string }[];
  disabled_when_role_missing: boolean;
}

export function fetchFeatureSurfaces() {
  return workspaceGetJson<{ surfaces: FeatureSurface[] }>(
    "/api/v1/model-routing/feature-surfaces",
    { surfaces: [] },
    "GET /api/v1/model-routing/feature-surfaces",
  );
}

// ─── Learner Workflow (cross-feature) ─────────────────────────────────────────
//
// The workflow service stitches Practice / Assessments / Missions / Roadmap /
// Chat / TutorBot into a single learner journey on the backend. Two endpoints
// are exposed:
//
//   GET /api/v1/workflow/journey  — full snapshot for the dashboard
//   GET /api/v1/workflow/next     — single best next-action CTA
//
// See `deeptutor/services/workflow/` for the orchestrator.

export type NextActionKind =
  | "practice"
  | "tutor"
  | "assessment"
  | "mission"
  | "co_writer"
  | "onboarding";

export interface NextAction {
  kind: NextActionKind;
  title: string;
  description: string;
  href: string;
  milestone_id: string | null;
  milestone_title: string | null;
  topic: string | null;
  estimated_minutes: number | null;
  rationale: string;
}

export interface TopicMasterySummary {
  topic: string;
  correct: number;
  incorrect: number;
  attempts: number;
  accuracy: number;
  accuracy_pct: number;
  mastered: boolean;
  thresholds: { min_correct: number; min_accuracy: number };
}

export interface JourneyMilestone {
  id: string;
  title: string;
  description: string;
  xp: number;
  estimated_days: number;
  skills: string[];
  model_roles: string[];
  resources: RoadmapResource[];
  status: "completed" | "active" | "available" | "locked";
  auto_completed?: boolean;
  trigger_actions: string[];
  phase_title?: string;
}

export interface JourneySnapshot {
  generated_at: string;
  profile: {
    target_path: string;
    goals: string[];
    weekly_hours: number | null;
    experience_level: string;
    diagnostic_completed: boolean;
  };
  plan_summary: {
    plan_id: string;
    title: string;
    summary: string;
    totals: {
      milestones_total: number;
      milestones_completed: number;
      xp_completed: number;
      progress_pct: number;
    };
    is_preview: boolean;
  };
  current_milestone: JourneyMilestone | null;
  next_milestones: JourneyMilestone[];
  completed_milestones: JourneyMilestone[];
  topic_mastery: TopicMasterySummary[];
  gamification: {
    total_xp: number;
    level: { level: number; progress_pct: number } | null;
    streak_current: number;
    streak_max: number;
    event_count: number;
  };
  derived_signals: string[];
  next_action: NextAction | null;
}

const EMPTY_JOURNEY: JourneySnapshot = {
  generated_at: "",
  profile: {
    target_path: "",
    goals: [],
    weekly_hours: null,
    experience_level: "",
    diagnostic_completed: false,
  },
  plan_summary: {
    plan_id: "",
    title: "",
    summary: "",
    totals: {
      milestones_total: 0,
      milestones_completed: 0,
      xp_completed: 0,
      progress_pct: 0,
    },
    is_preview: true,
  },
  current_milestone: null,
  next_milestones: [],
  completed_milestones: [],
  topic_mastery: [],
  gamification: {
    total_xp: 0,
    level: null,
    streak_current: 0,
    streak_max: 0,
    event_count: 0,
  },
  derived_signals: [],
  next_action: null,
};

export function fetchLearnerJourney() {
  return workspaceGetJson<JourneySnapshot>(
    "/api/v1/workflow/journey",
    EMPTY_JOURNEY,
    "GET /api/v1/workflow/journey",
  );
}

export function fetchNextAction() {
  return workspaceGetJson<{ action: NextAction | null }>(
    "/api/v1/workflow/next",
    { action: null },
    "GET /api/v1/workflow/next",
  );
}
