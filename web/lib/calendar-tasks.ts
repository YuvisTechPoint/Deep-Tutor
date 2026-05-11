/**
 * Client-side calendar tasks (workspace). Persisted in localStorage until
 * a server model exists.
 */

export const CALENDAR_TASKS_STORAGE_KEY = "deeptutor.calendar.tasks.v1";

export interface CalendarTask {
  id: string;
  title: string;
  /** ISO date ``YYYY-MM-DD`` (local calendar day). */
  date: string;
  /** ``HH:mm`` or ``HH:mm:ss`` — empty means all-day. */
  timeStart: string;
  timeEnd: string;
  done: boolean;
  notes: string;
}

export function newTaskId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `t_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

export function loadCalendarTasks(): CalendarTask[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(CALENDAR_TASKS_STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter(
        (row): row is CalendarTask =>
          typeof row === "object" &&
          row !== null &&
          typeof (row as CalendarTask).id === "string" &&
          typeof (row as CalendarTask).title === "string" &&
          typeof (row as CalendarTask).date === "string",
      )
      .map((row) => ({
        id: row.id,
        title: row.title,
        date: row.date,
        timeStart: typeof row.timeStart === "string" ? row.timeStart : "",
        timeEnd: typeof row.timeEnd === "string" ? row.timeEnd : "",
        done: Boolean(row.done),
        notes: typeof row.notes === "string" ? row.notes : "",
      }));
  } catch {
    return [];
  }
}

export function saveCalendarTasks(tasks: CalendarTask[]): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(
      CALENDAR_TASKS_STORAGE_KEY,
      JSON.stringify(tasks),
    );
  } catch {
    /* quota */
  }
}

/** Pad local ``Date`` to ``YYYY-MM-DD``. */
export function toYmd(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

export function parseYmd(ymd: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(ymd);
  if (!m) return null;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return Number.isNaN(d.getTime()) ? null : d;
}

/** Days in month (1-indexed month). */
export function daysInMonth(year: number, monthIndex: number): number {
  return new Date(year, monthIndex + 1, 0).getDate();
}

/** Compare tasks by date then start time for stable ordering. */
export function compareTasks(a: CalendarTask, b: CalendarTask): number {
  if (a.date !== b.date) return a.date.localeCompare(b.date);
  return (a.timeStart || "99:99:99").localeCompare(b.timeStart || "99:99:99");
}
