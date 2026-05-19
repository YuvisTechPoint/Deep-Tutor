"""Curated Hugging Face model ids for the OSS AI Tutor stack.

``Qwen/Qwen3.5-35B-A3B`` is a native vision-language MoE model (image-text-to-text).
DeepTutor calls it through the HF OpenAI-compatible router when ``HF_TOKEN`` is set,
not via an in-process ``transformers`` pipeline (that path needs multi-GPU self-hosting).
"""

from __future__ import annotations

# Primary tutor + multimodal (chat images, vision solver, career, assessment).
HF_MAIN_VLM_MODEL = "Qwen/Qwen3.5-35B-A3B"

__all__ = ["HF_MAIN_VLM_MODEL"]
