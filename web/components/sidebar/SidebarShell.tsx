"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { type ReactNode, useCallback, useEffect, useState } from "react";
import { useAppShell } from "@/context/AppShellContext";
import { fetchAuthStatus } from "@/lib/auth";
import {
  BadgeCheck,
  BarChart2,
  Bell,
  BookMarked,
  BookOpen,
  Bot,
  Briefcase,
  Calendar,
  CalendarDays,
  ChevronDown,
  ChevronRight,
  ClipboardCheck,
  ClipboardList,
  CreditCard,
  GitCompare,
  LayoutGrid,
  Library,
  LineChart,
  MapPin,
  MessageSquare,
  PanelLeftClose,
  PanelLeftOpen,
  PenLine,
  Plug,
  Plus,
  Search,
  Settings,
  Sparkles,
  Target,
  TrendingUp,
  Trophy,
  Upload,
  UserRound,
  Users,
  Zap,
  type LucideIcon,
} from "lucide-react";
import { useTranslation } from "react-i18next";
import SessionList from "@/components/SessionList";
import { TutorBotRecent } from "@/components/sidebar/TutorBotRecent";
import { SidebarFooterStatus } from "@/components/sidebar/SidebarFooterStatus";
import type { SessionSummary } from "@/lib/session-api";
import { Tooltip } from "@/components/ui/Tooltip";

interface NavEntry {
  href: string;
  label: string;
  icon: LucideIcon;
  tooltipKey?: string;
}

const PRIMARY_NAV: NavEntry[] = [
  {
    href: "/chat",
    label: "Chat",
    icon: MessageSquare,
    tooltipKey: "Chat tooltip",
  },
  {
    href: "/roadmap",
    label: "Roadmap",
    icon: MapPin,
    tooltipKey: "Learning roadmap",
  },
  {
    href: "/onboarding",
    label: "Onboarding",
    icon: ClipboardList,
    tooltipKey: "Onboarding tooltip",
  },
  {
    href: "/eip",
    label: "Learning ID",
    icon: BadgeCheck,
    tooltipKey: "Learning ID tooltip",
  },
  {
    href: "/assessments",
    label: "Assessments",
    icon: ClipboardCheck,
    tooltipKey: "Assessment center",
  },
  {
    href: "/practice",
    label: "Practice",
    icon: Target,
    tooltipKey: "Practice & assessment",
  },
  {
    href: "/career",
    label: "Career",
    icon: Briefcase,
    tooltipKey: "Career intelligence",
  },
  {
    href: "/calendar",
    label: "Calendar",
    icon: CalendarDays,
    tooltipKey: "calendar.tooltip",
  },
  {
    href: "/skill-boost",
    label: "Skill Boost",
    icon: Sparkles,
    tooltipKey: "skillBoost.tooltip",
  },
  {
    href: "/resume",
    label: "Resume upload",
    icon: Upload,
    tooltipKey: "resume.tooltip",
  },
  {
    href: "/profile-cv",
    label: "Profile & CV",
    icon: UserRound,
    tooltipKey: "profileCv.tooltip",
  },
  {
    href: "/dashboard",
    label: "Dashboard",
    icon: TrendingUp,
    tooltipKey: "Learning analytics",
  },
  {
    href: "/agents",
    label: "TutorBot",
    icon: Bot,
    tooltipKey: "TutorBot tooltip",
  },
  {
    href: "/co-writer",
    label: "Co-Writer",
    icon: PenLine,
    tooltipKey: "Co-Writer tooltip",
  },
  { href: "/book", label: "Book", icon: Library, tooltipKey: "Book tooltip" },
  {
    href: "/knowledge",
    label: "Knowledge",
    icon: BookOpen,
    tooltipKey: "Knowledge tooltip",
  },
  {
    href: "/space",
    label: "Space",
    icon: LayoutGrid,
    tooltipKey: "Space tooltip",
  },
  {
    href: "/missions",
    label: "Missions",
    icon: Calendar,
    tooltipKey: "Daily missions",
  },
  {
    href: "/analytics",
    label: "Analytics",
    icon: BarChart2,
    tooltipKey: "Learning analytics",
  },
  {
    href: "/achievements",
    label: "Achievements",
    icon: Trophy,
    tooltipKey: "Badges & achievements",
  },
  {
    href: "/notifications",
    label: "Notifications",
    icon: Bell,
    tooltipKey: "Notifications",
  },
  {
    href: "/billing",
    label: "Billing",
    icon: CreditCard,
    tooltipKey: "Billing tooltip",
  },
];

