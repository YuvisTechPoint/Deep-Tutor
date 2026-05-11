import type { AppLanguage } from "@/lib/app-language";
import { appLanguageToBcp47Locale } from "@/lib/app-language";

export type Language = AppLanguage;

export function getLocale(lang: Language): string {
  return appLanguageToBcp47Locale(lang);
}

export function formatDate(
  date: Date,
  lang: Language,
  options: Intl.DateTimeFormatOptions = {
    year: "numeric",
    month: "short",
    day: "numeric",
  },
): string {
  return new Intl.DateTimeFormat(getLocale(lang), options).format(date);
}

export function formatTime(
  date: Date,
  lang: Language,
  options: Intl.DateTimeFormatOptions = { hour: "2-digit", minute: "2-digit" },
): string {
  return new Intl.DateTimeFormat(getLocale(lang), options).format(date);
}
