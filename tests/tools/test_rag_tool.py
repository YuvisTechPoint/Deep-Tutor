"""Factory + tool-wrapper layer tests (LlamaIndex default, optional LangChain)."""

from __future__ import annotations

import pytest

from deeptutor.services.rag.factory import (
    DEFAULT_PROVIDER,
    get_active_rag_provider,
    get_pipeline,
    list_pipelines,
    normalize_provider_name,
    reset_pipeline_cache,
)
from deeptutor.tools.rag_tool import (
    RAGService,
    _resolve_kb_name,
    get_available_providers,
    get_current_provider,
)


class TestNormalizeProviderName:
    @pytest.mark.parametrize(
        "value,expected",
        [
            (None, DEFAULT_PROVIDER),
            ("", DEFAULT_PROVIDER),
            ("  ", DEFAULT_PROVIDER),
            ("llamaindex", DEFAULT_PROVIDER),
            ("LlamaIndex", DEFAULT_PROVIDER),
            ("lightrag", DEFAULT_PROVIDER),
            ("langchain", "langchain"),
            ("LC", "langchain"),
            ("totally_unknown_xyz", DEFAULT_PROVIDER),
        ],
    )
    def test_mapping(self, value, expected) -> None:
        assert normalize_provider_name(value) == expected


class TestPipelineFactory:
    def test_list_pipelines_includes_default(self) -> None:
        pipelines = list_pipelines()
        assert isinstance(pipelines, list)
        ids = {p["id"] for p in pipelines}
        assert DEFAULT_PROVIDER in ids
        assert ids.issubset({DEFAULT_PROVIDER, "langchain"})

    def test_get_pipeline_returns_singleton(self) -> None:
        reset_pipeline_cache()
        try:
            first = get_pipeline()
            second = get_pipeline()
        except (ValueError, ImportError) as exc:
            pytest.skip(f"LlamaIndex optional dependency missing: {exc}")
        assert first is second

    def test_get_pipeline_same_for_legacy_aliases(self) -> None:
        reset_pipeline_cache()
        try:
            a = get_pipeline("llamaindex")
            b = get_pipeline("lightrag")
            c = get_pipeline("nonexistent_xyz")
        except (ValueError, ImportError) as exc:
            pytest.skip(f"LlamaIndex optional dependency missing: {exc}")
        assert a is b is c


class TestRAGServiceClassHelpers:
    def test_list_providers_includes_default(self) -> None:
        providers = RAGService.list_providers()
        ids = {p["id"] for p in providers}
        assert DEFAULT_PROVIDER in ids

    def test_has_provider_default_true(self) -> None:
        assert RAGService.has_provider(DEFAULT_PROVIDER) is True

    def test_has_provider_langchain_when_installed(self) -> None:
        try:
            import langchain_openai  # noqa: F401
        except ImportError:
            assert RAGService.has_provider("langchain") is False
        else:
            assert RAGService.has_provider("langchain") is True

    def test_has_provider_unknown_false(self) -> None:
        assert RAGService.has_provider("nonexistent") is False
        assert RAGService.has_provider("") is False

    def test_get_current_provider_reads_env(self, monkeypatch: pytest.MonkeyPatch) -> None:
        reset_pipeline_cache()
        monkeypatch.delenv("RAG_PIPELINE", raising=False)
        monkeypatch.delenv("RAG_PROVIDER", raising=False)
        assert get_current_provider() == DEFAULT_PROVIDER
        monkeypatch.setenv("RAG_PIPELINE", "langchain")
        assert get_active_rag_provider() == "langchain"
        assert RAGService.get_current_provider() == "langchain"


class TestToolLayerExports:
    def test_get_available_providers_matches_class_method(self) -> None:
        assert get_available_providers() == RAGService.list_providers()

    def test_resolve_default_alias_to_configured_default(self, tmp_path) -> None:
        from deeptutor.knowledge.manager import KnowledgeBaseManager

        base_dir = tmp_path / "knowledge_bases"
        manager = KnowledgeBaseManager(base_dir=str(base_dir))
        manager.config["knowledge_bases"]["actual-kb"] = {
            "path": "actual-kb",
            "status": "ready",
        }
        manager._save_config()

        assert _resolve_kb_name("default", kb_base_dir=str(base_dir)) == "actual-kb"

    def test_resolve_exact_kb_named_default_before_alias(self, tmp_path) -> None:
        from deeptutor.knowledge.manager import KnowledgeBaseManager

        base_dir = tmp_path / "knowledge_bases"
        manager = KnowledgeBaseManager(base_dir=str(base_dir))
        manager.config["knowledge_bases"] = {
            "default": {"path": "default", "status": "ready"},
            "z-kb": {"path": "z-kb", "status": "ready"},
        }
        manager._save_config()

        assert _resolve_kb_name("default", kb_base_dir=str(base_dir)) == "default"
