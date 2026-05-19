"""LangChain + FAISS retrieval merged with optional curated corpora."""

from __future__ import annotations

import asyncio
import logging
import os
from pathlib import Path
import shutil
import traceback
from typing import Any, List, Optional

from deeptutor.services.embedding import get_embedding_config
from deeptutor.services.rag.pipelines.langchain_corpus.corpus_loader import (
    corpus_root_from_kb_base,
    load_all_corpus_text_pairs,
)

logger = logging.getLogger(__name__)

_LANGCHAIN_IMPORT_ERROR: str | None = None


def _check_langchain() -> None:
    global _LANGCHAIN_IMPORT_ERROR
    if _LANGCHAIN_IMPORT_ERROR is not None:
        raise RuntimeError(_LANGCHAIN_IMPORT_ERROR)
    try:
        from langchain_community.vectorstores import FAISS  # noqa: F401
        from langchain_openai import OpenAIEmbeddings  # noqa: F401
        from langchain_text_splitters import RecursiveCharacterTextSplitter  # noqa: F401
    except ImportError as exc:
        _LANGCHAIN_IMPORT_ERROR = (
            "LangChain RAG extras are not installed. Install with: "
            "pip install 'deeptutor[rag-langchain]'"
        )
        raise RuntimeError(_LANGCHAIN_IMPORT_ERROR) from exc


def _make_embeddings():
    from langchain_openai import OpenAIEmbeddings

    cfg = get_embedding_config()
    kwargs: dict[str, Any] = {"model": cfg.model, "api_key": cfg.api_key or ""}
    if cfg.effective_url:
        kwargs["openai_api_base"] = str(cfg.effective_url).rstrip("/")
    if cfg.extra_headers:
        kwargs["default_headers"] = dict(cfg.extra_headers)
    return OpenAIEmbeddings(**kwargs)


def _kb_lc_dir(kb_base_dir: str, kb_name: str) -> Path:
    return Path(kb_base_dir) / kb_name / "_langchain_faiss"


def _corpus_index_dir(kb_base_dir: str) -> Path:
    return corpus_root_from_kb_base(kb_base_dir) / ".langchain_faiss"


def _paths_to_texts(file_paths: List[str]) -> list[tuple[str, dict[str, Any]]]:
    out: list[tuple[str, dict[str, Any]]] = []
    for fp in file_paths:
        path = Path(fp)
        if not path.is_file():
            continue
        suf = path.suffix.lower()
        if suf in {".txt", ".md"}:
            text = path.read_text(encoding="utf-8", errors="replace").strip()
            if text:
                out.append((text, {"file_path": str(path), "file_name": path.name}))
        elif suf == ".jsonl":
            for i, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines()):
                line = line.strip()
                if not line:
                    continue
                try:
                    import json

                    row = json.loads(line)
                except Exception:
                    continue
                if isinstance(row, dict):
                    t = str(row.get("text") or row.get("content") or "").strip()
                    if t:
                        out.append((t, {"file_path": str(path), "file_name": path.name, "line": i}))
    return out


def _build_faiss_from_texts(
    texts_meta: list[tuple[str, dict[str, Any]]],
    embeddings,
    *,
    chunk_size: int,
    chunk_overlap: int,
):
    from langchain_community.vectorstores import FAISS
    from langchain_core.documents import Document
    from langchain_text_splitters import RecursiveCharacterTextSplitter

    splitter = RecursiveCharacterTextSplitter(
        chunk_size=chunk_size,
        chunk_overlap=chunk_overlap,
        length_function=len,
    )
    docs: list[Any] = []
    for text, meta in texts_meta:
        for chunk in splitter.split_text(text):
            if chunk.strip():
                docs.append(Document(page_content=chunk.strip(), metadata=dict(meta)))
    if not docs:
        return None
    return FAISS.from_documents(docs, embeddings)


