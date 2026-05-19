"""Model router — open-source, self-hosted-first intent routing.

This router prefers local/self-hosted inference endpoints (vLLM/TGI/Ollama/
llama.cpp/FastAPI inference servers). Hugging Face hosted inference remains an
optional fallback when local endpoints are not configured.
"""

from __future__ import annotations

from dataclasses import dataclass
import os

from deeptutor.services.hf_openai_compat import (
    HF_OPENAI_COMPAT_ROUTER_BASE,
    hf_hub_token_from_env,
    normalize_hf_openai_compat_base_url,
)
from deeptutor.services.model_router.default_models import HF_MAIN_VLM_MODEL
from deeptutor.services.model_router.intent import Intent

_HF_BASE = HF_OPENAI_COMPAT_ROUTER_BASE

# Per-intent model env-var overrides
_INTENT_ENV: dict[Intent, str] = {
    Intent.CODING: "HF_MODEL_CODING",
    Intent.MATH: "HF_MODEL_MATH",
    Intent.VISION: "HF_MODEL_VISION",
    Intent.OCR: "HF_MODEL_OCR",
    Intent.SPEECH: "HF_MODEL_SPEECH",
    Intent.CAREER: "HF_MODEL_CAREER",
    Intent.ASSESSMENT: "HF_MODEL_ASSESSMENT",
    Intent.GENERAL: "HF_MODEL_GENERAL",
    Intent.SAFETY: "HF_MODEL_SAFETY",
}

# Per-feature-surface model env-var overrides. Feature overrides take
# precedence over intent-based defaults: e.g. the chat WebSocket should
# always honour ``HF_MODEL_CHAT`` even when the detected intent is GENERAL.
_FEATURE_ENV: dict[str, str] = {
    "chat": "HF_MODEL_CHAT",
    "tutorbot": "HF_MODEL_TUTORBOT",
    "roadmap": "HF_MODEL_ROADMAP",
    "co_writer": "HF_MODEL_COWRITER",
    "book": "HF_MODEL_BOOK",
    "knowledge": "HF_MODEL_KNOWLEDGE",
    "practice_coding": "HF_MODEL_PRACTICE_CODING",
    "practice_math": "HF_MODEL_PRACTICE_MATH",
    "practice_general": "HF_MODEL_PRACTICE_GENERAL",
    "missions": "HF_MODEL_MISSIONS",
    "career": "HF_MODEL_CAREER_SURFACE",
    "dashboard": "HF_MODEL_DASHBOARD",
    "vision_solver": "HF_MODEL_VISION_SOLVER",
}

# Default model per UI surface when no ``HF_MODEL_<FEATURE>`` env override is set.
_FEATURE_DEFAULT: dict[str, str] = {
    "chat": HF_MAIN_VLM_MODEL,
    "tutorbot": HF_MAIN_VLM_MODEL,
    "roadmap": HF_MAIN_VLM_MODEL,
    "co_writer": HF_MAIN_VLM_MODEL,
    "book": HF_MAIN_VLM_MODEL,
    "missions": HF_MAIN_VLM_MODEL,
    "dashboard": HF_MAIN_VLM_MODEL,
    "career": HF_MAIN_VLM_MODEL,
    "vision_solver": HF_MAIN_VLM_MODEL,
}

# Curated defaults from the OSS AI Tutor stack.
_INTENT_DEFAULT: dict[Intent, str] = {
    Intent.CODING: "deepseek-ai/DeepSeek-Coder-V2-Instruct",
    Intent.MATH: "deepseek-ai/deepseek-math-7b-instruct",
    Intent.VISION: HF_MAIN_VLM_MODEL,
    Intent.OCR: "naver-clova-ix/donut-base",
    Intent.SPEECH: "openai/whisper-large-v3",
    Intent.CAREER: HF_MAIN_VLM_MODEL,
    Intent.ASSESSMENT: HF_MAIN_VLM_MODEL,
    Intent.GENERAL: HF_MAIN_VLM_MODEL,
    Intent.SAFETY: "meta-llama/Llama-Guard-3-8B",
}

