import SpaceMiniNav from "@/components/space/SpaceMiniNav";

export default function SpaceLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <div className="flex min-h-0 w-full flex-1 overflow-hidden">
      <SpaceMiniNav />
      <main className="min-h-0 flex-1 overflow-y-auto bg-[var(--background)] [scrollbar-gutter:stable]">
        <div className="mx-auto max-w-5xl px-6 py-8 pb-12 sm:px-8">{children}</div>
      </main>
    </div>
  );
}
