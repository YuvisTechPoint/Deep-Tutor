import asyncio
from contextlib import asynccontextmanager
import logging
import os

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from deeptutor.logging import configure_logging
from deeptutor.services.config import get_env_store
from deeptutor.services.path_service import get_path_service

_env_values = get_env_store().load()
for _key in (
    "AUTH_ENABLED",
    "AUTH_SECRET",
    "AUTH_TOKEN_EXPIRE_HOURS",
    "AUTH_USERNAME",
    "AUTH_PASSWORD_HASH",
    "POCKETBASE_URL",
    "POCKETBASE_ADMIN_EMAIL",
    "POCKETBASE_ADMIN_PASSWORD",
):
    if _key in _env_values:
        os.environ[_key] = _env_values[_key]
configure_logging()
logger = logging.getLogger(__name__)


class _SuppressWsNoise(logging.Filter):
    """Suppress noisy uvicorn logs for WebSocket connection churn."""

    _SUPPRESSED = ("connection open", "connection closed")

    def filter(self, record: logging.LogRecord) -> bool:
        msg = record.getMessage()
        return not any(f in msg for f in self._SUPPRESSED)


logging.getLogger("uvicorn.error").addFilter(_SuppressWsNoise())

CONFIG_DRIFT_ERROR_TEMPLATE = (
    "Configuration Drift Detected: Capability tool references {drift} are not "
    "registered in the runtime tool registry. Register the missing tools or "
    "remove the stale tool names from the capability manifests."
)
TRUTHY_ENV_VALUES = {"1", "true", "yes", "on"}


class SafeOutputStaticFiles(StaticFiles):
    """Static file mount that only exposes explicitly whitelisted artifacts."""

    def __init__(self, *args, path_service, **kwargs):
        super().__init__(*args, **kwargs)
        self._path_service = path_service

    async def get_response(self, path: str, scope):
        if not self._path_service.is_public_output_path(path):
            raise HTTPException(status_code=404, detail="Output not found")
        return await super().get_response(path, scope)


def validate_tool_consistency():
    """
    Validate that capability manifests only reference tools that are actually
    registered in the runtime ``ToolRegistry``.
    """
    try:
        from deeptutor.runtime.registry.capability_registry import get_capability_registry
        from deeptutor.runtime.registry.tool_registry import get_tool_registry

        capability_registry = get_capability_registry()
        tool_registry = get_tool_registry()
        available_tools = set(tool_registry.list_tools())

        referenced_tools = set()
        for manifest in capability_registry.get_manifests():
            referenced_tools.update(manifest.get("tools_used", []) or [])

        drift = referenced_tools - available_tools
        if drift:
            raise RuntimeError(CONFIG_DRIFT_ERROR_TEMPLATE.format(drift=drift))
    except RuntimeError:
        logger.exception("Configuration validation failed")
        raise
    except Exception:
        logger.exception("Failed to load configuration for validation")
        raise


def _env_truthy(value: str | None) -> bool:
    return str(value or "").strip().lower() in TRUTHY_ENV_VALUES


def _split_origins(value: str | None) -> list[str]:
    if not value:
        return []
    origins: list[str] = []
    seen: set[str] = set()
    for raw in value.replace("\n", ",").split(","):
        origin = raw.strip().rstrip("/")
        if not origin or origin in seen:
            continue
        origins.append(origin)
        seen.add(origin)
    return origins


def _build_cors_settings() -> dict[str, object]:
    """Build CORS settings for mobile/web clients and remote Docker deployments."""
    extra_origins = _split_origins(os.getenv("CORS_ORIGIN")) + _split_origins(
        os.getenv("CORS_ORIGINS")
    )
    origins = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]
    for origin in extra_origins:
        if origin not in origins:
            origins.append(origin)

    # Auth is disabled by default. In that local/single-user mode, allow remote
    # Docker/LAN browser origins out of the box. When auth is enabled, still allow
    # localhost dev ports while keeping explicit CORS_ORIGIN(S) for deployments.
    allow_origin_regex = (
        r"https?://(localhost|127\.0\.0\.1)(:\d+)?"
        if _env_truthy(os.getenv("AUTH_ENABLED"))
        else r"https?://.*"
    )
    return {"allow_origins": origins, "allow_origin_regex": allow_origin_regex}


