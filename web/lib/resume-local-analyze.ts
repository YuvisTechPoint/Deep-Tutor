/**
 * Client-only résumé text extraction and lightweight heuristics.
 * No uploads — runs on Data URLs already stored in localStorage.
 */

export type ResumeExtractionKind = "txt" | "pdf-heuristic" | "unsupported";

export interface ResumeAnalysisSnapshot {
  generatedAt: string;
  extraction: ResumeExtractionKind;
  wordCount: number;
  estimatedReadMinutes: number;
  bulletLikeLines: number;
  dateHints: number;
  emails: string[];
  phones: string[];
  urls: string[];
  sections: {
    experience: boolean;
    education: boolean;
    skills: boolean;
    summary: boolean;
    projects: boolean;
  };
  matchedSkills: string[];
  topKeywords: string[];
  previewSnippet: string;
  note?: string;
}

const SKILL_LEXICON = [
  "python",
  "javascript",
  "typescript",
  "react",
  "next.js",
  "node",
  "java",
  "go",
  "rust",
  "c++",
  "sql",
  "aws",
  "azure",
  "gcp",
  "kubernetes",
  "docker",
  "tensorflow",
  "pytorch",
  "nlp",
  "llm",
  "rag",
  "fastapi",
  "django",
  "flask",
  "graphql",
  "rest",
  "redis",
  "kafka",
  "postgresql",
  "mongodb",
  "git",
  "ci/cd",
  "agile",
  "scrum",
  "leadership",
  "communication",
  "stakeholder",
  "product",
  "analytics",
  "machine learning",
  "deep learning",
  "data science",
  "excel",
  "tableau",
  "power bi",
];

const STOPWORDS = new Set([
  "the",
  "and",
  "for",
  "with",
  "from",
  "your",
  "this",
  "that",
  "have",
  "has",
  "was",
  "were",
  "are",
  "our",
  "all",
  "any",
  "not",
  "but",
  "can",
  "will",
  "into",
  "about",
  "over",
  "such",
  "also",
  "using",
  "used",
  "work",
  "team",
  "years",
  "year",
  "month",
  "months",
  "jan",
  "feb",
  "mar",
  "apr",
  "may",
  "jun",
  "jul",
  "aug",
  "sep",
  "oct",
  "nov",
  "dec",
]);

function dataUrlToBytes(dataUrl: string): Uint8Array | null {
  const idx = dataUrl.indexOf("base64,");
  if (idx === -1) return null;
  const b64 = dataUrl.slice(idx + 7);
  try {
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i) & 0xff;
    return out;
  } catch {
    return null;
  }
}

function bytesToUtf8(bytes: Uint8Array): string {
  try {
    return new TextDecoder("utf-8", { fatal: false }).decode(bytes);
  } catch {
    let s = "";
    for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return s;
  }
}

function unescapePdfStringOperand(inner: string): string {
  let out = "";
  for (let i = 0; i < inner.length; i++) {
    const c = inner[i];
    if (c !== "\\") {
      out += c;
      continue;
    }
    i++;
    const e = inner[i];
    if (!e) break;
    if (e === "n") out += "\n";
    else if (e === "r") out += "\r";
    else if (e === "t") out += "\t";
    else if (e === "b") out += "\b";
    else if (e === "f") out += "\f";
    else if (e === "(") out += "(";
    else if (e === ")") out += ")";
    else if (e === "\\") out += "\\";
    else if (/[0-7]/.test(e)) {
      let oct = e;
      while (oct.length < 3 && i + 1 < inner.length && /[0-7]/.test(inner[i + 1])) {
        i++;
        oct += inner[i];
      }
      out += String.fromCharCode(parseInt(oct, 8) % 256);
    } else {
      out += e;
    }
  }
  return out;
}

/** Best-effort: pulls literal strings before `Tj` (common in many PDF generators). */
export function extractTextFromPdfDataUrl(dataUrl: string): string | null {
  const bytes = dataUrlToBytes(dataUrl);
  if (!bytes) return null;
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  const parts: string[] = [];
  // Use RegExp constructor to avoid bundler regex serialization issues
  const re = new RegExp(String.raw`\(((?:\\.|[^\\)]))*\)\s*Tj`, "g");
  let m: RegExpExecArray | null;
  while ((m = re.exec(bin)) !== null) {
    try {
      const chunk = unescapePdfStringOperand(m[1]);
      if (chunk.trim()) parts.push(chunk);
    } catch {
      /* skip */
    }
  }
  if (parts.length === 0) return null;
  return parts.join(" ");
}

export function extractTextFromDataUrl(
  dataUrl: string | undefined,
  mime: string,
  fileName: string,
): { text: string | null; kind: ResumeExtractionKind; note?: string } {
  if (!dataUrl) {
    return {
      text: null,
      kind: "unsupported",
      note: "no_inline_payload",
    };
  }
  const lower = fileName.toLowerCase();
  const isTxt =
    mime.includes("text/plain") || lower.endsWith(".txt") || lower.endsWith(".md");
  if (isTxt) {
    const bytes = dataUrlToBytes(dataUrl);
    if (!bytes) return { text: null, kind: "unsupported", note: "decode_failed" };
    const text = bytesToUtf8(bytes).replace(/\u0000/g, "");
    return { text: text.trim() || null, kind: "txt" };
  }
  const isPdf = mime.includes("pdf") || lower.endsWith(".pdf");
  if (isPdf) {
    const rough = extractTextFromPdfDataUrl(dataUrl);
    if (rough && rough.replace(/\s+/g, " ").trim().length > 40) {
      return { text: rough, kind: "pdf-heuristic" };
    }
    return {
      text: null,
      kind: "unsupported",
      note: "pdf_text_not_found",
    };
  }
  return {
    text: null,
    kind: "unsupported",
    note: "format_local_scan_limited",
  };
}