const MENTOR_NAV: NavEntry[] = [
  { href: "/mentor", label: "Cohort", icon: Users, tooltipKey: "Mentor cohort" },
  {
    href: "/mentor/progress",
    label: "Progress",
    icon: LineChart,
    tooltipKey: "Learner progress",
  },
  {
    href: "/mentor/intervention",
    label: "Intervention",
    icon: Zap,
    tooltipKey: "Intervention alerts",
  },
  {
    href: "/mentor/content",
    label: "Content",
    icon: BookMarked,
    tooltipKey: "Course content",
  },
];

const RECRUITER_NAV: NavEntry[] = [
  {
    href: "/recruiter",
    label: "Talent Search",
    icon: Search,
    tooltipKey: "Talent search",
  },
  {
    href: "/recruiter/compare",
    label: "Compare",
    icon: GitCompare,
    tooltipKey: "Compare candidates",
  },
];

const SECONDARY_NAV: NavEntry[] = [
  { href: "/integrations", label: "Integrations", icon: Plug },
  { href: "/settings", label: "Settings", icon: Settings },
];
const DEFAULT_SESSION_VIEWPORT_CLASS_NAME = "max-h-[112px]";
const SESSIONS_EXPANDED_STORAGE_KEY = "dt:sidebar:sessions-expanded";

function readStoredSessionsExpanded(): boolean {
  if (typeof window === "undefined") return true;
  try {
    const raw = window.localStorage.getItem(SESSIONS_EXPANDED_STORAGE_KEY);
    if (raw === null) return true;
    return raw !== "0";
  } catch {
    return true;
  }
}

function writeStoredSessionsExpanded(expanded: boolean): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(
      SESSIONS_EXPANDED_STORAGE_KEY,
      expanded ? "1" : "0",
    );
  } catch {
    /* ignore quota / private-mode errors */
  }
}

interface SidebarShellProps {
  sessions?: SessionSummary[];
  activeSessionId?: string | null;
  loadingSessions?: boolean;
  showSessions?: boolean;
  sessionViewportClassName?: string;
  onNewChat?: () => void;
  onSelectSession?: (sessionId: string) => void | Promise<void>;
  onRenameSession?: (sessionId: string, title: string) => void | Promise<void>;
  onDeleteSession?: (sessionId: string) => void | Promise<void>;
  footerSlot?: ReactNode;
}

