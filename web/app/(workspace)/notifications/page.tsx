"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import {
  Bell,
  Check,
  CheckCheck,
  ExternalLink,
  Flame,
  HelpCircle,
  Loader2,
  Map,
  MessageSquare,
  Settings,
  Trophy,
  X,
} from "lucide-react";

import {
  dismissNotification,
  fetchNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  type NotificationItem,
} from "@/lib/workspace-api";

type FilterTab = "all" | "unread" | "mentions" | "system";

const TYPE_CONFIG: Record<
  string,
  { icon: React.ComponentType<{ size?: number; className?: string }>; iconColor: string; iconBg: string }
> = {
  streak_reminder: {
    icon: Flame,
    iconColor: "text-amber-400",
    iconBg: "bg-amber-500/15",
  },
  achievement_unlocked: {
    icon: Trophy,
    iconColor: "text-violet-400",
    iconBg: "bg-violet-500/15",
  },
  mentor_message: {
    icon: MessageSquare,
    iconColor: "text-teal-400",
    iconBg: "bg-teal-500/15",
  },
  system_update: {
    icon: Settings,
    iconColor: "text-slate-400",
    iconBg: "bg-slate-500/15",
  },
  quiz_available: {
    icon: HelpCircle,
    iconColor: "text-indigo-400",
    iconBg: "bg-indigo-500/15",
  },
  new_roadmap_item: {
    icon: Map,
    iconColor: "text-emerald-400",
    iconBg: "bg-emerald-500/15",
  },
};

function timeAgo(iso: string): string {
  const then = new Date(iso).getTime();
  if (!then) return iso;
  const diff = Date.now() - then;
  const minutes = Math.floor(diff / 60_000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} hr ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return "yesterday";
  if (days < 7) return `${days} days ago`;
  return new Date(then).toLocaleDateString();
}

