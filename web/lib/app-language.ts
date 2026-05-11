/**
 * Canonical UI language codes for the web app (i18n + persisted preferences).
 * Legacy ``zh`` is normalized away at read boundaries — Chinese is no longer
 * offered as a UI option; Hindi and Bengali are added (Bengali uses partial
 * translation overlays merged with English in i18n).
 */
export type AppLanguage = "en" | "hi" | "bn";

export function normalizeLanguage(lang: unknown): AppLanguage {
  if (!lang) return "en";
  const s = String(lang).toLowerCase().trim();
  if (s === "hi" || s === "hindi") return "hi";
  if (s === "bn" || s === "bengali" || s === "bangla") return "bn";
  if (
    s === "zh" ||
    s === "cn" ||
    s === "chinese" ||
    s.startsWith("zh-") ||
    s.startsWith("zh_")
  ) {
    return "en";
  }
  if (s === "en" || s === "english" || s.startsWith("en-")) return "en";
  return "en";
}

/** BCP 47 locale for ``Intl`` formatting from UI language. */
export function appLanguageToBcp47Locale(lang: AppLanguage): string {
  if (lang === "hi") return "hi-IN";
  if (lang === "bn") return "bn-BD";
  return "en-US";
}

/** Category labels: avoid tight uppercase tracking on dense scripts. */
export function usesDenseScriptCategoryLabels(lang: AppLanguage): boolean {
  return lang === "hi" || lang === "bn";
}