# Auxiliary roles outside the Intent enum — surfaced via the catalog only.
AUX_ROLE_DEFAULTS: dict[str, dict[str, str]] = {
    "embeddings_en": {
        "model": "BAAI/bge-large-en-v1.5",
        "description": "BGE-large EN — English RAG embeddings",
        "env": "HF_MODEL_EMBEDDINGS_EN",
    },
    "embeddings_multilingual": {
        "model": "intfloat/multilingual-e5-large",
        "description": "E5-large — Multilingual RAG embeddings",
        "env": "HF_MODEL_EMBEDDINGS_MULTILINGUAL",
    },
    "reranker": {
        "model": "BAAI/bge-reranker-large",
        "description": "BGE reranker — top-k re-ranking",
        "env": "HF_MODEL_RERANKER",
    },
    "tts": {
        "model": "coqui/XTTS-v2",
        "description": "XTTS-v2 — Tutor speech output",
        "env": "HF_MODEL_TTS",
    },
    "ocr_printed": {
        "model": "microsoft/trocr-large-printed",
        "description": "TrOCR-large-printed — Scanned text OCR",
        "env": "HF_MODEL_OCR_PRINTED",
    },
    "fallback_mobile": {
        "model": "microsoft/Phi-3-mini-4k-instruct",
        "description": "Phi-3-mini — Low-bandwidth fallback",
        "env": "HF_MODEL_FALLBACK",
    },
}

# Maps each UI surface to the canonical model roles it relies on. Consumed by
# ``/api/v1/model-routing/feature-surfaces`` so the frontend can show users
# which open-source model powers a given page.
FEATURE_SURFACE_ROLES: dict[str, dict[str, object]] = {
    "chat": {"primary": "general", "supporting": ["safety", "embeddings_en", "reranker"]},
    "tutorbot": {"primary": "general", "supporting": ["safety", "embeddings_en", "reranker"]},
    "co_writer": {"primary": "general", "supporting": ["safety"]},
    "book": {"primary": "general", "supporting": ["vision", "embeddings_en", "reranker"]},
    "knowledge": {
        "primary": "general",
        "supporting": ["embeddings_en", "embeddings_multilingual", "reranker"],
    },
    "space": {"primary": "general", "supporting": []},
    "roadmap": {"primary": "general", "supporting": ["career"]},
    "onboarding": {"primary": "general", "supporting": []},
    "eip": {"primary": "general", "supporting": []},
    "practice_coding": {"primary": "coding", "supporting": ["safety"]},
    "practice_math": {"primary": "math", "supporting": ["safety"]},
    "practice_general": {"primary": "general", "supporting": ["safety"]},
    "missions": {"primary": "general", "supporting": ["math", "coding"]},
    "dashboard": {"primary": "general", "supporting": ["career"]},
    "career": {"primary": "career", "supporting": ["embeddings_en"]},
    "achievements": {"primary": "general", "supporting": []},
    "analytics": {"primary": "general", "supporting": []},
    "notifications": {"primary": "general", "supporting": []},
    "vision_solver": {"primary": "vision", "supporting": ["ocr"]},
    "voice": {"primary": "speech", "supporting": ["tts"], "disabled_when_role_missing": True},
}

MODEL_DESCRIPTIONS: dict[str, str] = {
    HF_MAIN_VLM_MODEL: "Qwen3.5-35B-A3B - Main tutor (text + vision)",
    "Qwen/Qwen2.5-32B-Instruct": "Qwen2.5-32B-Instruct - Main tutor (legacy)",
    "mistralai/Mixtral-8x7B-Instruct-v0.1": "Mixtral-8x7B-Instruct - Tutor fallback",
    "deepseek-ai/DeepSeek-Coder-V2-Instruct": "DeepSeek-Coder-V2 - Coding mentor",
    "bigcode/starcoder2-15b": "StarCoder2-15B - Coding fallback",
    "deepseek-ai/deepseek-math-7b-instruct": "DeepSeek-Math-7B - Math reasoning",
    "Qwen/Qwen2.5-VL-7B-Instruct": "Qwen2.5-VL-7B - Vision tutoring",
    "llava-hf/llava-1.5-13b-hf": "LLaVA-1.5-13B - Vision fallback",
    "microsoft/trocr-large-printed": "TrOCR-large-printed - OCR",
    "naver-clova-ix/donut-base": "Donut-base - Document understanding",
    "openai/whisper-large-v3": "Whisper large-v3 - Speech-to-text",
    "coqui/XTTS-v2": "XTTS-v2 - Text-to-speech",
    "BAAI/bge-large-en-v1.5": "BGE-large - Embeddings",
    "intfloat/multilingual-e5-large": "E5-large - Multilingual embeddings",
    "BAAI/bge-reranker-large": "BGE-reranker-large - Reranking",
    "microsoft/Phi-3-mini-4k-instruct": "Phi-3-mini - Edge fallback",
    "meta-llama/Llama-Guard-3-8B": "Llama Guard 3 - Safety",
}


