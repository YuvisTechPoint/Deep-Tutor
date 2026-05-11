import { redirect } from "next/navigation";

/** Canonical WRD path alias → in-app roadmap surface */
export default function LearningPathAliasPage() {
  redirect("/roadmap");
}
