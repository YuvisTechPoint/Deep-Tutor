"""Model routing API — exposes the intent→model mapping to the frontend.

Exposes:
  GET /api/v1/model-routing/routes      — all intent→model mappings
  POST /api/v1/model-routing/detect     — detect intent for a text query
"""
from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()


class IntentDetectionRequest(BaseModel):
    text: str
    has_image: bool = False


class IntentDetectionResponse(BaseModel):
    intent: str
    model: str
    model_description: str


class RouteEntry(BaseModel):
    intent: str
    model: str
    description: str
    env_override: str
    backend: str = "huggingface"
    self_hosted: bool = False
    api_base: str = ""


@router.get("/model-routing/routes", response_model=list[RouteEntry])
async def get_routes() -> list[RouteEntry]:
    """Return current intent→model routing table."""
    from deeptutor.services.model_router import get_model_router

    router_svc = get_model_router()
    return [RouteEntry(**entry) for entry in router_svc.all_routes()]


@router.get("/model-routing/catalog")
async def get_catalog() -> dict:
    """Return the full model catalog (intent + auxiliary roles)."""
    from deeptutor.services.model_router import get_model_router

    router_svc = get_model_router()
    return {"entries": router_svc.catalog()}


@router.get("/model-routing/feature-surfaces")
async def feature_surfaces() -> dict:
    """Return per-UI-surface model role mapping (for inline 'powered by' badges)."""
    from deeptutor.services.model_router import get_model_router

    router_svc = get_model_router()
    return {"surfaces": router_svc.feature_surfaces()}


@router.post("/model-routing/detect", response_model=IntentDetectionResponse)
async def detect_intent_endpoint(body: IntentDetectionRequest) -> IntentDetectionResponse:
    """Detect the routing intent for a query string."""
    from deeptutor.api.routers.learning_profile import _load_raw as _load_learning_profile
    from deeptutor.services.model_router import (
        adjust_intent_with_learning_profile,
        detect_intent,
        get_model_router,
    )

    intent = detect_intent(body.text, body.has_image)
    intent = adjust_intent_with_learning_profile(intent, _load_learning_profile())
    router_svc = get_model_router()
    cfg = router_svc.route(intent)
    return IntentDetectionResponse(
        intent=intent.value,
        model=cfg.model,
        model_description=cfg.description,
    )