@dataclass
class RoutedModelConfig:
    model: str
    api_base: str
    api_key: str
    intent: Intent
    description: str
    backend: str = "huggingface"
    self_hosted: bool = False


class ModelRouter:
    """Routes an intent to a model config ready for OpenAI-compat calls."""

    def __init__(self) -> None:
        self._token = hf_hub_token_from_env()
        raw_hf = (os.environ.get("HF_INFERENCE_BASE_URL") or "").strip()
        self._base = (
            normalize_hf_openai_compat_base_url(raw_hf) if raw_hf else _HF_BASE
        ).rstrip("/")
        self._self_hosted_only = str(os.environ.get("SELF_HOSTED_ONLY", "")).strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }

    def _local_endpoint_for(self, intent: Intent) -> tuple[str, str, str, bool]:
        """Resolve self-hosted endpoint in priority order."""
        intent_prefix = intent.value.upper()
        specific_base = os.environ.get(f"ROUTER_{intent_prefix}_BASE_URL", "").strip()
        if specific_base:
            return (
                specific_base.rstrip("/"),
                os.environ.get(f"ROUTER_{intent_prefix}_API_KEY", "sk-no-key-required").strip(),
                os.environ.get(f"ROUTER_{intent_prefix}_BACKEND", "custom").strip() or "custom",
                True,
            )

        backend_order: list[tuple[str, str, str]] = [
            ("vllm", "VLLM_BASE_URL", "VLLM_API_KEY"),
            ("tgi", "TGI_BASE_URL", "TGI_API_KEY"),
            ("ollama", "OLLAMA_BASE_URL", "OLLAMA_API_KEY"),
            ("llama.cpp", "LLAMACPP_BASE_URL", "LLAMACPP_API_KEY"),
            ("fastapi", "FASTAPI_INFERENCE_BASE_URL", "FASTAPI_INFERENCE_API_KEY"),
        ]
        for backend, base_env, key_env in backend_order:
            base = os.environ.get(base_env, "").strip()
            if not base:
                continue
            key = os.environ.get(key_env, "").strip() or "sk-no-key-required"
            return base.rstrip("/"), key, backend, True

        if not self._self_hosted_only:
            return self._base, self._token, "huggingface", False
        return "http://localhost:8000/v1", "sk-no-key-required", "vllm", True

    def route(self, intent: Intent) -> RoutedModelConfig:
        env_key = _INTENT_ENV.get(intent, "")
        model = (os.environ.get(env_key) or "").strip() if env_key else ""
        if not model:
            model = _INTENT_DEFAULT.get(intent, _INTENT_DEFAULT[Intent.GENERAL])
        api_base, api_key, backend, is_self_hosted = self._local_endpoint_for(intent)

        return RoutedModelConfig(
            model=model,
            api_base=api_base,
            api_key=api_key,
            intent=intent,
            description=MODEL_DESCRIPTIONS.get(model, model),
            backend=backend,
            self_hosted=is_self_hosted,
        )

    def route_feature(
        self,
        feature: str,
        intent: Intent | None = None,
    ) -> RoutedModelConfig:
        """Route for a named feature surface (e.g. ``"chat"``, ``"tutorbot"``).

        Resolution order:
          1. Explicit per-feature env override (``HF_MODEL_<FEATURE>``).
          2. Per-intent override / default returned by :meth:`route`.
          3. ``HF_MODEL_GENERAL`` / curated general default.

        ``api_base`` and ``api_key`` are inherited from the resolved intent's
        endpoint so the feature override only swaps the **model id**, never the
        upstream provider.
        """
        resolved_intent = intent or Intent.GENERAL
        intent_routed = self.route(resolved_intent)

        feature_key = feature.strip().lower()
        env_key = _FEATURE_ENV.get(feature_key, "")
        override = (os.environ.get(env_key) or "").strip() if env_key else ""
        if not override:
            override = _FEATURE_DEFAULT.get(feature_key, "").strip()
        if not override:
            return intent_routed

        return RoutedModelConfig(
            model=override,
            api_base=intent_routed.api_base,
            api_key=intent_routed.api_key,
            intent=intent_routed.intent,
            description=MODEL_DESCRIPTIONS.get(override, override),
            backend=intent_routed.backend,
            self_hosted=intent_routed.self_hosted,
        )

    def model_for_feature(self, feature: str) -> str | None:
        """Return the configured model id for a surface, or ``None`` if unset."""
        feature_key = feature.strip().lower()
        env_key = _FEATURE_ENV.get(feature_key, "")
        if env_key:
            override = (os.environ.get(env_key) or "").strip()
            if override:
                return override
        default = _FEATURE_DEFAULT.get(feature_key, "").strip()
        return default or None

    def all_routes(self) -> list[dict]:
        """Return metadata for all intent→model mappings (used in admin UI)."""
        routes: list[dict] = []
        for intent in Intent:
            routed = self.route(intent)
            routes.append(
                {
                    "intent": intent.value,
                    "model": routed.model,
                    "description": routed.description,
                    "env_override": _INTENT_ENV.get(intent, ""),
                    "backend": routed.backend,
                    "self_hosted": routed.self_hosted,
                    "api_base": routed.api_base,
                }
            )
        return routes

    def catalog(self) -> list[dict]:
        """Return the *full* model catalog: intent roles + auxiliary roles.

        Auxiliary roles cover RAG embeddings, reranker, TTS, OCR, and the
        low-latency fallback model. The frontend can render these alongside
        the primary intent routes so admins / learners see every model role.
        """

        rows: list[dict] = list(self.all_routes())
        for role, info in AUX_ROLE_DEFAULTS.items():
            env_val = os.environ.get(info["env"], "").strip()
            model = env_val or info["model"]
            rows.append(
                {
                    "intent": role,
                    "model": model,
                    "description": info["description"],
                    "env_override": info["env"],
                    "backend": "huggingface",
                    "self_hosted": False,
                    "api_base": self._base,
                    "auxiliary": True,
                }
            )
        return rows

    def feature_surfaces(self) -> list[dict]:
        """Return the surface → model-role mapping for the frontend."""
        rows: list[dict] = []
        for surface, spec in FEATURE_SURFACE_ROLES.items():
            primary = spec.get("primary")
            supporting = list(spec.get("supporting") or [])
            disabled = bool(spec.get("disabled_when_role_missing"))
            primary_model: str | None = None
            if isinstance(primary, str):
                if primary in {i.value for i in Intent}:
                    primary_model = self.route(Intent(primary)).model
                elif primary in AUX_ROLE_DEFAULTS:
                    info = AUX_ROLE_DEFAULTS[primary]
                    primary_model = os.environ.get(info["env"], "").strip() or info["model"]
            # A per-feature env override always wins over the role default so
            # surfaces like /chat, /roadmap, and /tutorbot can ship with a
            # bespoke open-source model.
            feature_override = self.model_for_feature(surface)
            if feature_override:
                primary_model = feature_override
            supporting_models = []
            for role in supporting:
                if role in {i.value for i in Intent}:
                    supporting_models.append(
                        {"role": role, "model": self.route(Intent(role)).model}
                    )
                elif role in AUX_ROLE_DEFAULTS:
                    info = AUX_ROLE_DEFAULTS[role]
                    supporting_models.append(
                        {
                            "role": role,
                            "model": os.environ.get(info["env"], "").strip() or info["model"],
                        }
                    )
            rows.append(
                {
                    "surface": surface,
                    "primary_role": primary,
                    "primary_model": primary_model,
                    "supporting": supporting_models,
                    "disabled_when_role_missing": disabled,
                }
            )
        return rows

    def safety_config(self) -> RoutedModelConfig:
        return self.route(Intent.SAFETY)

    def vl_config(self) -> RoutedModelConfig:
        """Vision-language model for image understanding."""
        env = os.environ.get("HF_MODEL_VL", "").strip()
        model = env or HF_MAIN_VLM_MODEL
        api_base, api_key, backend, is_self_hosted = self._local_endpoint_for(Intent.VISION)
        return RoutedModelConfig(
            model=model,
            api_base=api_base,
            api_key=api_key,
            intent=Intent.VISION,
            description=MODEL_DESCRIPTIONS.get(model, model),
            backend=backend,
            self_hosted=is_self_hosted,
        )


_router_instance: ModelRouter | None = None


def get_model_router() -> ModelRouter:
    global _router_instance
    if _router_instance is None:
        _router_instance = ModelRouter()
    return _router_instance
