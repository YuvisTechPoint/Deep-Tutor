"""Career Agent Capability — skill gap analysis, job readiness, roadmaps."""
from __future__ import annotations

import json
import re
from typing import Any

from deeptutor.capabilities.request_contracts import get_capability_request_schema
from deeptutor.core.capability_protocol import BaseCapability, CapabilityManifest
from deeptutor.core.context import UnifiedContext
from deeptutor.core.stream_bus import StreamBus

_CAREER_SYSTEM = """You are a world-class Career Intelligence Agent for tech professionals.
You help learners:
1. Map their current skills to target job roles
2. Identify precise skill gaps
3. Build 30/60/90-day learning roadmaps
4. Estimate job readiness (0-100%) with reasoning
5. Compare career paths with pros/cons
6. Generate interview preparation checklists
7. Suggest portfolio projects for the target role

Always be specific, actionable, and data-driven. Reference real job market expectations.
Format responses in clear sections with headings, bullet lists, and progress indicators.
"""

_ROADMAP_PROMPT = """Create a detailed, actionable learning roadmap for:
Target role: {role}
Current skills: {skills}
Timeline: {timeline}
Experience level: {level}

Structure the roadmap as:
1. Skill gap analysis (table: skill | have | need | gap)
2. Phase-by-phase plan (30/60/90 days or milestones)
3. Specific resources for each phase
4. Projects to build for the portfolio
5. Job readiness score estimate (0-100%) with justification
6. Top 3 interview topics to focus on

Be highly specific — mention exact libraries, tools, and concepts.
"""


def _parse_json_block(text: str) -> dict[str, Any] | None:
    m = re.search(r"```(?:json)?\s*([\s\S]+?)```", text)
    raw = m.group(1) if m else text.strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


class CareerAgentCapability(BaseCapability):
    manifest = CapabilityManifest(
        name="career_agent",
        description=(
            "Career intelligence: skill gap analysis, job readiness scoring, "
            "learning roadmaps, career path comparison."
        ),
        stages=["analyzing", "planning", "responding"],
        tools_used=["web_search", "rag"],
        cli_aliases=["career", "roadmap", "job"],
        config_defaults={
            "mode": "roadmap",
            "timeline": "3 months",
            "level": "mid-level",
        },
        request_schema=get_capability_request_schema("chat"),
    )

    async def run(self, context: UnifiedContext, stream: StreamBus) -> None:
        from deeptutor.services.llm import stream as llm_stream
        from deeptutor.services.llm.config import get_llm_config
        from deeptutor.services.model_router import Intent, get_model_router

        router = get_model_router()
        hf_cfg = router.route(Intent.CAREER)
        llm_cfg = get_llm_config()

        api_key = hf_cfg.api_key or llm_cfg.api_key
        base_url = hf_cfg.api_base if hf_cfg.api_key else (llm_cfg.base_url or hf_cfg.api_base)
        model = hf_cfg.model if hf_cfg.api_key else llm_cfg.model

        cfg = context.config_overrides or {}
        mode = cfg.get("mode", "roadmap")

        async with stream.stage("analyzing", source=self.manifest.name):
            await stream.progress("Analyzing career profile...", source=self.manifest.name)

        if mode == "roadmap":
            prompt = _ROADMAP_PROMPT.format(
                role=cfg.get("role", context.content),
                skills=cfg.get("skills", "to be inferred from query"),
                timeline=cfg.get("timeline", "3 months"),
                level=cfg.get("level", "mid-level"),
            )
        else:
            prompt = context.content

        async with stream.stage("responding", source=self.manifest.name):
            buffer: list[str] = []
            async for chunk in llm_stream(
                prompt=prompt,
                system_prompt=_CAREER_SYSTEM,
                model=model,
                api_key=api_key,
                base_url=base_url,
                temperature=0.3,
            ):
                buffer.append(chunk)
                await stream.content(chunk, source=self.manifest.name)

        full = "".join(buffer)
        await stream.result(
            {"response": full, "mode": mode, "capability": "career_agent", "model": model},
            source=self.manifest.name,
        )
