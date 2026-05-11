import { redirect } from "next/navigation";

/** Canonical recruiter auth lives at `/recruiter/login`; keep this path for middleware + bookmarks. */
export default function RecruiterLoginAliasPage() {
  redirect("/recruiter/login");
}
