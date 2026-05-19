"""Tests for TutorBot tool-call name/argument normalization."""

from deeptutor.tutorbot.providers.tool_call_utils import normalize_tool_invocation


def test_normalize_embedded_python_dict_in_name():
    name = "rag{'kb_name': 'cyber-law', 'mode': 'naive', 'query': 'cyber law and ethics definition'}"
    n, args = normalize_tool_invocation(name, {})
    assert n == "rag"
    assert args["kb_name"] == "cyber-law"
    assert args["mode"] == "naive"
    assert "cyber law" in args["query"]


def test_normalize_wrapped_function_tag():
    raw = "<function-rag{'query': 'x'}>"
    n, args = normalize_tool_invocation(raw, {})
    assert n == "rag"
    assert args["query"] == "x"


def test_normalize_preserves_valid_name():
    n, args = normalize_tool_invocation("web_search", {"query": "test"})
    assert n == "web_search"
    assert args == {"query": "test"}


def test_normalize_merges_existing_arguments():
    n, args = normalize_tool_invocation("rag{'query': 'b'}", {"kb_name": "k"})
    assert n == "rag"
    assert args["kb_name"] == "k"
    assert args["query"] == "b"
