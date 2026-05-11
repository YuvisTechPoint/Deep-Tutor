import { apiFetch, apiUrl } from "@/lib/api";

export interface LearningProfile {
  goals: string[];
  target_path: string;
  weekly_hours: number | null;
  learning_styles: string[];
  experience_level: string;
  prior_summary: string;
  diagnostic_completed: boolean;
  updated_at?: string | null;
}

export async function getLearningProfile(): Promise<LearningProfile> {
  const res = await apiFetch(apiUrl("/api/v1/learning-profile"), {
    cache: "no-store",
  });
  // 404 means no profile saved yet — return empty defaults instead of throwing
  if (res.status === 404) {
    return {
      goals: [],
      target_path: "",
      weekly_hours: null,
      learning_styles: [],
      experience_level: "",
      prior_summary: "",
      diagnostic_completed: false,
    };
  }
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    // Surface a human-readable message, not a raw JSON blob
    let detail = text;
    try {
      const parsed = JSON.parse(text);
      detail = parsed.detail ?? parsed.message ?? text;
    } catch {
      // keep raw text
    }
    throw new Error(detail || `Failed to load profile (${res.status})`);
  }
  return res.json() as Promise<LearningProfile>;
}

export async function saveLearningProfile(
  body: LearningProfile,
): Promise<LearningProfile> {
  const { updated_at: _ignored, ...payload } = body;
  const res = await apiFetch(apiUrl("/api/v1/learning-profile"), {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    let detail = text;
    try {
      const parsed = JSON.parse(text);
      detail = parsed.detail ?? parsed.message ?? text;
    } catch {
      // keep raw text
    }
    throw new Error(detail || `Failed to save profile (${res.status})`);
  }
  return res.json() as Promise<LearningProfile>;
}
