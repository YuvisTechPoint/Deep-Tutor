import { redirect } from "next/navigation";
import { LandingPage } from "@/components/landing/LandingPage";

type SearchParams = Record<string, string | string[] | undefined>;

function first(v: string | string[] | undefined): string | undefined {
  if (v === undefined) return undefined;
  return Array.isArray(v) ? v[0] : v;
}

/**
 * Deep links like `/?session=…` open the chat workspace.
 * Plain `/` shows the product landing page (canonical IA).
 */
export default async function HomePage({
  searchParams,
}: {
  searchParams: Promise<SearchParams>;
}) {
  const sp = await searchParams;
  const sessionId = first(sp.session);
  if (sessionId) {
    const parts: string[] = [];
    const capability = first(sp.capability);
    if (capability) parts.push(`capability=${encodeURIComponent(capability)}`);
    const toolsRaw = sp.tool;
    const tools = Array.isArray(toolsRaw) ? toolsRaw : toolsRaw ? [toolsRaw] : [];
    for (const t of tools) {
      if (t) parts.push(`tool=${encodeURIComponent(t)}`);
    }
    const qs = parts.length ? `?${parts.join("&")}` : "";
    redirect(`/chat/${sessionId}${qs}`);
  }

  return <LandingPage />;
}
