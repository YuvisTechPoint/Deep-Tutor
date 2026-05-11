import Link from "next/link";

const features = [
  {
    title: "Adaptive roadmaps",
    body: "Diagnostics and mastery signals reshape what you study next—always explainable.",
  },
  {
    title: "Multimodal tutor",
    body: "Chat, voice, diagrams, and point-and-ask flows grounded on your materials.",
  },
  {
    title: "Career intelligence",
    body: "EIP-linked progress maps to roles, gaps, and evidence recruiters can trust.",
  },
  {
    title: "Institution-ready",
    body: "Mentor consoles, cohort analytics, moderation, and model routing controls.",
  },
];

export function LandingPage() {
  return (
    <div className="min-h-screen bg-[var(--background)] text-[var(--foreground)]">
      <header className="border-b border-[var(--border)] bg-[var(--card)]/80 backdrop-blur-sm sticky top-0 z-10">
        <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-4 sm:px-6">
          <span className="text-sm font-semibold tracking-tight sm:text-base">
            DeepTutor
            <span className="ml-2 font-normal text-[var(--muted-foreground)]">
              Adaptive learning OS
            </span>
          </span>
          <nav className="flex items-center gap-2 sm:gap-3">
            <Link
              href="/login"
              className="rounded-md px-3 py-1.5 text-sm text-[var(--muted-foreground)] transition hover:text-[var(--foreground)]"
            >
              Sign in
            </Link>
            <Link
              href="/register"
              className="rounded-md bg-[var(--primary)] px-3 py-1.5 text-sm font-medium text-[var(--primary-foreground)] shadow-sm transition hover:opacity-90"
            >
              Get started
            </Link>
          </nav>
        </div>
      </header>

      <main>
        <section className="relative overflow-hidden border-b border-[var(--border)]">
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_-20%,rgba(176,80,30,0.18),transparent)] dark:bg-[radial-gradient(ellipse_80%_50%_at_50%_-20%,rgba(212,115,75,0.15),transparent)]" />
          <div className="relative mx-auto max-w-6xl px-4 py-16 sm:px-6 sm:py-24">
            <p className="text-xs font-medium uppercase tracking-[0.2em] text-[var(--primary)]">
              AI-native tutoring
            </p>
            <h1 className="mt-3 max-w-3xl text-3xl font-semibold tracking-tight sm:text-4xl md:text-5xl">
              An adaptive mentor—not a static course catalog.
            </h1>
            <p className="mt-4 max-w-2xl text-base leading-relaxed text-[var(--muted-foreground)] sm:text-lg">
              Personalized diagnostics, lessons, assessments, and a multimodal tutor workspace
              designed as a production-grade learning operating system with EIP and career signals.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <Link
                href="/onboarding"
                className="inline-flex items-center justify-center rounded-lg bg-[var(--primary)] px-5 py-2.5 text-sm font-medium text-[var(--primary-foreground)] shadow-md transition hover:opacity-90"
              >
                Start onboarding
              </Link>
              <Link
                href="/chat"
                className="inline-flex items-center justify-center rounded-lg border border-[var(--border)] bg-[var(--card)] px-5 py-2.5 text-sm font-medium text-[var(--foreground)] transition hover:bg-[var(--muted)]"
              >
                Open tutor workspace
              </Link>
              <Link
                href="/mobile-study"
                className="inline-flex items-center justify-center rounded-lg border border-dashed border-[var(--border)] px-5 py-2.5 text-sm font-medium text-[var(--muted-foreground)] transition hover:border-[var(--primary)] hover:text-[var(--foreground)]"
              >
                Mobile study mode
              </Link>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-6xl px-4 py-14 sm:px-6 sm:py-20">
          <h2 className="text-lg font-semibold tracking-tight sm:text-xl">
            Built for serious learners and institutions
          </h2>
          <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {features.map((f) => (
              <div
                key={f.title}
                className="rounded-xl border border-[var(--border)] bg-[var(--card)] p-4 shadow-sm"
              >
                <h3 className="text-sm font-semibold">{f.title}</h3>
                <p className="mt-2 text-sm leading-relaxed text-[var(--muted-foreground)]">
                  {f.body}
                </p>
              </div>
            ))}
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
                className="rounded-lg bg-[var(--foreground)] px-4 py-2 text-sm font-medium text-[var(--background)] transition hover:opacity-90 dark:bg-[var(--primary)] dark:text-[var(--primary-foreground)]"
              >
                Learner dashboard
              </Link>
              <Link
                href="/roadmap"
                className="rounded-lg border border-[var(--border)] bg-[var(--card)] px-4 py-2 text-sm font-medium transition hover:bg-[var(--muted)]"
              >
                Adaptive roadmap
              </Link>
            </div>
          </div>
        </section>
      </main>

      <footer className="border-t border-[var(--border)] py-8 text-center text-xs text-[var(--muted-foreground)]">
        Product specification: see{" "}
        <code className="rounded bg-[var(--muted)] px-1 py-0.5">docs/canonical_requirements.md</code> in
        the repository.
      </footer>
    </div>
  );
}
