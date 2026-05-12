"""
Chat API Router
================

WebSocket endpoint for lightweight chat with session management.
REST endpoints for session operations.
"""

import logging
from types import SimpleNamespace

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect

from deeptutor.agents.chat import ChatAgent, SessionManager
from deeptutor.services.config import PROJECT_ROOT, load_config_with_main
from deeptutor.services.llm.config import LLMConfig, get_llm_config
from deeptutor.api.routers.learning_profile import _load_raw as _load_learning_profile
from deeptutor.analytics.emit import emit_domain_event
from deeptutor.services.model_router import (
    adjust_intent_with_learning_profile,
    detect_intent,
    get_model_router,
)
from deeptutor.services.settings.interface_settings import get_ui_language

# Initialize logger
config = load_config_with_main("main.yaml", PROJECT_ROOT)
log_dir = config.get("paths", {}).get("user_log_dir") or config.get("logging", {}).get("log_dir")
logger = logging.getLogger(__name__)

router = APIRouter()

# Initialize session manager
session_manager = SessionManager()


# =============================================================================
# REST Endpoints for Session Management
# =============================================================================


@router.get("/chat/sessions")
async def list_sessions(limit: int = 20):
    """
    List recent chat sessions.

    Args:
        limit: Maximum number of sessions to return

    Returns:
        List of session summaries
    """
    return session_manager.list_sessions(limit=limit, include_messages=False)


@router.get("/chat/sessions/{session_id}")
async def get_session(session_id: str):
    """
    Get a specific chat session with full message history.

    Args:
        session_id: Session identifier

    Returns:
        Complete session data including messages
    """
    session = session_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.delete("/chat/sessions/{session_id}")
async def delete_session(session_id: str):
    """
    Delete a chat session.

    Args:
        session_id: Session identifier

    Returns:
        Success message
    """
    if session_manager.delete_session(session_id):
        return {"status": "deleted", "session_id": session_id}
    raise HTTPException(status_code=404, detail="Session not found")


# =============================================================================
# WebSocket Endpoint for Chat
# =============================================================================


