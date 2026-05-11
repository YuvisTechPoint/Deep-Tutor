"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import {
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Clock,
  Plus,
  Trash2,
} from "lucide-react";
import {
  type CalendarTask,
  compareTasks,
  daysInMonth,
  loadCalendarTasks,
  newTaskId,
  parseYmd,
  saveCalendarTasks,
  toYmd,
} from "@/lib/calendar-tasks";

const ACCENT = "#D4734B";

function pad2(n: number): string {
  return String(n).padStart(2, "0");
}

function formatLiveClock(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
}

export default function CalendarPage() {
  const { t, i18n } = useTranslation();
  const [now, setNow] = useState(() => new Date());
  const [view, setView] = useState(() => {
    const d = new Date();
    return new Date(d.getFullYear(), d.getMonth(), 1);
  });
  const [selectedYmd, setSelectedYmd] = useState(() => toYmd(new Date()));
  const [tasks, setTasks] = useState<CalendarTask[]>([]);
  const [title, setTitle] = useState("");
  const [timeStart, setTimeStart] = useState("");
  const [timeEnd, setTimeEnd] = useState("");
  const [notes, setNotes] = useState("");

  useEffect(() => {
    setTasks(loadCalendarTasks());
  }, []);

  useEffect(() => {
    const id = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(id);
  }, []);

  const persist = useCallback((next: CalendarTask[]) => {
    setTasks(next);
    saveCalendarTasks(next);
  }, []);

  const year = view.getFullYear();
  const monthIndex = view.getMonth();
  const firstDow = new Date(year, monthIndex, 1).getDay();
  const dim = daysInMonth(year, monthIndex);

  const cells = useMemo(() => {
    const out: { ymd: string | null; inMonth: boolean }[] = [];
    for (let i = 0; i < firstDow; i++) out.push({ ymd: null, inMonth: false });
    for (let d = 1; d <= dim; d++) {
      const ymd = `${year}-${pad2(monthIndex + 1)}-${pad2(d)}`;
      out.push({ ymd, inMonth: true });
    }
    while (out.length % 7 !== 0) out.push({ ymd: null, inMonth: false });
    return out;
  }, [year, monthIndex, firstDow, dim]);

  const tasksForSelected = useMemo(() => {
    return tasks
      .filter((x) => x.date === selectedYmd)
      .sort(compareTasks);
  }, [tasks, selectedYmd]);

  const addTask = () => {
    const trimmed = title.trim();
    if (!trimmed) return;
    const row: CalendarTask = {
      id: newTaskId(),
      title: trimmed,
      date: selectedYmd,
      timeStart: timeStart.trim(),
      timeEnd: timeEnd.trim(),
      done: false,
      notes: notes.trim(),
    };
    persist([...tasks, row].sort(compareTasks));
    setTitle("");
    setTimeStart("");
    setTimeEnd("");
    setNotes("");
  };

  const toggleDone = (id: string) => {
    persist(
      tasks.map((x) => (x.id === id ? { ...x, done: !x.done } : x)),
    );
  };

  const removeTask = (id: string) => {
    persist(tasks.filter((x) => x.id !== id));
  };

  const shiftMonth = (delta: number) => {
    setView(new Date(year, monthIndex + delta, 1));
  };

  const monthLabel = view.toLocaleString(i18n.language || undefined, {
    month: "long",
    year: "numeric",
  });

  const weekShort = useMemo(() => {
    const base = new Date(2024, 5, 2);
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(base);
      d.setDate(base.getDate() + i);
      return d.toLocaleDateString(i18n.language || undefined, {
        weekday: "short",
      });
    });
  }, [i18n.language]);

  return (
    <div className="flex h-full min-h-0 flex-col overflow-hidden">
      <header className="shrink-0 border-b border-[var(--border)]/60 bg-[var(--card)]/40 px-6 py-4">
        <div className="mx-auto flex max-w-5xl flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="flex items-center gap-3">
            <div
              className="flex h-10 w-10 items-center justify-center rounded-xl border border-[var(--border)]/60 bg-[var(--background)]"
              style={{ color: ACCENT }}
            >
              <CalendarDays className="h-5 w-5" />
            </div>
            <div>
              <h1 className="text-lg font-semibold tracking-tight text-[var(--foreground)]">
                {t("calendar.page_title")}
              </h1>
              <p className="text-xs text-[var(--muted-foreground)]">
                {t("calendar.page_subtitle")}
              </p>
            </div>
          </div>
          <div
            className="flex items-center gap-2 rounded-xl border border-[var(--border)]/60 bg-[var(--background)] px-4 py-2 font-mono text-sm tabular-nums text-[var(--foreground)]"
            style={{ borderColor: `${ACCENT}44` }}
          >
            <Clock className="h-4 w-4 shrink-0" style={{ color: ACCENT }} />
            <span>{formatLiveClock(now)}</span>
          </div>
        </div>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto px-6 py-6">
        <div className="mx-auto grid max-w-5xl gap-6 lg:grid-cols-[minmax(0,1fr)_380px]">
          <section className="rounded-2xl border border-[var(--border)]/60 bg-[var(--card)]/30 p-4">
            <div className="mb-4 flex items-center justify-between gap-2">
              <button
                type="button"
                onClick={() => shiftMonth(-1)}
                className="rounded-lg border border-[var(--border)]/60 p-2 text-[var(--muted-foreground)] hover:bg-[var(--background)] hover:text-[var(--foreground)]"
                aria-label={t("calendar.prev_month")}
              >
                <ChevronLeft className="h-4 w-4" />
              </button>
              <span className="text-sm font-medium text-[var(--foreground)]">
                {monthLabel}
              </span>
              <button
                type="button"
                onClick={() => shiftMonth(1)}
                className="rounded-lg border border-[var(--border)]/60 p-2 text-[var(--muted-foreground)] hover:bg-[var(--background)] hover:text-[var(--foreground)]"
                aria-label={t("calendar.next_month")}
              >
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>
            <div className="grid grid-cols-7 gap-px text-center text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
              {weekShort.map((d) => (
                <div key={d} className="py-2">
                  {d}
                </div>
              ))}
            </div>
            <div className="mt-1 grid grid-cols-7 gap-1">
              {cells.map((cell, idx) => {
                if (!cell.ymd) {
                  return (
                    <div
                      key={`e-${idx}`}
                      className="aspect-square rounded-lg bg-[var(--muted)]/10"
                    />
                  );
                }
                const active = cell.ymd === selectedYmd;
                const today = cell.ymd === toYmd(new Date());
                const count = tasks.filter((x) => x.date === cell.ymd).length;
                return (
                  <button
                    key={cell.ymd}
                    type="button"
                    onClick={() => setSelectedYmd(cell.ymd!)}
                    className={`relative flex aspect-square flex-col items-center justify-center rounded-lg border text-[13px] transition-colors ${
                      active
                        ? "border-transparent text-white shadow-sm"
                        : "border-[var(--border)]/50 bg-[var(--background)]/40 text-[var(--foreground)] hover:border-[var(--border)]"
                    } ${today && !active ? "ring-1 ring-[#D4734B]/50" : ""}`}
                    style={
                      active
                        ? { backgroundColor: ACCENT, borderColor: ACCENT }
                        : undefined
                    }
                  >
                    {parseYmd(cell.ymd!)?.getDate()}
                    {count > 0 && (
                      <span
                        className={`absolute bottom-1 h-1.5 w-1.5 rounded-full ${
                          active ? "bg-white/90" : "bg-[#D4734B]"
                        }`}
                      />
                    )}
                  </button>
                );
              })}
            </div>
          </section>

          <section className="flex min-h-0 flex-col gap-4 rounded-2xl border border-[var(--border)]/60 bg-[var(--card)]/30 p-4">
            <div>
              <h2 className="text-sm font-semibold text-[var(--foreground)]">
                {t("calendar.tasks_for")}{" "}
                <span className="tabular-nums" style={{ color: ACCENT }}>
                  {selectedYmd}
                </span>
              </h2>
              <p className="mt-1 text-[11px] text-[var(--muted-foreground)]">
                {t("calendar.tasks_hint")}
              </p>
            </div>

            <div className="space-y-2 rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/30 p-3">
              <label className="block text-[11px] font-medium text-[var(--muted-foreground)]">
                {t("calendar.task_title")}
              </label>
              <input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full rounded-lg border border-[var(--border)]/60 bg-transparent px-3 py-2 text-sm text-[var(--foreground)] outline-none focus:border-[#D4734B]/60"
                placeholder={t("calendar.task_title_ph")}
              />
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="mb-1 block text-[10px] text-[var(--muted-foreground)]">
                    {t("calendar.time_start")}
                  </label>
                  <input
                    type="time"
                    step={1}
                    value={timeStart}
                    onChange={(e) => setTimeStart(e.target.value)}
                    className="w-full rounded-lg border border-[var(--border)]/60 bg-transparent px-2 py-1.5 text-xs text-[var(--foreground)]"
                  />
                </div>
                <div>
                  <label className="mb-1 block text-[10px] text-[var(--muted-foreground)]">
                    {t("calendar.time_end")}
                  </label>
                  <input
                    type="time"
                    step={1}
                    value={timeEnd}
                    onChange={(e) => setTimeEnd(e.target.value)}
                    className="w-full rounded-lg border border-[var(--border)]/60 bg-transparent px-2 py-1.5 text-xs text-[var(--foreground)]"
                  />
                </div>
              </div>
              <label className="mt-1 block text-[11px] font-medium text-[var(--muted-foreground)]">
                {t("calendar.notes_optional")}
              </label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                rows={2}
                className="w-full resize-none rounded-lg border border-[var(--border)]/60 bg-transparent px-3 py-2 text-xs text-[var(--foreground)] outline-none focus:border-[#D4734B]/60"
                placeholder={t("calendar.notes_ph")}
              />
              <button
                type="button"
                onClick={addTask}
                className="mt-2 flex w-full items-center justify-center gap-2 rounded-lg px-3 py-2 text-sm font-medium text-white transition-opacity hover:opacity-90"
                style={{ backgroundColor: ACCENT }}
              >
                <Plus className="h-4 w-4" />
                {t("calendar.add_task")}
              </button>
            </div>

            <div className="min-h-0 flex-1 space-y-2 overflow-y-auto pr-1">
              {tasksForSelected.length === 0 ? (
                <p className="py-6 text-center text-xs text-[var(--muted-foreground)]">
                  {t("calendar.no_tasks_day")}
                </p>
              ) : (
                tasksForSelected.map((task) => (
                  <div
                    key={task.id}
                    className="flex items-start gap-2 rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/40 p-3"
                  >
                    <input
                      type="checkbox"
                      checked={task.done}
                      onChange={() => toggleDone(task.id)}
                      className="mt-1 h-4 w-4 accent-[#D4734B]"
                    />
                    <div className="min-w-0 flex-1">
                      <div
                        className={`text-sm font-medium ${
                          task.done
                            ? "text-[var(--muted-foreground)] line-through"
                            : "text-[var(--foreground)]"
                        }`}
                      >
                        {task.title}
                      </div>
                      <div className="mt-0.5 font-mono text-[11px] text-[var(--muted-foreground)]">
                        {task.timeStart || t("calendar.all_day")}
                        {task.timeEnd
                          ? ` → ${task.timeEnd}`
                          : ""}
                      </div>
                      {task.notes ? (
                        <p className="mt-1 text-[11px] text-[var(--muted-foreground)]">
                          {task.notes}
                        </p>
                      ) : null}
                    </div>
                    <button
                      type="button"
                      onClick={() => removeTask(task.id)}
                      className="rounded-md p-1.5 text-[var(--muted-foreground)] hover:bg-rose-500/15 hover:text-rose-400"
                      aria-label={t("calendar.delete_task")}
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                ))
              )}
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
