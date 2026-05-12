import type { ReactNode } from "react";
import Link from "next/link";
import { DEFAULT_POST_LOGIN_PATH } from "@/lib/auth-routes";
import { marketingLoginUrl, marketingSignupUrl } from "@/lib/external-auth";
import {
  BarChart3,
  BookOpen,
  Brain,
  Briefcase,
  Building2,
  ClipboardCheck,
  Cpu,
  Layers,
  LineChart,
  Mic,
  Route,
  Search,
  Shield,
  Sparkles,
  Target,
  Users,
  Zap,
} from "lucide-react";

const features = [
  {
    title: "Adaptive roadmaps",
    body: "Diagnostics and mastery signals reshape what you study next—always explainable.",
    icon: Route,
    accent: "from-amber-500/25 to-orange-600/10",
  },
  {
    title: "Multimodal tutor",
    body: "Chat, voice, diagrams, and point-and-ask flows grounded on your materials.",
    icon: Mic,
    accent: "from-violet-500/25 to-fuchsia-600/10",
  },
  {
    title: "Career intelligence",
    body: "EIP-linked progress maps to roles, gaps, and evidence recruiters can trust.",
    icon: Briefcase,
    accent: "from-sky-500/25 to-cyan-600/10",
  },
  {
    title: "Institution-ready",
    body: "Mentor consoles, cohort analytics, moderation, and model routing controls.",
    icon: Building2,
    accent: "from-emerald-500/25 to-teal-600/10",
  },
] as const;

const capabilityTiles = [
  { label: "Knowledge RAG", desc: "Ground answers in your corpus", icon: Search },
  { label: "Deep solve", desc: "Step-wise reasoning pipelines", icon: Brain },
  { label: "Assessments", desc: "Adaptive checks & mock flows", icon: ClipboardCheck },
  { label: "Cohort analytics", desc: "Signals mentors can act on", icon: BarChart3 },
  { label: "Model routing", desc: "Policy-aware model choice", icon: Cpu },
  { label: "Safety layer", desc: "Moderation & audit hooks", icon: Shield },
] as const;

const journey = [
  {
    step: "01",
    title: "Diagnose",
    body: "Placement-style probes and gap maps anchor the plan—not generic playlists.",
  },
  {
    step: "02",
    title: "Learn",
    body: "Lessons, tutor chat, and multimodal explanations tied to objectives you own.",
  },
  {
    step: "03",
    title: "Prove",
    body: "Practice banks, mock tests, and evidence you can export for coaches or hiring.",
  },
] as const;

const stackBadges = ["Your syllabus", "Your PDFs & links", "Your model policies", "Your brand"];

function SafeNavLink({
  href,
  className,
  children,
}: {
  href: string;
  className: string;
  children: ReactNode;
}) {
  if (href.startsWith("http://") || href.startsWith("https://")) {
    return (
      <a href={href} className={className}>
        {children}
      </a>
    );
  }
  return (
    <Link href={href} className={className}>
      {children}
    </Link>
  );
}

