"""Coding Mentor Capability — powered by Qwen2.5-Coder-32B-Instruct via HF router."""
from __future__ import annotations

from deeptutor.capabilities.request_contracts import get_capability_request_schema
from deeptutor.core.capability_protocol import BaseCapability, CapabilityManifest
from deeptutor.core.context import UnifiedContext
from deeptutor.core.stream_bus import StreamBus

_SYSTEM_PROMPT = """You are an expert Coding Mentor. You specialize in:
- Explaining algorithms and data structures step-by-step
- Debugging code with clear root-cause analysis
- Writing clean, well-commented code examples
- Teaching programming concepts from first principles
- Conducting mock technical interviews
- Reviewing code and suggesting improvements with reasoning
- Helping with DSA problems: break them into sub-problems, suggest patterns

Rules:
- Always show code in fenced code blocks with the correct language tag
- For debugging, identify the exact line and explain WHY it fails
- For new concepts, give a minimal example then a realistic one
- Adapt depth to the learner's apparent skill level
- End complex explanations with a "Key takeaway" summary
"""


class CodingMentorCapability(BaseCapability):
    manifest = CapabilityManifest(
        name="coding_mentor",
        description="Expert coding mentor: debugging, DSA, code review, interview prep, project scaffolding.",
        stages=["analyzing", "mentoring", "responding"],
        tools_used=["code_execution", "rag", "web_search"],
        cli_aliases=["code", "coding", "mentor"],
        request_schema=get_capability_request_schema("chat"),
    )

    async def run(self, context: UnifiedContext, stream: StreamBus) -> None:
        from deeptutor.services.llm import stream as llm_stream
        from deeptutor.services.llm.config import get_llm_config
        from deeptutor.services.model_router import detect_intent, get_model_router, Intent

        async with stream.stage("analyzing", source=self.manifest.name):
            await stream.progress("Routing to coding model...", source=self.manifest.name)

        router = get_model_router()
        cfg = router.route(Intent.CODING)

        llm_cfg = get_llm_config()
        api_key = cfg.api_key or llm_cfg.api_key
        base_url = cfg.api_base if cfg.api_key else (llm_cfg.base_url or cfg.api_base)
        model = cfg.model if cfg.api_key else llm_cfg.model

        messages = [{"role": "system", "content": _SYSTEM_PROMPT}]
        for prev in context.history or []:
            role = getattr(prev, "role", None) or prev.get("role", "user")
            content = getattr(prev, "content", None) or prev.get("content", "")
            if role in ("user", "assistant") and content:
                messages.append({"role": role, "content": content})

        messages.append({"role": "user", "content": context.content})

        async with stream.stage("responding", source=self.manifest.name):
            buffer = []
            async for chunk in llm_stream(
                prompt=context.content,
                model=model,
                api_key=api_key,
                base_url=base_url,
                messages=messages,
                temperature=0.2,
            ):
                buffer.append(chunk)
                await stream.content(chunk, source=self.manifest.name)

        await stream.result(
            {"response": "".join(buffer), "model": model, "capability": "coding_mentor"},
            source=self.manifest.name,
        )
