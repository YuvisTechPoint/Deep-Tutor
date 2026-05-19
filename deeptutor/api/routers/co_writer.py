import asyncio
from dataclasses import asdict
from datetime import datetime
from html import escape as html_escape
from io import BytesIO
import json
import logging
import os
import re
import traceback
from typing import AsyncGenerator, Literal
import uuid

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response, StreamingResponse
from pydantic import BaseModel

from deeptutor.agents.chat.agentic_pipeline import AgenticChatPipeline
from deeptutor.co_writer.edit_agent import (
    EditAgent,
    load_history,
    local_fallback_edit,
    looks_like_llm_error,
    print_stats,
    save_history,
    save_tool_call,
    tool_calls_dir,
)
from deeptutor.co_writer.storage import (
    CoWriterDocument,
    CoWriterDocumentSummary,
    get_co_writer_storage,
)
from deeptutor.core.context import UnifiedContext
from deeptutor.core.stream_bus import StreamBus
from deeptutor.services.config import PROJECT_ROOT, load_config_with_main
from deeptutor.services.llm import clean_thinking_tags
from deeptutor.services.settings.interface_settings import get_ui_language

router = APIRouter()

# Initialize logger with config
config = load_config_with_main("main.yaml", PROJECT_ROOT)
log_dir = config.get("paths", {}).get("user_log_dir") or config.get("logging", {}).get("log_dir")
logger = logging.getLogger(__name__)

_edit_agent: EditAgent | None = None


def _current_language() -> str:
    # Prefer UI settings, fall back to main.yaml system.language
    return get_ui_language(default=config.get("system", {}).get("language", "en"))


def get_edit_agent() -> EditAgent:
    """
    Get the singleton EditAgent instance with refreshed configuration.

    Uses a singleton pattern with refresh_config() to ensure:
    1. Efficient reuse of the agent instance
    2. Latest LLM configuration from Settings is always used
    """
    global _edit_agent
    lang = _current_language()
    if _edit_agent is None or getattr(_edit_agent, "language", None) != lang:
        _edit_agent = EditAgent(language=lang)
    # Refresh config to pick up any changes from Settings
    _edit_agent.refresh_config()
    return _edit_agent


class EditRequest(BaseModel):
    text: str
    instruction: str
    action: Literal["rewrite", "shorten", "expand"] = "rewrite"
    source: Literal["rag", "web"] | None = None
    kb_name: str | None = None


class EditResponse(BaseModel):
    edited_text: str
    operation_id: str


class ReactEditRequest(BaseModel):
    selected_text: str
    instruction: str = ""
    mode: Literal["rewrite", "shorten", "expand", "none"] = "rewrite"
    tools: list[str] = []
    kb_name: str | None = None
    model: str | None = None


class ReactEditResponse(BaseModel):
    edited_text: str
    operation_id: str
    thinking: str = ""
    tool_traces: list[dict] = []


class AutoMarkRequest(BaseModel):
    text: str


class AutoMarkResponse(BaseModel):
    marked_text: str
    operation_id: str


class ExportPdfRequest(BaseModel):
    content: str
    filename: str = "cv.pdf"
    title: str = "CV"


def _normalize_react_edit_tools(tools: list[str] | None) -> list[str]:
    allowed = {
        "brainstorm",
        "rag",
        "web_search",
        "code_execution",
        "reason",
        "paper_search",
    }
    normalized: list[str] = []
    for name in tools or []:
        tool = str(name or "").strip()
        if tool and tool in allowed and tool not in normalized:
            normalized.append(tool)
    return normalized


def _markdown_heading_key(title: str) -> str:
    return re.sub(r"\s+", " ", title.strip().lower()).strip(" :")


