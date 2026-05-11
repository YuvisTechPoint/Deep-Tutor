"""HiDream-O1-Image proxy API (requires upstream Flask server)."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from deeptutor.services.image_generation import (
    HiDreamConfigurationError,
    HiDreamGenerationError,
    generate_hidream_t2i_png,
    save_hidream_png_to_chat_workspace,
)

router = APIRouter()


class HiDreamT2IRequest(BaseModel):
    prompt: str = Field(..., min_length=1)
    width: int = Field(default=1024, ge=256, le=2048)
    height: int = Field(default=1024, ge=256, le=2048)
    seed: int = Field(default=32)


class HiDreamT2IResponse(BaseModel):
    relative_path: str
    outputs_url_path: str


@router.post("/hidream/t2i", response_model=HiDreamT2IResponse)
async def hidream_text_to_image(body: HiDreamT2IRequest) -> HiDreamT2IResponse:
    """Generate a PNG via HiDream-O1-Image (upstream ``app.py``), save under chat workspace."""
    try:
        png = await generate_hidream_t2i_png(
            prompt=body.prompt.strip(),
            width=body.width,
            height=body.height,
            seed=body.seed,
        )
        rel = save_hidream_png_to_chat_workspace(png)
    except HiDreamConfigurationError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except HiDreamGenerationError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"HiDream request failed: {exc}") from exc

    return HiDreamT2IResponse(
        relative_path=rel,
        outputs_url_path=f"/api/outputs/{rel}",
    )