def _merge_results(
    query: str,
    kb_store: Any | None,
    corpus_store: Any | None,
    *,
    kb_k: int,
    corpus_k: int,
) -> tuple[str, list[dict[str, Any]]]:
    parts: list[str] = []
    sources: list[dict[str, Any]] = []
    seen: set[str] = set()

    def add_docs(docs: list[Any], *, origin: str) -> None:
        for i, doc in enumerate(docs):
            key = (doc.page_content[:120] + origin).strip()
            if key in seen:
                continue
            seen.add(key)
            parts.append(doc.page_content)
            meta = dict(doc.metadata or {})
            sources.append(
                {
                    "title": meta.get("title") or meta.get("file_name") or meta.get("corpus_id") or origin,
                    "content": doc.page_content[:240],
                    "source": meta.get("file_path") or meta.get("source_file") or origin,
                    "chunk_id": f"{origin}-{i}",
                    "origin": origin,
                    "corpus_id": meta.get("corpus_id", ""),
                }
            )

    if kb_store is not None:
        try:
            kb_docs = kb_store.similarity_search(query, k=kb_k)
            add_docs(kb_docs, origin="kb")
        except Exception as exc:
            logger.warning("KB similarity search failed: %s", exc)
    if corpus_store is not None:
        try:
            c_docs = corpus_store.similarity_search(query, k=corpus_k)
            add_docs(c_docs, origin="corpus")
        except Exception as exc:
            logger.warning("Corpus similarity search failed: %s", exc)

    content = "\n\n".join(parts) if parts else ""
    return content, sources