function normalizeText(raw: string): string {
  return raw.replace(/\r\n/g, "\n").replace(/[ \t]+/g, " ").trim();
}

function detectSections(text: string): ResumeAnalysisSnapshot["sections"] {
  const u = text.toUpperCase();
  return {
    experience:
      /\b(EXPERIENCE|WORK HISTORY|EMPLOYMENT|PROFESSIONAL EXPERIENCE|CAREER)\b/.test(u),
    education: /\b(EDUCATION|ACADEMIC|UNIVERSITY|DEGREE|QUALIFICATIONS)\b/.test(u),
    skills: /\b(SKILLS|TECHNICAL SKILLS|CORE COMPETENCIES|STACK)\b/.test(u),
    summary: /\b(SUMMARY|PROFILE|OBJECTIVE|ABOUT ME|OVERVIEW)\b/.test(u),
    projects: /\b(PROJECTS|PORTFOLIO|SELECTED WORK)\b/.test(u),
  };
}

function extractContacts(text: string): Pick<
  ResumeAnalysisSnapshot,
  "emails" | "phones" | "urls"
> {
  const emails = [
    ...new Set(
      (text.match(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Za-z]{2,}/g) ?? []).map((e) =>
        e.toLowerCase(),
      ),
    ),
  ];
  const urls = [...new Set(text.match(/https?:\/\/[^\s)\]>]+/g) ?? [])].slice(0, 12);
  const phoneLike =
    text.match(/\b\+?\d[\d\s().-]{7,14}\d\b|\b\(\d{3}\)\s*\d{3}[-.]?\d{4}\b/g) ?? [];
  const phones = [...new Set(phoneLike.map((p) => p.replace(/\s+/g, " ").trim()))].slice(
    0,
    5,
  );
  return { emails, phones, urls };
}

function countBulletLikeLines(text: string): number {
  const lines = text.split("\n");
  let n = 0;
  for (const line of lines) {
    const t = line.trim();
    if (/^[-•●◦▪▸►]\s+\S/.test(t) || /^\*\s+\S/.test(t)) n++;
  }
  return n;
}

function countDateHints(text: string): number {
  const m =
    text.match(
      /\b(19|20)\d{2}\b|\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+(19|20)\d{2}\b|\b\d{1,2}\/\d{4}\b/gi,
    ) ?? [];
  return m.length;
}

function matchSkills(text: string): string[] {
  const lower = text.toLowerCase();
  const found: string[] = [];
  for (const s of SKILL_LEXICON) {
    const needle = s.toLowerCase();
    if (lower.includes(needle)) found.push(s);
  }
  return [...new Set(found)].slice(0, 24);
}

function computeTopKeywords(text: string, limit: number): string[] {
  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9+#./\s-]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 2 && !STOPWORDS.has(w));
  const freq = new Map<string, number>();
  for (const w of words) freq.set(w, (freq.get(w) ?? 0) + 1);
  return [...freq.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([w]) => w);
}

export function analyzeResumePlainText(
  text: string,
  extraction: ResumeExtractionKind,
  note?: string,
): ResumeAnalysisSnapshot {
  const clean = normalizeText(text).slice(0, 200_000);
  const words = clean.length ? clean.split(/\s+/) : [];
  const wordCount = words.filter(Boolean).length;
  const estimatedReadMinutes = Math.max(1, Math.round(wordCount / 200));
  const contacts = extractContacts(clean);
  const sections = detectSections(clean);
  const bulletLikeLines = countBulletLikeLines(clean);
  const dateHints = countDateHints(clean);
  const matchedSkills = matchSkills(clean);
  const topKeywords = computeTopKeywords(clean, 8);
  const previewSnippet = clean.slice(0, 320) + (clean.length > 320 ? "…" : "");

  return {
    generatedAt: new Date().toISOString(),
    extraction,
    wordCount,
    estimatedReadMinutes,
    bulletLikeLines,
    dateHints,
    ...contacts,
    sections,
    matchedSkills,
    topKeywords,
    previewSnippet,
    note,
  };
}

export function runLocalResumeAnalysis(
  dataUrl: string | undefined,
  mime: string,
  fileName: string,
): ResumeAnalysisSnapshot | null {
  const { text, kind, note } = extractTextFromDataUrl(dataUrl, mime, fileName);
  if (!text) {
    return {
      generatedAt: new Date().toISOString(),
      extraction: kind,
      wordCount: 0,
      estimatedReadMinutes: 0,
      bulletLikeLines: 0,
      dateHints: 0,
      emails: [],
      phones: [],
      urls: [],
      sections: {
        experience: false,
        education: false,
        skills: false,
        summary: false,
        projects: false,
      },
      matchedSkills: [],
      topKeywords: [],
      previewSnippet: "",
      note: note ?? "no_text_extracted",
    };
  }
  return analyzeResumePlainText(text, kind, note);
}