export default function NotificationsPage() {
  const [notifs, setNotifs] = useState<NotificationItem[]>([]);
  const [filter, setFilter] = useState<FilterTab>("all");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reload = async () => {
    const data = await fetchNotifications();
    setNotifs(data.items);
  };

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        await reload();
      } catch (e) {
        if (!cancelled) {
          setError(
            e instanceof Error ? e.message : "Failed to load notifications",
          );
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  async function markAllRead() {
    try {
      await markAllNotificationsRead();
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to mark notifications");
    }
  }

  async function markRead(id: string) {
    try {
      const target = notifs.find((n) => n.id === id);
      if (!target || target.read) return;
      await markNotificationRead(id);
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to mark read");
    }
  }

  async function dismiss(id: string) {
    try {
      await dismissNotification(id);
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to dismiss notification");
    }
  }

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center gap-2 text-[var(--muted-foreground)]">
        <Loader2 className="h-5 w-5 animate-spin" />
        <span>Loading notifications…</span>
      </div>
    );
  }

  const filtered = notifs.filter((n) => {
    if (filter === "unread") return !n.read;
    if (filter === "mentions") return n.is_mention;
    if (filter === "system") return n.is_system;
    return true;
  });

  const unreadCount = notifs.filter((n) => !n.read).length;

  return (
    <div className="flex h-screen flex-col overflow-hidden bg-[var(--background)]">
      <header className="shrink-0 border-b border-white/5 bg-[var(--secondary)] px-6 py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="relative">
              <Bell size={20} className="text-[var(--foreground)]" />
              {unreadCount > 0 && (
                <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-violet-500 text-white text-[10px] font-bold flex items-center justify-center">
                  {unreadCount}
                </span>
              )}
            </div>
            <div>
              <h1 className="text-lg font-semibold text-[var(--foreground)]">
                Notifications
              </h1>
              <p className="text-sm text-[var(--muted-foreground)]">
                {unreadCount} unread
              </p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={markAllRead}
              className="flex items-center gap-2 rounded-xl border border-white/5 px-3 py-1.5 text-xs font-medium text-[var(--muted-foreground)] hover:text-[var(--foreground)] hover:bg-white/5 transition-colors"
            >
              <CheckCheck size={13} />
              Mark all read
            </button>
            <Link
              href="/settings"
              className="flex items-center gap-2 rounded-xl border border-white/5 px-3 py-1.5 text-xs font-medium text-[var(--muted-foreground)] hover:text-[var(--foreground)] hover:bg-white/5 transition-colors"
            >
              <Settings size={13} />
              Settings
            </Link>
          </div>
        </div>

        <div className="flex gap-1 mt-3">
          {(
            [
              { key: "all", label: `All (${notifs.length})` },
              { key: "unread", label: `Unread (${unreadCount})` },
              {
                key: "mentions",
                label: `Mentions (${notifs.filter((n) => n.is_mention).length})`,
              },
              {
                key: "system",
                label: `System (${notifs.filter((n) => n.is_system).length})`,
              },
            ] as { key: FilterTab; label: string }[]
          ).map(({ key, label }) => (
            <button
              key={key}
              type="button"
              onClick={() => setFilter(key)}
              className={`px-4 py-1.5 rounded-xl text-xs font-medium transition-colors ${
                filter === key
                  ? "bg-violet-500/20 text-violet-400 border border-violet-500/30"
                  : "text-[var(--muted-foreground)] hover:text-[var(--foreground)]"
              }`}
            >
              {label}
            </button>
          ))}
        </div>
      </header>

      {error && (
        <div className="mx-6 mt-3 rounded-xl border border-red-500/30 bg-red-500/10 px-4 py-2 text-sm text-red-200">
          {error}
        </div>
      )}

      <div className="flex-1 overflow-y-auto">
        {filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center h-64 gap-3">
            <div className="w-14 h-14 rounded-2xl bg-white/5 flex items-center justify-center">
              <Bell size={24} className="text-[var(--muted-foreground)]" />
            </div>
            <p className="text-sm font-medium text-[var(--foreground)]">
              All caught up!
            </p>
            <p className="text-xs text-[var(--muted-foreground)]">
              No notifications in this category.
            </p>
          </div>
        ) : (
          <div className="divide-y divide-white/5">
            {filtered.map((notif) => {
              const cfg = TYPE_CONFIG[notif.type] ?? TYPE_CONFIG.system_update;
              const Icon = cfg.icon;
              return (
                <div
                  key={notif.id}
                  className={`group relative flex items-start gap-4 px-6 py-4 transition-colors hover:bg-white/2 cursor-pointer ${
                    !notif.read ? "bg-violet-500/3" : ""
                  }`}
                  onClick={() => markRead(notif.id)}
                >
                  {!notif.read && (
                    <div className="absolute left-2 top-1/2 -translate-y-1/2 w-1.5 h-1.5 rounded-full bg-violet-500" />
                  )}

                  <div
                    className={`shrink-0 w-10 h-10 rounded-xl ${cfg.iconBg} flex items-center justify-center mt-0.5`}
                  >
                    <Icon size={18} className={cfg.iconColor} />
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-start justify-between gap-2">
                      <p className="text-sm font-semibold leading-snug text-[var(--foreground)]">
                        {notif.title}
                      </p>
                      <div className="flex items-center gap-2 shrink-0">
                        <span className="text-xs text-[var(--muted-foreground)] whitespace-nowrap">
                          {timeAgo(notif.created_at)}
                        </span>
                        <button
                          type="button"
                          onClick={(e) => {
                            e.stopPropagation();
                            void dismiss(notif.id);
                          }}
                          className="opacity-0 group-hover:opacity-100 p-1 rounded-lg text-[var(--muted-foreground)] hover:text-[var(--foreground)] hover:bg-white/5 transition-all"
                        >
                          <X size={12} />
                        </button>
                      </div>
                    </div>
                    <p className="text-xs text-[var(--muted-foreground)] mt-1 leading-relaxed line-clamp-2">
                      {notif.message}
                    </p>
                    {notif.action_label && notif.action_href && (
                      <Link
                        href={notif.action_href}
                        onClick={(e) => e.stopPropagation()}
                        className={`mt-2 inline-flex items-center gap-1.5 text-xs font-medium transition-colors ${cfg.iconColor} hover:opacity-80`}
                      >
                        {notif.action_label}
                        <ExternalLink size={11} />
                      </Link>
                    )}
                    {notif.is_system && (
                      <span className="inline-block ml-1 mt-2 rounded-md bg-slate-500/10 border border-slate-500/20 px-2 py-0.5 text-[10px] text-slate-400 font-medium">
                        System
                      </span>
                    )}
                    {notif.is_mention && (
                      <span className="inline-block ml-1 mt-2 rounded-md bg-teal-500/10 border border-teal-500/20 px-2 py-0.5 text-[10px] text-teal-400 font-medium">
                        Mention
                      </span>
                    )}
                  </div>

                  {!notif.read && (
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        void markRead(notif.id);
                      }}
                      className="shrink-0 p-1.5 rounded-lg text-[var(--muted-foreground)] hover:text-emerald-400 hover:bg-emerald-500/10 transition-colors mt-0.5"
                      title="Mark as read"
                    >
                      <Check size={13} />
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        )}

        {filtered.length > 0 && (
          <div className="px-6 py-4 border-t border-white/5 flex items-center justify-between">
            <p className="text-xs text-[var(--muted-foreground)]">
              Showing {filtered.length} of {notifs.length} notifications
            </p>
            <Link
              href="/settings"
              className="text-xs text-violet-400 hover:text-violet-300 transition-colors flex items-center gap-1.5"
            >
              <Settings size={12} />
              Notification Settings
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
