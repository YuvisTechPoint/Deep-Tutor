/**
 * Extract tutor self-check metadata from a deep_solve `result` stream event.
 */

export interface DeepSolveVerification {
  verified: boolean;
  confidence: number;
  note: string;
}

export function extractDeepSolveVerification(
  resultMetadata: Record<string, unknown> | undefined,
): DeepSolveVerification | null {
  if (!resultMetadata) return null;
  const inner = resultMetadata.metadata as Record<string, unknown> | undefined;
  const v = inner?.verification as Record<string, unknown> | undefined;
  if (!v || typeof v !== "object") return null;
  return {
    verified: Boolean(v.verified),
    confidence:
      typeof v.confidence === "number"
        ? v.confidence
        : Number.parseFloat(String(v.confidence ?? 0)) || 0,
    note: String(v.note ?? "").trim(),
  };
}