class LangChainCorpusPipeline:
    """FAISS + OpenAI-compatible embeddings; merges ``data/corpora`` datasets on every query."""

    def __init__(self, kb_base_dir: Optional[str] = None, *, chunk_size: int = 900, chunk_overlap: int = 120):
        self.logger = logger
        self.kb_base_dir = kb_base_dir or str(
            Path(__file__).resolve().parents[5] / "data" / "knowledge_bases"
        )
        self.chunk_size = int(os.environ.get("RAG_LC_CHUNK_SIZE", chunk_size))
        self.chunk_overlap = int(os.environ.get("RAG_LC_CHUNK_OVERLAP", chunk_overlap))
        self._corpus_k = max(1, int(os.environ.get("RAG_CORPUS_TOP_K", "3")))
        self._kb_k = max(1, int(os.environ.get("RAG_KB_TOP_K", "5")))

    def _extra_manifests(self) -> list[Path]:
        raw = os.environ.get("RAG_CORPUS_MANIFEST", "").strip()
        if not raw:
            return []
        return [Path(p.strip()).expanduser() for p in raw.split(";") if p.strip()]

    async def initialize(self, kb_name: str, file_paths: List[str], **kwargs) -> bool:
        _check_langchain()
        self.logger.info("LangChainCorpus: initializing KB '%s' (%d files)", kb_name, len(file_paths))
        texts = _paths_to_texts(list(file_paths))
        if not texts:
            self.logger.error("No ingestible text for LangChain pipeline")
            return False
        target = _kb_lc_dir(self.kb_base_dir, kb_name)

        def _run():
            embeddings = _make_embeddings()
            vs = _build_faiss_from_texts(
                texts,
                embeddings,
                chunk_size=self.chunk_size,
                chunk_overlap=self.chunk_overlap,
            )
            if vs is None:
                return False
            if target.exists():
                shutil.rmtree(target)
            target.mkdir(parents=True, exist_ok=True)
            vs.save_local(str(target))
            return True

        try:
            return await asyncio.to_thread(_run)
        except Exception as exc:
            self.logger.error("LangChainCorpus initialize failed: %s", exc)
            self.logger.error(traceback.format_exc())
            return False

    async def add_documents(self, kb_name: str, file_paths: List[str], **kwargs) -> bool:
        """Append chunks to an existing FAISS index when possible; otherwise rebuild."""
        _check_langchain()
        kb_dir = Path(self.kb_base_dir) / kb_name
        lc_dir = _kb_lc_dir(self.kb_base_dir, kb_name)
        new_texts = _paths_to_texts([str(Path(x)) for x in file_paths])
        if not new_texts:
            self.logger.warning("LangChainCorpus add_documents: no text extracted from new files")
            return False

        def _run():
            embeddings = _make_embeddings()
            from langchain_community.vectorstores import FAISS

            new_vs = _build_faiss_from_texts(
                new_texts,
                embeddings,
                chunk_size=self.chunk_size,
                chunk_overlap=self.chunk_overlap,
            )
            if new_vs is None:
                return False
            if lc_dir.exists() and any(lc_dir.iterdir()):
                base = FAISS.load_local(
                    str(lc_dir),
                    embeddings,
                    allow_dangerous_deserialization=True,
                )
                base.merge_from(new_vs)
                shutil.rmtree(lc_dir)
                lc_dir.mkdir(parents=True, exist_ok=True)
                base.save_local(str(lc_dir))
            else:
                kb_dir.mkdir(parents=True, exist_ok=True)
                if lc_dir.exists():
                    shutil.rmtree(lc_dir)
                lc_dir.mkdir(parents=True, exist_ok=True)
                new_vs.save_local(str(lc_dir))
            return True

        try:
            return await asyncio.to_thread(_run)
        except Exception as exc:
            self.logger.error("LangChainCorpus add_documents failed: %s", exc)
            self.logger.error(traceback.format_exc())
            return False

    async def search(self, query: str, kb_name: str, **kwargs) -> dict[str, Any]:
        _check_langchain()
        kwargs.pop("mode", None)
        top_k = int(kwargs.get("top_k", self._kb_k))

        kb_dir = _kb_lc_dir(self.kb_base_dir, kb_name)
        corpus_dir = _corpus_index_dir(self.kb_base_dir)

        def _run_search():
            embeddings = _make_embeddings()
            from langchain_community.vectorstores import FAISS

            kb_store = None
            if kb_dir.exists() and any(kb_dir.iterdir()):
                try:
                    kb_store = FAISS.load_local(
                        str(kb_dir),
                        embeddings,
                        allow_dangerous_deserialization=True,
                    )
                except Exception as exc:
                    self.logger.warning("Could not load KB FAISS (%s): %s", kb_name, exc)

            corpus_store = None
            pairs = load_all_corpus_text_pairs(
                self.kb_base_dir,
                extra_manifest_paths=self._extra_manifests() or None,
            )
            if pairs:
                if corpus_dir.exists():
                    try:
                        corpus_store = FAISS.load_local(
                            str(corpus_dir),
                            embeddings,
                            allow_dangerous_deserialization=True,
                        )
                    except Exception:
                        corpus_store = None
                if corpus_store is None:
                    built = _build_faiss_from_texts(
                        pairs,
                        embeddings,
                        chunk_size=self.chunk_size,
                        chunk_overlap=self.chunk_overlap,
                    )
                    if built is not None:
                        corpus_dir.parent.mkdir(parents=True, exist_ok=True)
                        if corpus_dir.exists():
                            shutil.rmtree(corpus_dir)
                        built.save_local(str(corpus_dir))
                        corpus_store = built

            content, sources = _merge_results(
                query,
                kb_store,
                corpus_store,
                kb_k=top_k,
                corpus_k=self._corpus_k,
            )
            return content, sources

        try:
            content, sources = await asyncio.to_thread(_run_search)
        except Exception as exc:
            return {
                "query": query,
                "answer": f"LangChain RAG search failed: {exc}",
                "content": "",
                "sources": [],
                "provider": "langchain",
                "error": str(exc),
            }

        if not content.strip():
            return {
                "query": query,
                "answer": (
                    "No LangChain index found for this knowledge base and no corpus passages "
                    "matched. Add documents to the KB or extend ``data/corpora/manifest.yaml``."
                ),
                "content": "",
                "sources": [],
                "provider": "langchain",
                "needs_reindex": kb_dir.exists() is False,
            }

        return {
            "query": query,
            "answer": content,
            "content": content,
            "sources": sources,
            "provider": "langchain",
        }

    async def delete(self, kb_name: str) -> bool:
        target = _kb_lc_dir(self.kb_base_dir, kb_name)
        if target.exists():
            shutil.rmtree(target)
            return True
        return False