function HeroMock() {
  return (
    <div
      className="relative mx-auto w-full max-w-md select-none lg:mx-0"
      aria-hidden
    >
      <div className="absolute -inset-4 rounded-[2rem] bg-gradient-to-br from-[var(--primary)]/20 via-transparent to-violet-500/15 blur-2xl" />
      <div className="relative overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--card)]/90 shadow-2xl backdrop-blur-md">
        <div className="flex items-center justify-between border-b border-[var(--border)] bg-[var(--muted)]/50 px-4 py-3">
          <div className="flex items-center gap-2">
            <span className="flex h-2 w-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.6)]" />
            <span className="text-xs font-medium text-[var(--muted-foreground)]">
              Tutor workspace
            </span>
          </div>
          <Sparkles className="h-4 w-4 text-[var(--primary)]" />
        </div>
        <div className="grid grid-cols-[minmax(0,7rem)_1fr] gap-0">
          <div className="border-r border-[var(--border)] bg-[var(--muted)]/30 p-3">
            <div className="space-y-2">
              {["Roadmap", "Practice", "Career"].map((label) => (
                <div
                  key={label}
                  className="rounded-lg border border-transparent bg-[var(--card)]/80 px-2 py-1.5 text-[10px] font-medium text-[var(--muted-foreground)]"
                >
                  {label}
                </div>
              ))}
            </div>
          </div>
          <div className="space-y-3 p-4">
            <div className="rounded-xl rounded-tl-sm border border-[var(--border)] bg-[var(--muted)]/40 px-3 py-2 text-[11px] leading-relaxed text-[var(--muted-foreground)]">
              Here is a worked example with a diagram hint—want the short version or the proof
              walkthrough?
            </div>
            <div className="ml-4 rounded-xl rounded-tr-sm border border-[var(--primary)]/35 bg-[var(--primary)]/10 px-3 py-2 text-[11px] font-medium text-[var(--foreground)]">
              Show the proof walkthrough and a quick self-check at the end.
            </div>
            <div className="flex items-center gap-2 pt-1">
              <div className="h-1 flex-1 overflow-hidden rounded-full bg-[var(--border)]">
                <div className="h-full w-2/3 rounded-full bg-gradient-to-r from-[var(--primary)] to-violet-500" />
              </div>
              <Zap className="h-3.5 w-3.5 shrink-0 text-[var(--primary)]" />
            </div>
          </div>
        </div>
      </div>
      <div className="pointer-events-none absolute -bottom-6 -right-6 hidden h-28 w-28 rounded-2xl border border-dashed border-[var(--border)] bg-[var(--card)]/40 sm:block" />
      <div className="pointer-events-none absolute -left-8 top-1/3 hidden h-16 w-16 rotate-12 rounded-xl border border-[var(--border)] bg-gradient-to-br from-[var(--primary)]/15 to-transparent sm:block" />
    </div>
  );
}

