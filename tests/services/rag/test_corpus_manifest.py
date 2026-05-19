"""Corpus manifest loading (no LangChain required)."""

from __future__ import annotations

import json
from pathlib import Path

import yaml

from deeptutor.services.rag.pipelines.langchain_corpus.corpus_loader import (
    corpus_root_from_kb_base,
    load_all_corpus_text_pairs,
    load_manifest_entries,
)


def test_corpus_root_from_kb_base(tmp_path: Path) -> None:
    kb_root = tmp_path / "data" / "knowledge_bases"
    kb_root.mkdir(parents=True)
    assert corpus_root_from_kb_base(kb_root) == (tmp_path / "data" / "corpora").resolve()


def test_load_manifest_and_jsonl(tmp_path: Path) -> None:
    corp = tmp_path / "data" / "corpora"
    bundles = corp / "bundles"
    bundles.mkdir(parents=True)
    rows = [
        {"text": "Alpha chunk about spaced repetition.", "topic": "learning"},
        {"text": "Beta chunk on active recall.", "topic": "learning"},
    ]
    (bundles / "sample.jsonl").write_text(
        "\n".join(json.dumps(r) for r in rows) + "\n",
        encoding="utf-8",
    )
    (corp / "manifest.yaml").write_text(
        yaml.safe_dump(
            {
                "version": 1,
                "datasets": [
                    {
                        "id": "sample_ds",
                        "description": "Test bundle",
                        "files": ["bundles/sample.jsonl"],
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    kb_base = tmp_path / "data" / "knowledge_bases"
    kb_base.mkdir(parents=True)
    entries = load_manifest_entries(kb_base)
    assert len(entries) == 1
    assert entries[0]["id"] == "sample_ds"
    pairs = load_all_corpus_text_pairs(kb_base)
    assert len(pairs) == 2
    assert "spaced repetition" in pairs[0][0]
