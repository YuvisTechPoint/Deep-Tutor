"""Spaced revision queue API."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from deeptutor.analytics.emit import emit_domain_event
from deeptutor.services.revision import list_due_cards, review_card

router = APIRouter()


class ReviewBody(BaseModel):
    card_id: str = Field(min_length=8, max_length=64)
    grade: str = Field(min_length=3, max_length=8)


@router.get("/queue")
async def revision_queue(limit: int = 20) -> dict:
    items = list_due_cards(limit=limit)
    return {"items": items, "count": len(items)}


@router.post("/review")
async def revision_review(body: ReviewBody) -> dict:
    g = body.grade.strip().lower()
    if g not in {"again", "good", "easy"}:
        raise HTTPException(status_code=400, detail="grade must be again|good|easy")
    updated = review_card(body.card_id, g)
    if updated is None:
        raise HTTPException(status_code=404, detail="card not found")
    emit_domain_event(
        "RevisionReviewed",
        subject_type="RevisionCard",
        subject_id=body.card_id,
        payload={"grade": g, "topic": updated.get("topic"), "next_due_ms": updated.get("due_at_ms")},
    )
    return {"card": updated}


__all__ = ["router"]
