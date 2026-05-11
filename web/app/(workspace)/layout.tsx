import WorkspaceSidebar from "@/components/sidebar/WorkspaceSidebar";
import { UnifiedChatProvider } from "@/context/UnifiedChatContext";

export default function WorkspaceLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <UnifiedChatProvider>
      <div className="flex h-screen overflow-hidden">
        <WorkspaceSidebar />
        <main className="flex min-h-0 flex-1 flex-col overflow-hidden bg-[var(--background)]">
          {children}
        </main>
      </div>
    </UnifiedChatProvider>
  );
}
