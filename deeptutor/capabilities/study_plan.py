"""Study Plan Capability - turns the roadmap engine into a tutor response."""

from __future__ import annotations

from typing import Any

from deeptutor.capabilities.request_contracts import get_capability_request_schema
from deeptutor.core.capability_protocol import BaseCapability, CapabilityManifest
from deeptutor.core.context import UnifiedContext
from deeptutor.core.stream_bus import StreamBus
from deeptutor.services.learning_plan import build_plan


class StudyPlanCapability(BaseCapability):
    manifest = CapabilityManifest(
        name="study_plan",
        description=(
            "Create a practical study plan from the learner's goal, weekly time, "
            "experience level, and DeepTutor roadmap milestones."
        ),
        stages=["profiling", "planning", "responding"],
        tools_used=["rag"],
        cli_aliases=["study", "plan", "roadmap"],
        config_defaults={
            "weekly_hours": 6,
            "experience_level": "beginner",
            "focus_days": 7,
        },
        request_schema=get_capability_request_schema("study_plan"),
    )

    async def run(self, context: UnifiedContext, stream: StreamBus) -> None:
        cfg = context.config_overrides or {}

        async with stream.stage("profiling", source=self.name):
            profile = self._profile_from_context(context, cfg)
            await stream.progress(
                f"Using {profile['weekly_hours']} study hours/week for {profile['target_path']}.",
                source=self.name,
            )

        async with stream.stage("planning", source=self.name):
            plan = build_plan(profile)
            active = self._active_milestones(plan)
            await stream.progress(
                f"Selected {len(active)} immediate milestone(s) from {plan['title']}.",
                source=self.name,
            )

        async with stream.stage("responding", source=self.name):
            response = self._render_response(plan, profile, active)
            await stream.content(response, source=self.name)

        await stream.result(
            {
                "response": response,
                "capability": self.name,
                "profile": profile,
                "plan": plan,
                "active_milestones": active,
            },
            source=self.name,
        )

    @staticmethod
    def _profile_from_context(
        context: UnifiedContext,
        cfg: dict[str, Any],
    ) -> dict[str, Any]:
        target_path = str(cfg.get("target_path") or context.user_message or "AI learning").strip()
        goals = cfg.get("goals") or []
        if isinstance(goals, str):
            goals = [goals]
        if not goals and context.user_message:
            goals = [context.user_message]
        return {
            "target_path": target_path,
            "goals": [str(goal) for goal in goals if str(goal).strip()],
            "weekly_hours": int(cfg.get("weekly_hours") or 6),
            "experience_level": str(cfg.get("experience_level") or "beginner").lower(),
        }

    @staticmethod
    def _active_milestones(plan: dict[str, Any]) -> list[dict[str, Any]]:
        active: list[dict[str, Any]] = []
        for phase in plan.get("phases", []):
            for milestone in phase.get("milestones", []):
                if milestone.get("status") == "active":
                    active.append(
                        {
                            "phase": phase.get("title", ""),
                            "id": milestone.get("id", ""),
                            "title": milestone.get("title", ""),
                            "description": milestone.get("description", ""),
                            "estimated_days": milestone.get("estimated_days", 0),
                            "skills": list(milestone.get("skills") or []),
                            "resources": list(milestone.get("resources") or []),
                        }
                    )
        if active:
            return active

        for phase in plan.get("phases", []):
            for milestone in phase.get("milestones", []):
                if milestone.get("status") in {"available", "locked"}:
                    return [
                        {
                            "phase": phase.get("title", ""),
                            "id": milestone.get("id", ""),
                            "title": milestone.get("title", ""),
                            "description": milestone.get("description", ""),
                            "estimated_days": milestone.get("estimated_days", 0),
                            "skills": list(milestone.get("skills") or []),
                            "resources": list(milestone.get("resources") or []),
                        }
                    ]
        return []

    @staticmethod
    def _render_response(
        plan: dict[str, Any],
        profile: dict[str, Any],
        active: list[dict[str, Any]],
    ) -> str:
        totals = plan.get("totals", {})
        lines = [
            f"## {plan.get('title', 'Study Plan')}",
            "",
            f"Goal: {profile['target_path']}",
            f"Pace: {profile['weekly_hours']} hours/week, {profile['experience_level']} level",
            f"Progress: {totals.get('milestones_completed', 0)}/{totals.get('milestones_total', 0)} milestones complete",
            "",
            "### This week",
        ]

        if not active:
            lines.append("- Review completed milestones and choose the next topic from Roadmap.")
            return "\n".join(lines)

        first = active[0]
        skills = ", ".join(first.get("skills") or ["core concepts"])
        days = first.get("estimated_days") or 7
        lines.extend(
            [
                f"- Focus milestone: **{first['title']}** ({first['phase']})",
                f"- Outcome: {first['description']}",
                f"- Skills: {skills}",
                f"- Suggested duration: {days} day(s)",
                "",
                "### 7-day cadence",
                "- Day 1: Diagnose what you already know and write three questions.",
                "- Day 2-3: Learn the core concept, then explain it in your own words.",
                "- Day 4-5: Complete practice tasks and ask DeepTutor to review mistakes.",
                "- Day 6: Build or solve one small applied challenge.",
                "- Day 7: Take a short quiz, mark the milestone complete if ready, and plan the next one.",
            ]
        )

        resources = first.get("resources") or []
        if resources:
            lines.extend(["", "### Starter resources"])
            for resource in resources[:3]:
                title = resource.get("title", "Resource")
                kind = resource.get("type", "resource")
                duration = resource.get("duration", "")
                suffix = f" - {duration}" if duration else ""
                lines.append(f"- {title} ({kind}){suffix}")

        return "\n".join(lines)
