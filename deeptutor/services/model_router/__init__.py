"""Multi-model intent router — maps query intent to the best-fit model config."""

from deeptutor.services.model_router.intent import Intent, detect_intent
from deeptutor.services.model_router.router import ModelRouter, get_model_router

__all__ = ["Intent", "detect_intent", "ModelRouter", "get_model_router"]
