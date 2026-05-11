"""Optional image generation backends (external services)."""

from deeptutor.services.image_generation.hidream_remote import (
    HiDreamConfigurationError,
    HiDreamGenerationError,
    generate_hidream_t2i_png,
    save_hidream_png_to_chat_workspace,
)

__all__ = [
    "HiDreamConfigurationError",
    "HiDreamGenerationError",
    "generate_hidream_t2i_png",
    "save_hidream_png_to_chat_workspace",
]
