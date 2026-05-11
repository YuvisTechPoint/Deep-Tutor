import i18n, { type Resource } from "i18next";
import { initReactI18next } from "react-i18next";

import enApp from "@/locales/en/app.json";
import bnOverrides from "@/locales/bn/overrides.json";
import hiOverrides from "@/locales/hi/overrides.json";
import hiPracticeQ from "@/locales/hi/practice-q.json";
import { normalizeLanguage } from "@/lib/app-language";

export { normalizeLanguage } from "@/lib/app-language";
export type { AppLanguage } from "@/lib/app-language";

function mergeAppStrings(
  base: Record<string, string>,
  overrides: Record<string, string>,
): Record<string, string> {
  return { ...base, ...overrides };
}

const hiApp = mergeAppStrings(
  mergeAppStrings(
    enApp as Record<string, string>,
    hiOverrides as Record<string, string>,
  ),
  hiPracticeQ as Record<string, string>,
);
const bnApp = mergeAppStrings(
  enApp as Record<string, string>,
  bnOverrides as Record<string, string>,
);

let _initialized = false;

export function initI18n(language?: unknown) {
  if (_initialized) return i18n;

  const resources: Resource = {
    en: { app: enApp },
    hi: { app: hiApp as typeof enApp },
    bn: { app: bnApp as typeof enApp },
  };

  i18n.use(initReactI18next).init({
    resources,
    lng: normalizeLanguage(language),
    fallbackLng: "en",
    // Use a single default namespace to keep lookups simple.
    // We intentionally keep keySeparator disabled so keys like "Generating..." remain valid.
    defaultNS: "app",
    ns: ["app"],
    keySeparator: false,
    interpolation: {
      escapeValue: false,
    },
    returnEmptyString: false,
    returnNull: false,
  });

  _initialized = true;
  return i18n;
}