export function SidebarShell({
  sessions = [],
  activeSessionId = null,
  loadingSessions = false,
  showSessions = false,
  sessionViewportClassName = DEFAULT_SESSION_VIEWPORT_CLASS_NAME,
  onNewChat,
  onSelectSession,
  onRenameSession,
  onDeleteSession,
  footerSlot,
}: SidebarShellProps) {
  const pathname = usePathname();
  const router = useRouter();
  const { t } = useTranslation();
  const { sidebarCollapsed: collapsed, setSidebarCollapsed: setCollapsed } =
    useAppShell();

  const [userRole, setUserRole] = useState<string | undefined>(undefined);
  useEffect(() => {
    fetchAuthStatus().then((s) => setUserRole(s?.role)).catch(() => {});
  }, []);

  // Sessions panel: collapsible, persisted across reloads. Start expanded
  // to match SSR, then hydrate from localStorage to avoid hydration mismatches.
  const [sessionsExpanded, setSessionsExpandedState] = useState<boolean>(true);
  useEffect(() => {
    setSessionsExpandedState(readStoredSessionsExpanded());
  }, []);
  const toggleSessions = useCallback(() => {
    setSessionsExpandedState((prev) => {
      const next = !prev;
      writeStoredSessionsExpanded(next);
      return next;
    });
  }, []);

  // Responsive auto-collapse: force the sidebar into its 60px icon-rail when the
  // viewport is narrow so the main content area gets its breathing room. The
  // user can still expand it manually; we only auto-collapse, never auto-expand,
  // to respect their explicit preference on wider screens.
  useEffect(() => {
    if (typeof window === "undefined" || typeof window.matchMedia !== "function") {
      return;
    }
    const narrow = window.matchMedia("(max-width: 768px)");
    const apply = () => {
      if (narrow.matches && !collapsed) {
        setCollapsed(true);
      }
    };
    apply();
    const listener = (e: MediaQueryListEvent) => {
      if (e.matches && !collapsed) setCollapsed(true);
    };
    if (typeof narrow.addEventListener === "function") {
      narrow.addEventListener("change", listener);
      return () => narrow.removeEventListener("change", listener);
    }
    // Safari < 14 fallback
    narrow.addListener(listener);
    return () => narrow.removeListener(listener);
  }, [collapsed, setCollapsed]);

  const handleNewChat = () => {
    if (onNewChat) {
      onNewChat();
      return;
    }
    router.push("/chat");
  };

  /* ---- Collapsed state ---- */
  if (collapsed) {
    return (
      <aside className="group/sb relative flex h-screen w-[60px] shrink-0 flex-col items-center bg-[var(--secondary)] py-3 transition-all duration-200">
        {/* Header: logo + collapse toggle (toggle replaces logo on hover) */}
        <div className="relative mb-2 flex h-9 w-9 shrink-0 items-center justify-center">
          <Link
            href="/"
            aria-label={t("DeepTutor")}
            className="flex items-center justify-center transition-opacity duration-150 group-hover/sb:opacity-0"
          >
            <Image
              src="/logo-ver2.png"
              alt={t("DeepTutor")}
              width={22}
              height={22}
              className="h-[22px] w-[22px] rounded-md"
            />
          </Link>
          <button
            onClick={() => setCollapsed(false)}
            className="absolute inset-0 flex items-center justify-center rounded-lg text-[var(--muted-foreground)] opacity-0 transition-all duration-150 hover:bg-[var(--background)]/60 hover:text-[var(--foreground)] group-hover/sb:opacity-100"
            aria-label={t("Expand sidebar")}
          >
            <PanelLeftOpen size={16} />
          </button>
        </div>

        {/* New chat — visually distinct circular button */}
        <button
          onClick={handleNewChat}
          title={t("New Chat") as string}
          className="mb-2 flex h-9 w-9 shrink-0 items-center justify-center rounded-xl border border-[var(--border)]/50 bg-[var(--background)]/40 text-[var(--foreground)] shadow-sm transition-all duration-150 hover:border-[var(--border)] hover:bg-[var(--background)]/80"
          aria-label={t("New Chat")}
        >
          <Plus size={16} strokeWidth={2.2} />
        </button>

        {/* Subtle divider */}
        <div className="my-1.5 h-px w-7 shrink-0 bg-[var(--border)]/40" />

        {/* Primary nav — scrollable so all entries reach on short viewports */}
        <nav className="flex w-full min-h-0 flex-1 flex-col items-center gap-1 overflow-y-auto overflow-x-hidden px-1.5 [scrollbar-gutter:stable]">
          {PRIMARY_NAV.map((item) => {
            const active = pathname.startsWith(item.href);
            const description = item.tooltipKey
              ? t(item.tooltipKey)
              : undefined;
            return (
              <Tooltip
                key={item.href}
                label={t(item.label)}
                description={description}
                side="right"
              >
                <Link
                  href={item.href}
                  aria-label={t(item.label)}
                  className={`relative flex h-9 w-9 items-center justify-center rounded-xl transition-all duration-150 ${
                    active
                      ? "bg-[var(--background)]/80 text-[var(--foreground)] shadow-sm"
                      : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/50 hover:text-[var(--foreground)]"
                  }`}
                >
                  {active && (
                    <span className="absolute -left-1.5 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-full bg-[var(--foreground)]/80" />
                  )}
                  <item.icon size={18} strokeWidth={active ? 2 : 1.6} />
                </Link>
              </Tooltip>
            );
          })}
          {userRole === "mentor" && (
            <>
              <div className="my-1 h-px w-7 bg-[var(--border)]/40" />
              {MENTOR_NAV.map((item) => {
                const active = pathname.startsWith(item.href);
                return (
                  <Tooltip key={item.href} label={t(item.label)} side="right">
                    <Link
                      href={item.href}
                      aria-label={t(item.label)}
                      className={`relative flex h-9 w-9 items-center justify-center rounded-xl transition-all duration-150 ${
                        active
                          ? "bg-[var(--background)]/80 text-[var(--foreground)] shadow-sm"
                          : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/50 hover:text-[var(--foreground)]"
                      }`}
                    >
                      {active && (
                        <span className="absolute -left-1.5 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-full bg-[var(--foreground)]/80" />
                      )}
                      <item.icon size={18} strokeWidth={active ? 2 : 1.6} />
                    </Link>
                  </Tooltip>
                );
              })}
            </>
          )}
          {userRole === "recruiter" && (
            <>
              <div className="my-1 h-px w-7 bg-[var(--border)]/40" />
              {RECRUITER_NAV.map((item) => {
                const active = pathname.startsWith(item.href);
                return (
                  <Tooltip key={item.href} label={t(item.label)} side="right">
                    <Link
                      href={item.href}
                      aria-label={t(item.label)}
                      className={`relative flex h-9 w-9 items-center justify-center rounded-xl transition-all duration-150 ${
                        active
                          ? "bg-[var(--background)]/80 text-[var(--foreground)] shadow-sm"
                          : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/50 hover:text-[var(--foreground)]"
                      }`}
                    >
                      {active && (
                        <span className="absolute -left-1.5 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-full bg-[var(--foreground)]/80" />
                      )}
                      <item.icon size={18} strokeWidth={active ? 2 : 1.6} />
                    </Link>
                  </Tooltip>
                );
              })}
            </>
          )}
        </nav>

        {/* Secondary nav + footer */}
        <div className="flex w-full shrink-0 flex-col items-center gap-1 px-1.5 pt-1">
          <div className="my-1 h-px w-7 bg-[var(--border)]/40" />
          {SECONDARY_NAV.map((item) => {
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                title={t(item.label) as string}
                className={`relative flex h-9 w-9 items-center justify-center rounded-xl transition-all duration-150 ${
                  active
                    ? "bg-[var(--background)]/80 text-[var(--foreground)] shadow-sm"
                    : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/50 hover:text-[var(--foreground)]"
                }`}
              >
                {active && (
                  <span className="absolute -left-1.5 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-full bg-[var(--foreground)]/80" />
                )}
                <item.icon size={18} strokeWidth={active ? 2 : 1.6} />
              </Link>
            );
          })}
          {footerSlot}
          <SidebarFooterStatus collapsed />
        </div>
      </aside>
    );
  }

  /* ---- Expanded state ---- */
  return (
    <aside className="flex h-screen w-[220px] shrink-0 flex-col bg-[var(--secondary)] transition-all duration-200">
      {/* Header: logo + collapse toggle */}
      <div className="flex h-14 shrink-0 items-center justify-between px-4">
        <Link href="/" className="group flex items-center gap-2">
          <Image
            src="/logo-ver2.png"
            alt={t("DeepTutor")}
            width={22}
            height={22}
            className="h-[22px] w-[22px] transition-transform duration-200 group-hover:scale-105"
          />
          <span className="text-[16px] font-semibold leading-none tracking-[-0.02em] text-[var(--foreground)]">
            {t("DeepTutor")}
          </span>
        </Link>
        <button
          onClick={() => setCollapsed(true)}
          className="rounded-md p-1 text-[var(--muted-foreground)] transition-colors hover:text-[var(--foreground)]"
          aria-label={t("Collapse sidebar")}
        >
          <PanelLeftClose size={15} />
        </button>
      </div>

      {/* Primary nav — scrolls when the entry list exceeds the viewport */}
      <nav className="min-h-0 flex-1 overflow-y-auto overflow-x-hidden px-2 pt-1 pb-2 [scrollbar-gutter:stable]">
        <div className="space-y-px">
          {/* New chat */}
          <button
            onClick={handleNewChat}
            className="flex w-full items-center gap-2.5 rounded-lg px-3 py-2 text-[13.5px] text-[var(--muted-foreground)] transition-colors hover:bg-[var(--background)]/60 hover:text-[var(--foreground)]"
          >
            <Plus size={16} strokeWidth={2} />
            <span>{t("New Chat")}</span>
          </button>

          {PRIMARY_NAV.map((item) => {
            const active = pathname.startsWith(item.href);
            const hasSessionsBelow =
              item.href === "/chat" &&
              showSessions &&
              onSelectSession &&
              onRenameSession &&
              onDeleteSession;
            const hasBots = item.href === "/agents";
            const linkClass = `flex items-center gap-2.5 rounded-lg px-3 py-2 text-[13.5px] transition-colors ${
              active
                ? "bg-[var(--background)]/70 font-medium text-[var(--foreground)]"
                : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/50 hover:text-[var(--foreground)]"
            }`;
            return (
              <div key={item.href}>
                {hasSessionsBelow ? (
                  <div
                    className={`group/chatrow flex items-center gap-0.5 rounded-lg pr-1 transition-colors ${
                      active
                        ? "bg-[var(--background)]/70"
                        : "hover:bg-[var(--background)]/50"
                    }`}
                  >
                    <Link
                      href={item.href}
                      className={`flex flex-1 items-center gap-2.5 rounded-lg px-3 py-2 text-[13.5px] transition-colors ${
                        active
                          ? "font-medium text-[var(--foreground)]"
                          : "text-[var(--muted-foreground)] group-hover/chatrow:text-[var(--foreground)]"
                      }`}
                    >
                      <item.icon size={16} strokeWidth={active ? 1.9 : 1.5} />
                      <span>{t(item.label)}</span>
                    </Link>
                    <button
                      type="button"
                      onClick={toggleSessions}
                      className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md text-[var(--muted-foreground)] transition-colors hover:bg-[var(--background)]/70 hover:text-[var(--foreground)]"
                      aria-expanded={sessionsExpanded}
                      aria-controls="sidebar-chat-sessions"
                      aria-label={
                        sessionsExpanded
                          ? (t("Hide recent chats") as string)
                          : (t("Show recent chats") as string)
                      }
                      title={
                        sessionsExpanded
                          ? (t("Hide recent chats") as string)
                          : (t("Show recent chats") as string)
                      }
                    >
                      {sessionsExpanded ? (
                        <ChevronDown size={14} strokeWidth={1.8} />
                      ) : (
                        <ChevronRight size={14} strokeWidth={1.8} />
                      )}
                    </button>
                  </div>
                ) : (
                  <Link href={item.href} className={linkClass}>
                    <item.icon size={16} strokeWidth={active ? 1.9 : 1.5} />
                    <span>{t(item.label)}</span>
                  </Link>
                )}
                {hasSessionsBelow && sessionsExpanded && (
                  <div
                    id="sidebar-chat-sessions"
                    className={`${sessionViewportClassName} overflow-y-auto`}
                  >
                    <SessionList
                      sessions={sessions}
                      activeSessionId={activeSessionId}
                      loading={loadingSessions}
                      onSelect={onSelectSession}
                      onRename={onRenameSession}
                      onDelete={onDeleteSession}
                      compact
                    />
                  </div>
                )}
                {hasBots && <TutorBotRecent />}
              </div>
            );
          })}

          {/* Mentor section */}
          {userRole === "mentor" && (
            <>
              <div className="my-1.5 h-px bg-[var(--border)]/40" />
              <p className="px-3 pb-1 pt-0.5 text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]/60">
                Mentor
              </p>
              {MENTOR_NAV.map((item) => {
                const active = pathname.startsWith(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`flex items-center gap-2.5 rounded-lg px-3 py-2 text-[13.5px] transition-colors ${
                      active
                        ? "bg-[var(--background)]/70 font-medium text-[var(--foreground)]"
                        : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/50 hover:text-[var(--foreground)]"
                    }`}
                  >
                    <item.icon size={16} strokeWidth={active ? 1.9 : 1.5} />
                    <span>{t(item.label)}</span>
                  </Link>
                );
              })}
            </>
          )}

          {/* Recruiter section */}
          {userRole === "recruiter" && (
            <>
              <div className="my-1.5 h-px bg-[var(--border)]/40" />
              <p className="px-3 pb-1 pt-0.5 text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]/60">
                Recruiter
              </p>
              {RECRUITER_NAV.map((item) => {
                const active = pathname.startsWith(item.href);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`flex items-center gap-2.5 rounded-lg px-3 py-2 text-[13.5px] transition-colors ${
                      active
                        ? "bg-[var(--background)]/70 font-medium text-[var(--foreground)]"
                        : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/50 hover:text-[var(--foreground)]"
                    }`}
                  >
                    <item.icon size={16} strokeWidth={active ? 1.9 : 1.5} />
                    <span>{t(item.label)}</span>
                  </Link>
                );
              })}
            </>
          )}
        </div>
      </nav>

      {/* Secondary nav + footer (pinned to bottom; never scrolls) */}
      <div className="shrink-0 border-t border-[var(--border)]/40 px-2 py-2">
        {SECONDARY_NAV.map((item) => {
          const active = pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-2.5 rounded-lg px-3 py-2 text-[13.5px] transition-colors ${
                active
                  ? "bg-[var(--background)]/70 font-medium text-[var(--foreground)]"
                  : "text-[var(--muted-foreground)] hover:bg-[var(--background)]/50 hover:text-[var(--foreground)]"
              }`}
            >
              <item.icon size={16} strokeWidth={active ? 1.9 : 1.5} />
              <span>{t(item.label)}</span>
            </Link>
          );
        })}
        {footerSlot}
        <SidebarFooterStatus />
      </div>
    </aside>
  );
}
