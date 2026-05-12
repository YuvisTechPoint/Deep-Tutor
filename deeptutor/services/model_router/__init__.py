"""Multi-model intent router — maps query intent to the best-fit model config."""

from deeptutor.services.model_router.intent import (
    Intent,
    adjust_intent_with_learning_profile,
    detect_intent,
)
from deeptutor.services.model_router.router import ModelRouter, get_model_router

__all__ = [
    "Intent",
    "adjust_intent_with_learning_profile",
    "detect_intent",
    "ModelRouter",
    "get_model_router",
]