export function LandingPage() {
  const signInHref = marketingLoginUrl({ next: DEFAULT_POST_LOGIN_PATH });
  const registerHref = marketingSignupUrl();

  return (
    <div className="min-h-screen bg-[var(--background)] text-[var(--foreground)]">
      <div
        className="pointer-events-none fixed inset-0 -z-10 opacity-[0.35] dark:opacity-[0.22]"
        style={{
          backgroundImage: `radial-gradient(circle at 1px 1px, var(--border) 1px, transparent 0)`,
          backgroundSize: "28px 28px",
        }}
        aria-hidden
      />

      <header className="sticky top-0 z-20 border-b border-[var(--border)] bg-[var(--card)]/75 backdrop-blur-md">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4 sm:px-6">
          <Link href="/" className="group flex items-baseline gap-2">
            <span className="text-sm font-semibold tracking-tight transition group-hover:text-[var(--primary)] sm:text-base">
              DeepTutor
            </span>
            <span className="hidden text-xs font-normal text-[var(--muted-foreground)] sm:inline">
              Adaptive learning OS
            </span>
          </Link>
          <nav className="flex items-center gap-2 sm:gap-3">
            <SafeNavLink
              href={signInHref}
              className="rounded-md px-3 py-1.5 text-sm text-[var(--muted-foreground)] transition hover:text-[var(--foreground)]"
            >
              Sign in
            </SafeNavLink>
            <SafeNavLink
              href={registerHref}
              className="rounded-md bg-[var(--primary)] px-3 py-1.5 text-sm font-medium text-[var(--primary-foreground)] shadow-sm transition hover:opacity-90"
            >
              Get started
            </SafeNavLink>
          </nav>
        </div>
      </header>

      <main>
        <section className="relative overflow-hidden border-b border-[var(--border)]">
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_90%_60%_at_70%_-10%,rgba(176,80,30,0.14),transparent)] dark:bg-[radial-gradient(ellipse_90%_55%_at_65%_-15%,rgba(157,80,187,0.18),transparent)]" />
          <div className="pointer-events-none absolute bottom-0 left-1/2 h-px w-[min(100%,80rem)] -translate-x-1/2 bg-gradient-to-r from-transparent via-[var(--primary)]/40 to-transparent" />

          <div className="relative mx-auto grid max-w-6xl items-center gap-12 px-4 py-16 sm:px-6 sm:py-24 lg:grid-cols-[minmax(0,1fr)_minmax(0,26rem)] lg:gap-16">
            <div>
              <p className="inline-flex items-center gap-2 text-xs font-medium uppercase tracking-[0.2em] text-[var(--primary)]">
                <Layers className="h-3.5 w-3.5" aria-hidden />
                AI-native tutoring
              </p>
              <h1 className="mt-3 max-w-2xl text-3xl font-semibold tracking-tight sm:text-4xl md:text-5xl md:leading-[1.1]">
                An adaptive mentor—not a static course catalog.
              </h1>
              <p className="mt-4 max-w-xl text-base leading-relaxed text-[var(--muted-foreground)] sm:text-lg">
                Personalized diagnostics, lessons, assessments, and a multimodal tutor workspace
                designed as a production-grade learning operating system with EIP and career
                signals.
              </p>
              <div className="mt-8 flex flex-wrap gap-3">
                <Link
                  href="/onboarding"
                  className="inline-flex items-center justify-center gap-2 rounded-lg bg-[var(--primary)] px-5 py-2.5 text-sm font-medium text-[var(--primary-foreground)] shadow-md transition hover:opacity-90"
                >
                  <Target className="h-4 w-4" aria-hidden />
                  Start onboarding
                </Link>
                <Link
                  href="/chat"
                  className="inline-flex items-center justify-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--card)] px-5 py-2.5 text-sm font-medium text-[var(--foreground)] shadow-sm transition hover:bg-[var(--muted)]"
                >
                  <BookOpen className="h-4 w-4" aria-hidden />
                  Open tutor workspace
                </Link>
                <Link
                  href="/mobile-study"
                  className="inline-flex items-center justify-center gap-2 rounded-lg border border-dashed border-[var(--border)] px-5 py-2.5 text-sm font-medium text-[var(--muted-foreground)] transition hover:border-[var(--primary)] hover:text-[var(--foreground)]"
                >
                  Mobile study mode
                </Link>
              </div>

              <dl className="mt-10 grid max-w-lg grid-cols-3 gap-3 border-t border-[var(--border)] pt-8 sm:gap-4">
                <div>
                  <dt className="text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
                    Modes
                  </dt>
                  <dd className="mt-1 text-sm font-semibold">Chat · voice · visual</dd>
                </div>
                <div>
                  <dt className="text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
                    Surface
                  </dt>
                  <dd className="mt-1 text-sm font-semibold">Learner + mentor</dd>
                </div>
                <div>
                  <dt className="text-[10px] font-semibold uppercase tracking-wider text-[var(--muted-foreground)]">
                    Deploy
                  </dt>
                  <dd className="mt-1 text-sm font-semibold">API-first stack</dd>
                </div>
              </dl>
            </div>

            <HeroMock />
          </div>
        </section>

        <section className="border-b border-[var(--border)] bg-[var(--muted)]/25 py-10 sm:py-12">
          <div className="mx-auto max-w-6xl px-4 sm:px-6">
            <p className="text-center text-xs font-semibold uppercase tracking-[0.18em] text-[var(--muted-foreground)]">
              Designed to plug into your world
            </p>
            <div className="mt-6 flex flex-wrap items-center justify-center gap-2 sm:gap-3">
              {stackBadges.map((b) => (
                <span
                  key={b}
                  className="rounded-full border border-[var(--border)] bg-[var(--card)] px-4 py-1.5 text-xs font-medium text-[var(--muted-foreground)] shadow-sm"
                >
                  {b}
                </span>
              ))}
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-6xl px-4 py-14 sm:px-6 sm:py-20">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h2 className="text-lg font-semibold tracking-tight sm:text-xl">
                Built for serious learners and institutions
              </h2>
              <p className="mt-1 max-w-2xl text-sm text-[var(--muted-foreground)]">
                Four pillars that stay visible in the product—not slide-deck promises.
              </p>
            </div>
            <Link
              href="/dashboard"
              className="mt-2 inline-flex items-center gap-1 text-sm font-medium text-[var(--primary)] hover:underline sm:mt-0"
            >
              <LineChart className="h-4 w-4" aria-hidden />
              View learner dashboard
            </Link>
          </div>
          <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {features.map((f) => {
              const Icon = f.icon;
              return (
                <div
                  key={f.title}
                  className="group relative overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--card)] p-5 shadow-sm transition hover:border-[var(--primary)]/40 hover:shadow-md"
                >
                  <div
                    className={`pointer-events-none absolute -right-8 -top-8 h-24 w-24 rounded-full bg-gradient-to-br ${f.accent} opacity-80 blur-2xl transition group-hover:opacity-100`}
                  />
                  <div className="relative flex h-10 w-10 items-center justify-center rounded-xl border border-[var(--border)] bg-[var(--muted)]/60 text-[var(--primary)]">
                    <Icon className="h-5 w-5" aria-hidden />
                  </div>
                  <h3 className="relative mt-4 text-sm font-semibold">{f.title}</h3>
                  <p className="relative mt-2 text-sm leading-relaxed text-[var(--muted-foreground)]">
                    {f.body}
                  </p>
                </div>
              );
            })}
          </div>
        </section>

        <section className="border-t border-[var(--border)] bg-[var(--card)]/40 py-14 sm:py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-6">
            <div className="mx-auto max-w-2xl text-center">
              <h2 className="text-lg font-semibold tracking-tight sm:text-xl">
                Capability surface you can ship behind
              </h2>
              <p className="mt-2 text-sm text-[var(--muted-foreground)]">
                Agent tools, governance, and UX rails that read as one system—not a patchwork of
                demos.
              </p>
            </div>
            <div className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              {capabilityTiles.map((c) => {
                const Icon = c.icon;
                return (
                  <div
                    key={c.label}
                    className="flex gap-4 rounded-xl border border-[var(--border)] bg-[var(--background)]/80 p-4 shadow-sm"
                  >
                    <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-[var(--muted)] text-[var(--primary)]">
                      <Icon className="h-5 w-5" aria-hidden />
                    </div>
                    <div>
                      <h3 className="text-sm font-semibold">{c.label}</h3>
                      <p className="mt-1 text-xs leading-relaxed text-[var(--muted-foreground)]">
                        {c.desc}
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-6xl px-4 py-14 sm:px-6 sm:py-20">
          <h2 className="text-center text-lg font-semibold tracking-tight sm:text-xl">
            A learning loop you can explain to stakeholders
          </h2>
          <div className="mt-10 grid gap-6 md:grid-cols-3">
            {journey.map((j, i) => (
              <div key={j.step} className="relative">
                {i < journey.length - 1 ? (
                  <div
                    className="absolute left-[calc(50%+3.5rem)] top-10 hidden h-px w-[calc(100%-3.5rem)] bg-gradient-to-r from-[var(--primary)]/50 to-transparent md:block"
                    aria-hidden
                  />
                ) : null}
                <div className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-6 text-center shadow-sm md:text-left">
                  <span className="inline-flex rounded-full border border-[var(--primary)]/30 bg-[var(--primary)]/10 px-3 py-1 text-xs font-bold tabular-nums text-[var(--primary)]">
                    {j.step}
                  </span>
                  <h3 className="mt-4 text-base font-semibold">{j.title}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-[var(--muted-foreground)]">
                    {j.body}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </section>

        <section className="border-y border-[var(--border)] bg-gradient-to-b from-[var(--muted)]/30 to-transparent py-12 sm:py-16">
          <div className="mx-auto max-w-6xl px-4 sm:px-6">
            <div className="grid gap-8 lg:grid-cols-[1fr_minmax(0,20rem)] lg:items-center">
              <div>
                <h2 className="text-lg font-semibold tracking-tight">What teams tell us they need</h2>
                <p className="mt-2 text-sm text-[var(--muted-foreground)]">
                  Paraphrased patterns from early design partners—focused outcomes, not vanity quotes.
                </p>
                <ul className="mt-6 space-y-4">
                  {[
                    "“We need explainable next steps, not black-box recommendations.”",
                    "“Mentors need a cockpit, not another analytics export.”",
                    "“Career evidence should come from real work samples, not buzzwords.”",
                  ].map((q) => (
                    <li
                      key={q}
                      className="flex gap-3 rounded-xl border border-[var(--border)] bg-[var(--card)]/90 p-4 text-sm leading-relaxed text-[var(--muted-foreground)]"
                    >
                      <Users className="mt-0.5 h-4 w-4 shrink-0 text-[var(--primary)]" aria-hidden />
                      {q}
                    </li>
                  ))}
                </ul>
              </div>
              <div className="rounded-2xl border border-[var(--border)] bg-[var(--card)] p-6 shadow-lg">
                <p className="text-xs font-semibold uppercase tracking-wider text-[var(--primary)]">
                  Template: launch checklist
                </p>
                <ul className="mt-4 space-y-3 text-sm text-[var(--muted-foreground)]">
                  <li className="flex gap-2">
                    <span className="text-[var(--primary)]">✓</span>
                    Define cohorts, roles, and model policy
                  </li>
                  <li className="flex gap-2">
                    <span className="text-[var(--primary)]">✓</span>
                    Ingest syllabus + reference library
                  </li>
                  <li className="flex gap-2">
                    <span className="text-[var(--primary)]">✓</span>
                    Turn on mentor interventions + alerts
                  </li>
                  <li className="flex gap-2">
                    <span className="text-[var(--primary)]">✓</span>
                    Ship learner dashboard + career page
                  </li>
                </ul>
                <Link
                  href="/onboarding"
                  className="mt-6 flex w-full items-center justify-center gap-2 rounded-lg border border-dashed border-[var(--border)] py-2.5 text-sm font-medium text-[var(--foreground)] transition hover:border-[var(--primary)] hover:bg-[var(--muted)]/50"
                >
                  Use this flow in onboarding
                </Link>
              </div>
            </div>
          </div>
        </section>

        <section className="border-t border-[var(--border)] bg-[var(--muted)]/40 py-12 sm:py-16">
          <div className="mx-auto flex max-w-6xl flex-col items-start gap-4 px-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
            <div>
              <h2 className="text-lg font-semibold tracking-tight">Ready when you are</h2>
              <p className="mt-1 text-sm text-[var(--muted-foreground)]">
                Sign in, run diagnostics, and resume wherever you left off.
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              <Link
                href="/dashboard"
                className="inline-flex items-center gap-2 rounded-lg bg-[var(--foreground)] px-4 py-2 text-sm font-medium text-[var(--background)] transition hover:opacity-90 dark:bg-[var(--primary)] dark:text-[var(--primary-foreground)]"
              >
                <LineChart className="h-4 w-4" aria-hidden />
                Learner dashboard
              </Link>
              <Link
                href="/roadmap"
                className="inline-flex items-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--card)] px-4 py-2 text-sm font-medium transition hover:bg-[var(--muted)]"
              >
                <Route className="h-4 w-4" aria-hidden />
                Adaptive roadmap
              </Link>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-[var(--border)] py-10 text-center text-xs text-[var(--muted-foreground)]">
        <p>
          Product specification: see{" "}
          <code className="rounded bg-[var(--muted)] px-1.5 py-0.5 font-mono text-[11px]">
            docs/canonical_requirements.md
          </code>{" "}
          in the repository.
        </p>
        <p className="mt-3 text-[10px] uppercase tracking-wider text-[var(--muted-foreground)]/80">
          DeepTutor · Agent-native learning companion
        </p>
      </footer>
    </div>
  );
}
