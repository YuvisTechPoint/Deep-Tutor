"""RAG pipeline factory — LlamaIndex (default) or optional LangChain + FAISS + corpora."""

from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

DEFAULT_PROVIDER = "llamaindex"

# Cached pipeline instances keyed by (provider_kind, kb_base_dir).
_PIPELINE_CACHE: Dict[tuple[str, Optional[str]], Any] = {}


def reset_pipeline_cache() -> None:
    """Clear cached pipeline instances (for tests or hot config reload)."""
    _PIPELINE_CACHE.clear()


def get_active_rag_provider() -> str:
    """Resolve active pipeline from ``RAG_PIPELINE`` / ``RAG_PROVIDER`` (default: llamaindex)."""
    raw = (os.environ.get("RAG_PIPELINE") or os.environ.get("RAG_PROVIDER") or "").strip().lower()
    if raw in ("langchain", "langchain_corpus", "lc"):
        return "langchain"
    if raw in ("lightrag", "raganything"):
        return DEFAULT_PROVIDER
    return DEFAULT_PROVIDER


def normalize_provider_name(name: Optional[str] = None) -> str:
    """Map legacy config strings to supported pipeline ids."""
    if not name:
        return DEFAULT_PROVIDER
    n = str(name).strip().lower()
    if n in ("langchain", "langchain_corpus", "lc"):
        return "langchain"
    return DEFAULT_PROVIDER


def get_pipeline(
    name: Optional[str] = None,
    kb_base_dir: Optional[str] = None,
    **kwargs: Any,
):
    """Return a cached RAG pipeline (LlamaIndex or LangChain + FAISS).

    When ``name`` is omitted, ``get_active_rag_provider()`` reads ``RAG_PIPELINE``.
    Pass ``name="llamaindex"`` explicitly to force LlamaIndex regardless of env.
    """
    kind = normalize_provider_name(name) if name is not None else get_active_rag_provider()
    cache_key = (kind, kb_base_dir)

    if kwargs:
        if kind == "langchain":
            from deeptutor.services.rag.pipelines.langchain_corpus.pipeline import (
                LangChainCorpusPipeline,
            )

            if kb_base_dir is not None:
                kwargs.setdefault("kb_base_dir", kb_base_dir)
            return LangChainCorpusPipeline(**kwargs)

        from deeptutor.services.rag.pipelines.llamaindex.pipeline import LlamaIndexPipeline

        if kb_base_dir is not None:
            kwargs.setdefault("kb_base_dir", kb_base_dir)
        return LlamaIndexPipeline(**kwargs)

    if cache_key not in _PIPELINE_CACHE:
        if kind == "langchain":
            from deeptutor.services.rag.pipelines.langchain_corpus.pipeline import (
                LangChainCorpusPipeline,
            )

            _PIPELINE_CACHE[cache_key] = LangChainCorpusPipeline(kb_base_dir=kb_base_dir)
        else:
            from deeptutor.services.rag.pipelines.llamaindex.pipeline import LlamaIndexPipeline

            _PIPELINE_CACHE[cache_key] = LlamaIndexPipeline(kb_base_dir=kb_base_dir)

    return _PIPELINE_CACHE[cache_key]


def list_pipelines() -> List[Dict[str, str]]:
    """Return built-in pipelines (LangChain row only if imports succeed)."""
    rows: List[Dict[str, str]] = [
        {
            "id": "llamaindex",
            "name": "LlamaIndex",
            "description": "Vector retrieval with LlamaIndex (default).",
        }
    ]
    try:
        import langchain_community.vectorstores  # noqa: F401
        import langchain_openai  # noqa: F401
    except ImportError:
        return rows
    rows.append(
        {
            "id": "langchain",
            "name": "LangChain + FAISS + corpora",
            "description": (
                "OpenAI-compatible embeddings, FAISS per KB, merged with ``data/corpora`` "
                "datasets (install ``deeptutor[rag-langchain]``, set RAG_PIPELINE=langchain)."
            ),
        }
    )
    return rows


__all__ = [
    "DEFAULT_PROVIDER",
    "get_active_rag_provider",
    "get_pipeline",
    "list_pipelines",
    "normalize_provider_name",
    "reset_pipeline_cache",
]