_clickhouse_flush_task: asyncio.Task | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifecycle management
    Gracefully handle startup and shutdown events, avoid CancelledError
    """
    global _clickhouse_flush_task
    # Execute on startup
    logger.info("Application startup")

    # Validate configuration consistency
    validate_tool_consistency()

    # Initialize LLM client early so OPENAI_* env vars are available before
    # any downstream provider integrations start.
    try:
        from deeptutor.services.llm import get_llm_client

        llm_client = get_llm_client()
        logger.info(f"LLM client initialized: model={llm_client.config.model}")
    except Exception as e:
        logger.warning(f"Failed to initialize LLM client at startup: {e}")

    try:
        from deeptutor.events.event_bus import get_event_bus

        event_bus = get_event_bus()
        await event_bus.start()
        logger.info("EventBus started")
    except Exception as e:
        logger.warning(f"Failed to start EventBus: {e}")

    try:
        from deeptutor.services.tutorbot import get_tutorbot_manager

        await get_tutorbot_manager().auto_start_bots()
    except Exception as e:
        logger.warning(f"Failed to auto-start TutorBots: {e}")

    # Ping PocketBase if configured — logs a warning (not an error) if unreachable
    try:
        from deeptutor.services.pocketbase_client import ping_pocketbase

        await ping_pocketbase()
    except Exception as e:
        logger.warning(f"PocketBase startup check failed: {e}")

    try:
        from deeptutor.analytics import neo4j_graph

        sync_result = neo4j_graph.sync_milestone_graph_from_templates()
        if sync_result.get("edges_written"):
            logger.info("Neo4j milestone graph synced: %s edges", sync_result["edges_written"])
    except Exception as e:
        logger.debug(f"Neo4j startup sync skipped: {e}")

    async def _clickhouse_flush_loop() -> None:
        from deeptutor.analytics import clickhouse_sync

        while True:
            await asyncio.sleep(30)
            try:
                n = clickhouse_sync.flush_once()
                if n:
                    logger.info("ClickHouse domain_events flush: %s rows", n)
            except Exception:
                logger.debug("ClickHouse flush tick failed", exc_info=True)

    _clickhouse_flush_task = asyncio.create_task(_clickhouse_flush_loop())

    yield

    # Execute on shutdown
    logger.info("Application shutdown")

    if _clickhouse_flush_task is not None:
        _clickhouse_flush_task.cancel()
        try:
            await _clickhouse_flush_task
        except asyncio.CancelledError:
            pass
        _clickhouse_flush_task = None

    # Stop TutorBots
    try:
        from deeptutor.services.tutorbot import get_tutorbot_manager

        await get_tutorbot_manager().stop_all(preserve_auto_start=True)
        logger.info("TutorBots stopped")
    except Exception as e:
        logger.warning(f"Failed to stop TutorBots: {e}")

    # Stop EventBus
    try:
        from deeptutor.events.event_bus import get_event_bus

        event_bus = get_event_bus()
        await event_bus.stop()
        logger.info("EventBus stopped")
    except Exception as e:
        logger.warning(f"Failed to stop EventBus: {e}")


app = FastAPI(
    title="DeepTutor API",
    version="1.0.0",
    lifespan=lifespan,
    # Disable automatic trailing slash redirects to prevent protocol downgrade issues
    # when deployed behind HTTPS reverse proxies (e.g., nginx).
    # Without this, FastAPI's 307 redirects may change HTTPS to HTTP.
    # See: https://github.com/HKUDS/DeepTutor/issues/112
    redirect_slashes=False,
)

# Log only non-200 requests (uvicorn access_log is disabled in run_server.py)
_access_logger = logging.getLogger("uvicorn.access")


@app.middleware("http")
async def selective_access_log(request, call_next):
    response = await call_next(request)
    if response.status_code != 200:
        _access_logger.info(
            '%s - "%s %s HTTP/%s" %d',
            request.client.host if request.client else "-",
            request.method,
            request.url.path,
            request.scope.get("http_version", "1.1"),
            response.status_code,
        )
    return response


_cors_settings = _build_cors_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_settings["allow_origins"],
    allow_origin_regex=_cors_settings["allow_origin_regex"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount a filtered view over user outputs.
# Only whitelisted artifact paths are readable through the static handler.
path_service = get_path_service()
user_dir = path_service.get_public_outputs_root()

# Initialize user directories on startup
try:
    from deeptutor.services.setup import init_user_directories

    init_user_directories()
except Exception:
    # Fallback: just create the main directory if it doesn't exist
    if not user_dir.exists():
        user_dir.mkdir(parents=True)

app.mount(
    "/api/outputs",
    SafeOutputStaticFiles(directory=str(user_dir), path_service=path_service),
    name="outputs",
)

# Import routers only after runtime settings are initialized.
# Some router modules load YAML settings at import time.
from deeptutor.api.routers import (
    achievements,
    agent_config,
    analytics,
    attachments,
    auth,
    book,
    career,
    career_updates,
    chat,
    co_writer,
    coding_practice,
    dashboard,
    diagnostic,
    domain_events_admin,
    gamification,
    image_generation,
    knowledge,
    learning_graph,
    learning_plan,
    learning_profile,
    live_session_prep,
    memory,
    missions,
    model_routing,
    notebook,
    notifications,
    payments,
    plugins_api,
    practice,
    question,
    question_notebook,
    revision,
    safety,
    sessions,
    settings,
    skills,
    solve,
    speech,
    system,
    tutorbot,
    unified_ws,
    vision_solver,
    workflow,
)
from deeptutor.multi_user.router import router as multi_user_router  # noqa: E402

# Auth router is public — login/logout/register/status require no token
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])

# All other routers require a valid session when AUTH_ENABLED=true.
# require_auth is a no-op when AUTH_ENABLED=false, so this is safe for local use.
from deeptutor.api.routers.auth import require_auth  # noqa: E402

_auth = [Depends(require_auth)]

app.include_router(
    multi_user_router,
    prefix="/api/v1/multi-user",
    tags=["multi-user"],
    dependencies=_auth,
)

app.include_router(solve.router, prefix="/api/v1", tags=["solve"], dependencies=_auth)
app.include_router(chat.router, prefix="/api/v1", tags=["chat"], dependencies=_auth)
app.include_router(
    question.router, prefix="/api/v1/question", tags=["question"], dependencies=_auth
)
app.include_router(
    knowledge.router, prefix="/api/v1/knowledge", tags=["knowledge"], dependencies=_auth
)
app.include_router(
    dashboard.router, prefix="/api/v1/dashboard", tags=["dashboard"], dependencies=_auth
)
app.include_router(
    co_writer.router, prefix="/api/v1/co_writer", tags=["co_writer"], dependencies=_auth
)
app.include_router(
    notebook.router, prefix="/api/v1/notebook", tags=["notebook"], dependencies=_auth
)
app.include_router(book.router, prefix="/api/v1/book", tags=["book"], dependencies=_auth)
app.include_router(memory.router, prefix="/api/v1/memory", tags=["memory"], dependencies=_auth)
app.include_router(
    learning_profile.router,
    prefix="/api/v1/learning-profile",
    tags=["learning-profile"],
    dependencies=_auth,
)
app.include_router(
    sessions.router, prefix="/api/v1/sessions", tags=["sessions"], dependencies=_auth
)
app.include_router(
    question_notebook.router,
    prefix="/api/v1/question-notebook",
    tags=["question-notebook"],
    dependencies=_auth,
)
app.include_router(
    settings.router, prefix="/api/v1/settings", tags=["settings"], dependencies=_auth
)
app.include_router(skills.router, prefix="/api/v1/skills", tags=["skills"], dependencies=_auth)
app.include_router(system.router, prefix="/api/v1/system", tags=["system"], dependencies=_auth)
app.include_router(
    plugins_api.router, prefix="/api/v1/plugins", tags=["plugins"], dependencies=_auth
)
app.include_router(
    image_generation.router,
    prefix="/api/v1/image-generation",
    tags=["image-generation"],
    dependencies=_auth,
)
app.include_router(
    agent_config.router, prefix="/api/v1/agent-config", tags=["agent-config"], dependencies=_auth
)
app.include_router(
    vision_solver.router, prefix="/api/v1", tags=["vision-solver"], dependencies=_auth
)
app.include_router(
    speech.router, prefix="/api/v1", tags=["speech"], dependencies=_auth
)
app.include_router(
    safety.router, prefix="/api/v1", tags=["safety"], dependencies=_auth
)
app.include_router(
    model_routing.router,
    prefix="/api/v1",
    tags=["model-routing"],
    dependencies=_auth,
)
app.include_router(
    tutorbot.router, prefix="/api/v1/tutorbot", tags=["tutorbot"], dependencies=_auth
)
app.include_router(
    attachments.router,
    prefix="/api/attachments",
    tags=["attachments"],
    dependencies=_auth,
)

# ── Adaptive learning / gamification surfaces ─────────────────────────────────
app.include_router(
    gamification.router,
    prefix="/api/v1/gamification",
    tags=["gamification"],
    dependencies=_auth,
)
app.include_router(
    achievements.router,
    prefix="/api/v1/achievements",
    tags=["achievements"],
    dependencies=_auth,
)
app.include_router(
    notifications.router,
    prefix="/api/v1/notifications",
    tags=["notifications"],
    dependencies=_auth,
)
app.include_router(
    learning_plan.router,
    prefix="/api/v1/learning-plan",
    tags=["learning-plan"],
    dependencies=_auth,
)
app.include_router(
    live_session_prep.router,
    prefix="/api/v1/live-session",
    tags=["live-session"],
    dependencies=_auth,
)
app.include_router(
    learning_graph.router,
    prefix="/api/v1/learning/graph",
    tags=["learning-graph"],
    dependencies=_auth,
)
app.include_router(
    missions.router,
    prefix="/api/v1/missions",
    tags=["missions"],
    dependencies=_auth,
)
app.include_router(
    career.router,
    prefix="/api/v1/career",
    tags=["career"],
    dependencies=_auth,
)
app.include_router(
    career_updates.router,
    prefix="/api/v1/career",
    tags=["career"],
)
app.include_router(
    analytics.router,
    prefix="/api/v1/analytics",
    tags=["analytics"],
    dependencies=_auth,
)
app.include_router(
    domain_events_admin.router,
    prefix="/api/v1/admin",
    tags=["admin"],
    dependencies=_auth,
)
app.include_router(
    practice.router,
    prefix="/api/v1/practice",
    tags=["practice"],
    dependencies=_auth,
)
app.include_router(
    coding_practice.router,
    prefix="/api/v1/coding-practice",
    tags=["coding-practice"],
    dependencies=_auth,
)
app.include_router(
    diagnostic.router,
    prefix="/api/v1/diagnostic",
    tags=["diagnostic"],
    dependencies=_auth,
)
app.include_router(
    revision.router,
    prefix="/api/v1/revision",
    tags=["revision"],
    dependencies=_auth,
)
app.include_router(
    workflow.router,
    prefix="/api/v1/workflow",
    tags=["workflow"],
    dependencies=_auth,
)
app.include_router(
    payments.router,
    prefix="/api/v1/payments",
    tags=["payments"],
    dependencies=_auth,
)

# Unified WebSocket endpoint — auth is checked inside the handler (WebSockets
# cannot use FastAPI dependencies in the standard way)
app.include_router(unified_ws.router, prefix="/api/v1", tags=["unified-ws"])


@app.get("/")
async def root():
    return {"message": "Welcome to DeepTutor API"}


if __name__ == "__main__":
    from deeptutor.api.run_server import main as run_server_main

    run_server_main()
