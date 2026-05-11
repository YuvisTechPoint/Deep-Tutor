"""Assessment Capability — generates quizzes, evaluates answers, infers mastery."""
from __future__ import annotations

import json
import re
from typing import Any

from deeptutor.capabilities.request_contracts import get_capability_request_schema
from deeptutor.core.capability_protocol import BaseCapability, CapabilityManifest
from deeptutor.core.context import UnifiedContext
from deeptutor.core.stream_bus import StreamBus

_QUIZ_GENERATION_PROMPT = """You are an expert Assessment Designer for adaptive learning.
Generate {num_questions} high-quality MCQ questions on: {topic}
Difficulty: {difficulty} (easy/medium/hard)
Focus: {focus}

Return ONLY valid JSON in this exact format:
{{
  "topic": "<topic>",
  "difficulty": "<difficulty>",
  "questions": [
    {{
      "id": 1,
      "question": "<question text>",
      "options": {{"A": "...", "B": "...", "C": "...", "D": "..."}},
      "correct": "A",
      "explanation": "<why correct and why others are wrong>",
      "tags": ["concept1", "concept2"],
      "difficulty": "medium"
    }}
  ]
}}

Rules:
- Every question must test genuine understanding, not trivia
- Distractors should represent common misconceptions
- Explanations must be educational and thorough
- Tags should map to specific sub-concepts for mastery tracking
"""

_EVALUATION_PROMPT = """You are an expert learning evaluator.
Evaluate the student's answer and provide structured feedback.

Question: {question}
Correct answer: {correct} — {explanation}
Student answer: {student_answer}

Return ONLY valid JSON:
{{
  "is_correct": true/false,
  "score": 0-100,
  "feedback": "<constructive explanation>",
  "misconception": "<identified misconception or null>",
  "hint_for_retry": "<hint if wrong, or null>",
  "mastery_signal": "strong/developing/weak"
}}
"""


def _parse_json_block(text: str) -> dict[str, Any] | None:
    m = re.search(r"```(?:json)?\s*([\s\S]+?)```", text)
    raw = m.group(1) if m else text.strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


class AssessmentCapability(BaseCapability):
    manifest = CapabilityManifest(
        name="assessment",
        description=(
            "Generate quizzes and mock tests, evaluate student answers, "
            "infer mastery level, and recommend revision topics."
        ),
        stages=["designing", "generating", "evaluating"],
        tools_used=["rag"],
        cli_aliases=["quiz", "test", "assess"],
        config_defaults={
            "num_questions": 5,
            "difficulty": "medium",
            "focus": "conceptual understanding",
        },
        request_schema=get_capability_request_schema("chat"),
    )

    async def run(self, context: UnifiedContext, stream: StreamBus) -> None:
        from deeptutor.services.llm import complete as llm_complete
        from deeptutor.services.llm.config import get_llm_config
        from deeptutor.services.model_router import get_model_router, Intent

        cfg_overrides = context.config_overrides or {}
        mode = cfg_overrides.get("mode", "generate")  # "generate" | "evaluate"

        router = get_model_router()
        hf_cfg = router.route(Intent.ASSESSMENT)
        llm_cfg = get_llm_config()

        api_key = hf_cfg.api_key or llm_cfg.api_key
        base_url = hf_cfg.api_base if hf_cfg.api_key else (llm_cfg.base_url or hf_cfg.api_base)
        model = hf_cfg.model if hf_cfg.api_key else llm_cfg.model

        async with stream.stage("designing", source=self.manifest.name):
            await stream.progress(
                f"Designing {'quiz' if mode == 'generate' else 'evaluation'}...",
                source=self.manifest.name,
            )

        async with stream.stage("generating", source=self.manifest.name):
            if mode == "generate":
                num_q = int(cfg_overrides.get("num_questions", 5))
                difficulty = cfg_overrides.get("difficulty", "medium")
                focus = cfg_overrides.get("focus", "conceptual understanding")
                prompt = _QUIZ_GENERATION_PROMPT.format(
                    num_questions=num_q,
                    topic=context.content,
                    difficulty=difficulty,
                    focus=focus,
                )
                raw = await llm_complete(
                    prompt=prompt,
                    system_prompt="You are an expert assessment designer. Always respond with valid JSON.",
                    model=model,
                    api_key=api_key,
                    base_url=base_url,
                    temperature=0.4,
                )
                parsed = _parse_json_block(raw)
                if parsed:
                    await stream.content(
                        f"**Assessment: {parsed.get('topic', context.content)}**\n\n"
                        f"*{num_q} questions · {difficulty} difficulty*\n\n```json\n{json.dumps(parsed, indent=2)}\n```",
                        source=self.manifest.name,
                    )
                    await stream.result(
                        {"quiz": parsed, "mode": "generate", "capability": "assessment"},
                        source=self.manifest.name,
                    )
                else:
                    await stream.content(raw, source=self.manifest.name)
                    await stream.result({"raw": raw, "mode": "generate"}, source=self.manifest.name)
            else:
                await stream.content(
                    "Evaluation mode: pass `question`, `correct`, `explanation`, and "
                    "`student_answer` via config_overrides.",
                    source=self.manifest.name,
                )
                await stream.result({"mode": "evaluate"}, source=self.manifest.name)
