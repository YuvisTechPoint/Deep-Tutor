"""Load curated corpus datasets declared in ``data/corpora/manifest.yaml``."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

import yaml

logger = logging.getLogger(__name__)

DEFAULT_MANIFEST = (
    Path(__file__).resolve().parent.parent.parent.parent.parent.parent
    / "data"
    / "corpora"
    / "manifest.yaml"
)


def corpus_root_from_kb_base(kb_base_dir: str | Path) -> Path:
    """``data/knowledge_bases`` → ``data/corpora``."""
    base = Path(kb_base_dir).resolve()
    return (base.parent / "corpora").resolve()


def load_manifest_entries(
    kb_base_dir: str | Path,
    *,
    extra_manifest_paths: list[Path] | None = None,
) -> list[dict[str, Any]]:
    """Return dataset entries from the primary manifest plus optional extras."""
    roots = [corpus_root_from_kb_base(kb_base_dir)]
    entries: list[dict[str, Any]] = []
    paths: list[Path] = []
    primary = roots[0] / "manifest.yaml"
    if primary.exists():
        paths.append(primary)
    if extra_manifest_paths:
        paths.extend(extra_manifest_paths)
    for manifest_path in paths:
        try:
            raw = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
        except Exception as exc:
            logger.warning("Could not read corpus manifest %s: %s", manifest_path, exc)
            continue
        if not isinstance(raw, dict):
            continue
        for row in raw.get("datasets") or []:
            if isinstance(row, dict) and row.get("id") and row.get("files"):
                entries.append(
                    {
                        "id": str(row["id"]),
                        "description": str(row.get("description") or ""),
                        "files": [str(f) for f in row.get("files") or []],
                        "_root": manifest_path.parent,
                    }
                )
    return entries


def iter_documents_for_entry(entry: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    """Yield (page_content, metadata) pairs for one manifest dataset."""
    root: Path = entry["_root"]
    did = entry["id"]
    out: list[tuple[str, dict[str, Any]]] = []
    for rel in entry["files"]:
        path = (root / rel).resolve()
        if not path.is_file():
            logger.debug("Corpus file missing: %s", path)
            continue
        suffix = path.suffix.lower()
        if suffix == ".jsonl":
            for i, line in enumerate(path.read_text(encoding="utf-8").splitlines()):
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(row, str):
                    text = row.strip()
                    meta: dict[str, Any] = {"corpus_id": did, "source_file": rel, "line": i}
                elif isinstance(row, dict):
                    text = str(
                        row.get("text")
                        or row.get("content")
                        or row.get("body")
                        or row.get("passage")
                        or ""
                    ).strip()
                    meta = {
                        "corpus_id": did,
                        "source_file": rel,
                        "line": i,
                        **{k: v for k, v in row.items() if k not in ("text", "content", "body", "passage")},
                    }
                else:
                    continue
                if text:
                    out.append((text, meta))
        elif suffix in {".txt", ".md"}:
            text = path.read_text(encoding="utf-8", errors="replace").strip()
            if text:
                out.append(
                    (
                        text,
                        {"corpus_id": did, "source_file": rel, "title": path.stem},
                    )
                )
    return out


def load_all_corpus_text_pairs(
    kb_base_dir: str | Path,
    *,
    extra_manifest_paths: list[Path] | None = None,
) -> list[tuple[str, dict[str, Any]]]:
    pairs: list[tuple[str, dict[str, Any]]] = []
    for entry in load_manifest_entries(kb_base_dir, extra_manifest_paths=extra_manifest_paths):
        pairs.extend(iter_documents_for_entry(entry))
    return pairs