def _markdown_to_pdf_bytes(markdown: str, *, title: str = "CV") -> bytes:
    try:
        from reportlab.lib import colors
        from reportlab.lib.enums import TA_LEFT
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
        from reportlab.lib.units import inch
        from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer
    except Exception as exc:  # pragma: no cover - import failure is environment-specific
        raise HTTPException(status_code=503, detail=f"PDF rendering unavailable: {exc}")

    buffer = BytesIO()
    document = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=0.65 * inch,
        leftMargin=0.65 * inch,
        topMargin=0.7 * inch,
        bottomMargin=0.7 * inch,
        title=title,
    )

    base_styles = getSampleStyleSheet()
    heading1 = ParagraphStyle(
        "DeepTutorHeading1",
        parent=base_styles["Heading1"],
        textColor=colors.HexColor("#D4734B"),
        fontSize=18,
        leading=22,
        spaceAfter=10,
    )
    heading2 = ParagraphStyle(
        "DeepTutorHeading2",
        parent=base_styles["Heading2"],
        textColor=colors.HexColor("#D4734B"),
        fontSize=13,
        leading=16,
        spaceBefore=6,
        spaceAfter=6,
    )
    heading3 = ParagraphStyle(
        "DeepTutorHeading3",
        parent=base_styles["Heading3"],
        textColor=colors.HexColor("#6A3B2E"),
        fontSize=11,
        leading=14,
        spaceBefore=4,
        spaceAfter=4,
    )
    body = ParagraphStyle(
        "DeepTutorBody",
        parent=base_styles["BodyText"],
        fontName="Helvetica",
        fontSize=10,
        leading=13,
        alignment=TA_LEFT,
        spaceAfter=5,
    )
    list_body = ParagraphStyle(
        "DeepTutorListBody",
        parent=body,
        leftIndent=14,
        firstLineIndent=0,
        spaceAfter=2,
    )

    def render_inline(text: str) -> str:
        rendered = html_escape(text)
        rendered = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", rendered)
        rendered = re.sub(r"\*(.+?)\*", r"<i>\1</i>", rendered)
        rendered = re.sub(r"`(.+?)`", r"<font name='Courier'>\1</font>", rendered)
        return rendered

    def flush_paragraph(lines: list[str], story: list[object]) -> None:
        if not lines:
            return
        paragraph_text = "<br/>".join(render_inline(line) for line in lines).strip()
        if paragraph_text:
            story.append(Paragraph(paragraph_text, body))
        lines.clear()

    story: list[object] = []
    paragraph_lines: list[str] = []
    current_title = title.strip() or "CV"
    story.append(Paragraph(render_inline(current_title), heading1))
    story.append(Spacer(1, 0.12 * inch))

    lines = markdown.splitlines()
    index = 0
    while index < len(lines):
        raw_line = lines[index]
        line = raw_line.rstrip()
        stripped = line.strip()

        if not stripped:
            flush_paragraph(paragraph_lines, story)
            index += 1
            continue

        heading_match = re.match(r"^(#{1,6})\s+(.+?)\s*$", stripped)
        if heading_match:
            flush_paragraph(paragraph_lines, story)
            level = len(heading_match.group(1))
            heading_text = render_inline(heading_match.group(2))
            if level == 1:
                story.append(Paragraph(heading_text, heading1))
            elif level == 2:
                story.append(Paragraph(heading_text, heading2))
            else:
                story.append(Paragraph(heading_text, heading3))
            index += 1
            continue

        if stripped in {"---", "***", "___"}:
            flush_paragraph(paragraph_lines, story)
            story.append(Spacer(1, 0.08 * inch))
            index += 1
            continue

        list_match = re.match(r"^(?P<indent>[ \t]*)(?P<marker>[-*+]|\d+[.)])\s+(?P<text>.+)$", raw_line)
        if list_match:
            flush_paragraph(paragraph_lines, story)
            indent = list_match.group("indent").expandtabs(4)
            level = max(len(indent) // 2, 0)
            marker = list_match.group("marker")
            bullet = marker if marker[0].isdigit() else "•"
            list_text = render_inline(list_match.group("text"))
            item_style = ParagraphStyle(
                f"DeepTutorListBody{level}",
                parent=list_body,
                leftIndent=14 + (level * 14),
            )
            story.append(Paragraph(list_text, item_style, bulletText=bullet))
            index += 1
            continue

        paragraph_lines.append(stripped)
        index += 1

    flush_paragraph(paragraph_lines, story)
    document.build(story)
    return buffer.getvalue()


def _markdown_to_pdf_filename(filename: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "-", filename.strip())
    cleaned = cleaned.strip("-") or "cv"
    if not cleaned.lower().endswith(".pdf"):
        cleaned += ".pdf"
    return cleaned

def _default_mode_instruction(mode: str, language: str) -> str:
    if language.startswith("zh"):
        defaults = {
            "rewrite": "润色这段 Markdown，保持原意但让表达更自然。",
            "shorten": "压缩这段 Markdown，同时保留关键信息。",
            "expand": "扩展这段 Markdown，补充必要细节。",
            "none": "根据用户要求编辑这段 Markdown。",
        }
        return defaults.get(mode, defaults["none"])
    defaults = {
        "rewrite": "Rewrite this Markdown while preserving the original meaning.",
        "shorten": "Shorten this Markdown while keeping the key information.",
        "expand": "Expand this Markdown with useful detail.",
        "none": "Edit this Markdown according to the user's request.",
    }
    return defaults.get(mode, defaults["none"])


def _build_react_edit_prompt(
    *,
    selected_text: str,
    instruction: str,
    mode: str,
    language: str,
) -> str:
    user_instruction = instruction.strip() or _default_mode_instruction(mode, language)
    if language.startswith("zh"):
        return (
            "你正在编辑一段从 Markdown 编辑器里选中的文本。\n\n"
            f"编辑模式: {mode}\n"
            f"用户要求: {user_instruction}\n\n"
            "待编辑的选中文本:\n"
            "```markdown\n"
            f"{selected_text}\n"
            "```\n\n"
            "要求:\n"
            "1. 只输出编辑后的那段 Markdown 文本，供编辑器直接替换。\n"
            "2. 不要输出解释、标题、前后缀、代码围栏。\n"
            "3. 保持 Markdown 语法合法。\n"
            "4. 如果用了工具，把工具得到的事实自然融入结果，不要提工具名。\n"
        )
    return (
        "You are editing a text selection from a Markdown editor.\n\n"
        f"Edit mode: {mode}\n"
        f"User request: {user_instruction}\n\n"
        "Selected text to edit:\n"
        "```markdown\n"
        f"{selected_text}\n"
        "```\n\n"
        "Requirements:\n"
        "1. Output only the edited Markdown snippet for direct replacement.\n"
        "2. Do not include explanations, headings, prefixes, suffixes, or code fences.\n"
        "3. Keep the Markdown valid.\n"
        "4. If tools were used, incorporate their facts naturally without mentioning the tools.\n"
    )


def _strip_markdown_fence(text: str) -> str:
    cleaned = text.strip()
    if cleaned.startswith("```") and cleaned.endswith("```"):
        lines = cleaned.splitlines()
        if len(lines) >= 3:
            return "\n".join(lines[1:-1]).strip()
    return cleaned


def _clean_react_edit_output(text: str, *, binding: str | None, model: str | None) -> str:
    return _strip_markdown_fence(clean_thinking_tags(text, binding, model))


def _prepare_react_edit_request(
    request: ReactEditRequest, language: str
) -> tuple[str, str, list[str], list[str], str]:
    tools = _normalize_react_edit_tools(request.tools)
    instruction = request.instruction.strip()
    if request.mode == "none" and not instruction:
        detail = (
            "请输入编辑要求，或选择 shorten / expand / rewrite 模式。"
            if language.startswith("zh")
            else "Provide an edit instruction, or choose shorten / expand / rewrite mode."
        )
        raise HTTPException(status_code=400, detail=detail)

    selected_text = request.selected_text.strip("\n")
    if not selected_text.strip():
        detail = (
            "请先选中一段文本。"
            if language.startswith("zh")
            else "Please select a text passage first."
        )
        raise HTTPException(status_code=400, detail=detail)

    knowledge_bases = [request.kb_name] if request.kb_name and "rag" in tools else []
    prompt = _build_react_edit_prompt(
        selected_text=selected_text,
        instruction=instruction,
        mode=request.mode,
        language=language,
    )
    return selected_text, instruction, tools, knowledge_bases, prompt


async def _run_react_edit(
    request: ReactEditRequest,
    *,
    language: str,
    stream: StreamBus | None = None,
) -> dict[str, object]:
    selected_text, instruction, tools, knowledge_bases, prompt = _prepare_react_edit_request(
        request, language
    )
    operation_id = datetime.now().strftime("%Y%m%d_%H%M%S") + "_" + uuid.uuid4().hex[:6]

    requested_model = (
        (request.model or "").strip()
        or (os.getenv("LLM_RATE_LIMIT_FALLBACK_MODEL") or "").strip()
        or None
    )

    context = UnifiedContext(
        session_id="",
        user_message=prompt,
        conversation_history=[],
        enabled_tools=tools,
        active_capability="chat",
        knowledge_bases=knowledge_bases,
        attachments=[],
        config_overrides={"model": requested_model} if requested_model else {},
        language=language,
        metadata={
            "source": "co_writer_react_edit",
            "mode": request.mode,
            "requested_model": requested_model,
        },
    )

    pipeline = AgenticChatPipeline(language=language)
    active_stream = stream or StreamBus()
    enabled_tools = pipeline._normalize_enabled_tools(context.enabled_tools)
    thinking_text = await pipeline._stage_thinking(context, enabled_tools, active_stream)
    tool_traces = await pipeline._stage_acting(
        context=context,
        enabled_tools=enabled_tools,
        thinking_text=thinking_text,
        stream=active_stream,
    )

    agent = get_edit_agent()
    system_prompt = (
        "You are an expert markdown editor."
        if not language.startswith("zh")
        else "你是一个严格的 Markdown 编辑助手。"
    )
    final_prompt = _build_react_edit_prompt(
        selected_text=selected_text,
        instruction=instruction,
        mode=request.mode,
        language=language,
    )
    if thinking_text.strip():
        if language.startswith("zh"):
            final_prompt += f"\n内部推理摘要（不要暴露给用户）:\n{thinking_text.strip()}\n"
        else:
            final_prompt += (
                f"\nInternal reasoning summary (do not reveal):\n{thinking_text.strip()}\n"
            )
    if tool_traces:
        formatted_traces = pipeline._format_tool_traces(tool_traces)
        if language.startswith("zh"):
            final_prompt += f"\n工具结果（只吸收事实，不要解释过程）:\n{formatted_traces}\n"
        else:
            final_prompt += (
                f"\nTool results (absorb the facts only, do not explain the process):\n"
                f"{formatted_traces}\n"
            )

    response_chunks: list[str] = []
    used_local_fallback = False
    try:
        if stream is None:
            async for _c in agent.stream_llm(
                user_prompt=final_prompt,
                system_prompt=system_prompt,
                model=requested_model,
                stage=f"react_edit_{request.mode}",
            ):
                if _c:
                    response_chunks.append(_c)
        else:
            async with active_stream.stage("responding", source="co_writer_react_edit"):
                await active_stream.progress(
                    "Writing final edit...",
                    source="co_writer_react_edit",
                    stage="responding",
                )
                async for chunk in agent.stream_llm(
                    user_prompt=final_prompt,
                    system_prompt=system_prompt,
                    model=requested_model,
                    stage=f"react_edit_{request.mode}",
                ):
                    if not chunk:
                        continue
                    response_chunks.append(chunk)
                    await active_stream.content(
                        chunk,
                        source="co_writer_react_edit",
                        stage="responding",
                    )
    except Exception as e:
        # Local deterministic fallback for development when LLM is unavailable.
        logger.warning(f"LLM stream failed in react edit, falling back: {e}")
        if request.mode == "shorten":
            edited_text = local_fallback_edit(selected_text, "shorten", request.instruction)
        elif request.mode == "expand":
            edited_text = local_fallback_edit(selected_text, "expand", request.instruction)
        else:
            edited_text = local_fallback_edit(selected_text, "rewrite", request.instruction)
        response_chunks = [edited_text]
        used_local_fallback = True

    edited_text = _clean_react_edit_output(
        "".join(response_chunks),
        binding=agent.binding,
        model=requested_model or agent.get_model(),
    )

    if looks_like_llm_error(edited_text):
        edited_text = local_fallback_edit(selected_text, request.mode, instruction)
        used_local_fallback = True

    if used_local_fallback:
        thinking_text = (
            "Used local markdown fallback because the model was unavailable."
            if not language.startswith("zh")
            else "模型不可用，已使用本地 Markdown 回退编辑。"
        )

    tool_call_file = None
    if tool_traces:
        tool_call_file = save_tool_call(
            operation_id,
            "react_tools",
            {
                "type": "react_tools",
                "timestamp": datetime.now().isoformat(),
                "operation_id": operation_id,
                "mode": request.mode,
                "tools": tools,
                "kb_name": request.kb_name,
                "thinking": thinking_text,
                "tool_traces": [asdict(trace) for trace in tool_traces],
            },
        )

    history = load_history()
    history.append(
        {
            "id": operation_id,
            "timestamp": datetime.now().isoformat(),
            "action": "react_edit",
            "mode": request.mode,
            "tools": tools,
            "kb_name": request.kb_name,
            "requested_model": requested_model,
            "input": {
                "selected_text": request.selected_text,
                "instruction": instruction,
            },
            "output": {"edited_text": edited_text},
            "tool_call_file": tool_call_file,
            "model": requested_model or agent.get_model(),
        }
    )
    save_history(history)
    print_stats()

    result = {
        "edited_text": edited_text,
        "operation_id": operation_id,
        "thinking": thinking_text,
        "tool_traces": [asdict(trace) for trace in tool_traces],
    }
    if stream is not None:
        await active_stream.result(result, source="co_writer_react_edit")
    return result


async def _stream_react_edit(request: ReactEditRequest) -> AsyncGenerator[str, None]:
    language = _current_language()
    bus = StreamBus()
    error_holder: dict[str, str] = {}
    result_holder: dict[str, object] | None = None

    async def _run() -> None:
        nonlocal result_holder
        try:
            result_holder = await _run_react_edit(request, language=language, stream=bus)
        except HTTPException as exc:
            error_holder["detail"] = str(exc.detail)
        except Exception as exc:
            error_holder["detail"] = str(exc)
        finally:
            await bus.close()

    task = asyncio.create_task(_run())
    try:
        async for event in bus.subscribe():
            yield f"event: stream\ndata: {json.dumps(event.to_dict(), default=str)}\n\n"

        await task
        if error_holder:
            yield f"event: error\ndata: {json.dumps(error_holder, default=str)}\n\n"
        else:
            yield f"event: result\ndata: {json.dumps(result_holder or {}, default=str)}\n\n"
    finally:
        if not task.done():
            task.cancel()


@router.post("/edit", response_model=EditResponse)
async def edit_text(request: EditRequest):
    try:
        # Get agent with refreshed LLM configuration from Settings
        agent = get_edit_agent()

        result = await agent.process(
            text=request.text,
            instruction=request.instruction,
            action=request.action,
            source=request.source,
            kb_name=request.kb_name,
        )

        # Print token stats
        print_stats()

        return result

    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/edit_react", response_model=ReactEditResponse)
async def edit_text_react(request: ReactEditRequest):
    try:
        return await _run_react_edit(request, language=_current_language())
    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/edit_react/stream")
async def edit_text_react_stream(request: ReactEditRequest):
    try:
        _prepare_react_edit_request(request, _current_language())
    except HTTPException:
        raise
    return StreamingResponse(
        _stream_react_edit(request),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.post("/automark", response_model=AutoMarkResponse)
async def auto_mark_text(request: AutoMarkRequest):
    """AI auto-mark text"""
    try:
        # Get agent with refreshed LLM configuration from Settings
        agent = get_edit_agent()

        result = await agent.auto_mark(text=request.text)

        # Print token stats
        print_stats()

        return result
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/history")
async def get_history():
    """Get all operation history"""
    try:
        history = load_history()
        return {"history": history, "total": len(history)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/history/{operation_id}")
async def get_operation(operation_id: str):
    """Get single operation details"""
    try:
        history = load_history()
        for op in history:
            if op.get("id") == operation_id:
                return op
        raise HTTPException(status_code=404, detail="Operation not found")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/tool_calls/{operation_id}")
async def get_tool_call(operation_id: str):
    """Get tool call details"""
    try:
        # Find matching file
        for filepath in tool_calls_dir().glob(f"{operation_id}_*.json"):
            with open(filepath, encoding="utf-8") as f:
                return json.load(f)
        raise HTTPException(status_code=404, detail="Tool call not found")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/export/markdown")
async def export_markdown(content: dict):
    """Export as Markdown file"""
    try:
        markdown_content = content.get("content", "")
        filename = content.get("filename", "document.md")

        return Response(
            content=markdown_content,
            media_type="text/markdown",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/export/pdf")
async def export_pdf(request: ExportPdfRequest):
    """Render Markdown content to a server-generated PDF."""
    try:
        pdf_bytes = _markdown_to_pdf_bytes(request.content, title=request.title)
        filename = _markdown_to_pdf_filename(request.filename)
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────────────────────────────────────────
# Document CRUD (multi-project Co-Writer)
# ─────────────────────────────────────────────────────────────────────────────


class CreateDocumentRequest(BaseModel):
    title: str | None = None
    content: str = ""


class UpdateDocumentRequest(BaseModel):
    title: str | None = None
    content: str | None = None


class DocumentResponse(BaseModel):
    id: str
    title: str
    content: str
    created_at: float
    updated_at: float

    @classmethod
    def from_model(cls, doc: CoWriterDocument) -> "DocumentResponse":
        return cls(
            id=doc.id,
            title=doc.title,
            content=doc.content,
            created_at=doc.created_at,
            updated_at=doc.updated_at,
        )


class DocumentSummaryResponse(BaseModel):
    id: str
    title: str
    created_at: float
    updated_at: float
    preview: str = ""
    word_count: int = 0

    @classmethod
    def from_summary(cls, summary: CoWriterDocumentSummary) -> "DocumentSummaryResponse":
        return cls(
            id=summary.id,
            title=summary.title,
            created_at=summary.created_at,
            updated_at=summary.updated_at,
            preview=summary.preview,
            word_count=summary.word_count,
        )


@router.get("/documents")
async def list_documents() -> dict[str, list[DocumentSummaryResponse]]:
    """List all Co-Writer documents (summary view, sorted by recency)."""
    try:
        storage = get_co_writer_storage()
        summaries = storage.list_documents()
        return {"documents": [DocumentSummaryResponse.from_summary(s) for s in summaries]}
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/documents", response_model=DocumentResponse)
async def create_document(request: CreateDocumentRequest) -> DocumentResponse:
    """Create a new Co-Writer document."""
    try:
        storage = get_co_writer_storage()
        document = storage.create_document(title=request.title, content=request.content)
        return DocumentResponse.from_model(document)
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/documents/{doc_id}", response_model=DocumentResponse)
async def get_document(doc_id: str) -> DocumentResponse:
    """Get a single Co-Writer document by id."""
    try:
        storage = get_co_writer_storage()
        document = storage.load_document(doc_id)
        if document is None:
            raise HTTPException(status_code=404, detail="Document not found")
        return DocumentResponse.from_model(document)
    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/documents/{doc_id}", response_model=DocumentResponse)
async def update_document(doc_id: str, request: UpdateDocumentRequest) -> DocumentResponse:
    """Update a Co-Writer document (title and/or content)."""
    try:
        storage = get_co_writer_storage()
        document = storage.update_document(doc_id, title=request.title, content=request.content)
        if document is None:
            raise HTTPException(status_code=404, detail="Document not found")
        return DocumentResponse.from_model(document)
    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/documents/{doc_id}")
async def delete_document(doc_id: str) -> dict[str, bool]:
    """Delete a Co-Writer document."""
    try:
        storage = get_co_writer_storage()
        if not storage.doc_exists(doc_id):
            raise HTTPException(status_code=404, detail="Document not found")
        success = storage.delete_document(doc_id)
        return {"deleted": success}
    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