@router.websocket("/chat")
async def websocket_chat(websocket: WebSocket):
    """
    WebSocket endpoint for chat with session and context management.

    Message format:
    {
        "message": str,              # User message
        "session_id": str | null,    # Session ID (null for new session)
        "history": [...] | null,     # Optional: explicit history override
        "kb_name": str,              # Knowledge base name (for RAG)
        "enable_rag": bool,          # Enable RAG retrieval
        "enable_web_search": bool,   # Enable Web Search
        "image_data": str | null     # Optional data:image/... base64 payload
    }

    Response format:
    - {"type": "session", "session_id": str}           # Session ID (new or existing)
    - {"type": "status", "stage": str, "message": str} # Status updates
    - {"type": "stream", "content": str}               # Streaming response chunks
    - {"type": "sources", "rag": list, "web": list}    # Source citations
    - {"type": "result", "content": str}               # Final complete response
    - {"type": "error", "message": str}                # Error message
    """
    await websocket.accept()

    try:
        while True:
            # Receive message
            data = await websocket.receive_json()
            # Prefer the client-sent UI language for this turn; fall back to
            # persisted Settings so prompt loading tracks the language switch.
            requested_language = str(data.get("language") or "").lower().strip()
            language = (
                "zh"
                if requested_language.startswith("zh")
                else "en"
                if requested_language.startswith("en")
                else get_ui_language(default=config.get("system", {}).get("language", "en"))
            )
            message = data.get("message", "").strip()
            session_id = data.get("session_id")
            explicit_history = data.get("history")  # Optional override
            kb_name = data.get("kb_name", "")
            enable_rag = data.get("enable_rag", False)
            enable_web_search = data.get("enable_web_search", False)
            image_data = str(data.get("image_data") or "").strip()
            has_image = bool(image_data)

            if not message and not has_image:
                await websocket.send_json({"type": "error", "message": "Message is required"})
                continue

            logger.info(
                f"Chat request: session={session_id}, "
                f"message={message[:50]}..., rag={enable_rag}, web={enable_web_search}"
            )

            try:
                # Get or create session
                if session_id:
                    session = session_manager.get_session(session_id)
                    if not session:
                        # Session not found, create new one
                        session = session_manager.create_session(
                            title=message[:50] + ("..." if len(message) > 50 else ""),
                            settings={
                                "kb_name": kb_name,
                                "enable_rag": enable_rag,
                                "enable_web_search": enable_web_search,
                            },
                        )
                        session_id = session["session_id"]
                else:
                    # Create new session
                    session = session_manager.create_session(
                        title=message[:50] + ("..." if len(message) > 50 else ""),
                        settings={
                            "kb_name": kb_name,
                            "enable_rag": enable_rag,
                            "enable_web_search": enable_web_search,
                        },
                    )
                    session_id = session["session_id"]

                # Send session ID to frontend
                await websocket.send_json(
                    {
                        "type": "session",
                        "session_id": session_id,
                    }
                )

                # Build history from session or explicit override
                if explicit_history is not None:
                    history = explicit_history
                else:
                    # Get history from session messages
                    history = [
                        {"role": msg["role"], "content": msg["content"]}
                        for msg in session.get("messages", [])
                    ]

                # Add user message to session
                session_manager.add_message(
                    session_id=session_id,
                    role="user",
                    content=message,
                )

                intent = detect_intent(message, has_image=has_image)
                intent = adjust_intent_with_learning_profile(
                    intent,
                    _load_learning_profile(),
                )
                # Use feature-aware routing so ``HF_MODEL_CHAT`` (if set) takes
                # precedence over the intent default while still respecting
                # specialist routes (e.g. coding → DeepSeek-Coder) when the
                # user has not pinned a chat-specific model.
                routed = get_model_router().route_feature("chat", intent=intent)
                emit_domain_event(
                    "ModelRouteSelected",
                    subject_type="ChatTurn",
                    subject_id=session_id,
                    payload={"intent": intent.value, "model": routed.model},
                )
                await websocket.send_json(
                    {
                        "type": "route",
                        "intent": intent.value,
                        "model": routed.model,
                        "model_description": routed.description,
                    }
                )

                # Initialize ChatAgent. If HF_TOKEN is configured, route this
                # turn to the specialist model for the detected intent. If not,
                # keep the user's active provider profile and let the LLM layer
                # emit a clear missing-credentials message instead of calling
                # OpenAI with "no-key".
                try:
                    llm_config = get_llm_config()
                    if routed.api_key:
                        llm_config = LLMConfig(
                            model=routed.model,
                            api_key=routed.api_key,
                            base_url=routed.api_base,
                            effective_url=routed.api_base,
                            binding="huggingface",
                            provider_name="huggingface",
                            provider_mode="gateway",
                        )
                    api_key = llm_config.api_key
                    base_url = llm_config.base_url
                    api_version = getattr(llm_config, "api_version", None)
                    model = llm_config.model
                    binding = getattr(llm_config, "binding", None) or "openai"
                except Exception:
                    api_key = None
                    base_url = None
                    api_version = None
                    model = routed.model
                    binding = "huggingface"

                agent = ChatAgent(
                    language=language,
                    config=config,
                    api_key=api_key,
                    base_url=base_url,
                    api_version=api_version,
                    model=model,
                    binding=binding,
                )

                # Send status updates
                if enable_rag and kb_name:
                    await websocket.send_json(
                        {
                            "type": "status",
                            "stage": "rag",
                            "message": f"Searching knowledge base: {kb_name}...",
                        }
                    )

                if enable_web_search:
                    await websocket.send_json(
                        {
                            "type": "status",
                            "stage": "web",
                            "message": "Searching the web...",
                        }
                    )

                await websocket.send_json(
                    {
                        "type": "status",
                        "stage": "generating",
                        "message": "Generating response...",
                    }
                )

                # Process with streaming
                full_response = ""
                sources = {"rag": [], "web": []}

                attachments = []
                if image_data:
                    mime_type = "image/png"
                    base64_data = image_data
                    if image_data.startswith("data:") and "," in image_data:
                        meta, base64_data = image_data.split(",", 1)
                        mime_type = meta.removeprefix("data:").split(";", 1)[0] or mime_type
                    attachments.append(
                        SimpleNamespace(
                            type="image",
                            filename="uploaded-image.png",
                            mime_type=mime_type,
                            base64=base64_data,
                            url="",
                        )
                    )

                stream_generator = await agent.process(
                    message=message,
                    history=history,
                    kb_name=kb_name,
                    enable_rag=enable_rag,
                    enable_web_search=enable_web_search,
                    stream=True,
                    attachments=attachments,
                )

                async for chunk_data in stream_generator:
                    if chunk_data["type"] == "chunk":
                        await websocket.send_json(
                            {
                                "type": "stream",
                                "content": chunk_data["content"],
                            }
                        )
                        full_response += chunk_data["content"]
                    elif chunk_data["type"] == "complete":
                        full_response = chunk_data["response"]
                        sources = chunk_data.get("sources", {"rag": [], "web": []})

                # Send sources if any
                if sources.get("rag") or sources.get("web"):
                    await websocket.send_json({"type": "sources", **sources})

                # Send final result
                await websocket.send_json(
                    {
                        "type": "result",
                        "content": full_response,
                    }
                )

                # Save assistant message to session
                session_manager.add_message(
                    session_id=session_id,
                    role="assistant",
                    content=full_response,
                    sources=sources if (sources.get("rag") or sources.get("web")) else None,
                )

                logger.info(f"Chat completed: session={session_id}, {len(full_response)} chars")

            except Exception as e:
                logger.error(f"Chat processing error: {e}")
                await websocket.send_json({"type": "error", "message": str(e)})

    except WebSocketDisconnect:
        logger.debug("Client disconnected from chat")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        try:
            await websocket.send_json({"type": "error", "message": str(e)})
        except Exception:
            pass
