"""Session drafts and pre-session request queue for live calendar sessions."""

from __future__ import annotations

import re
from typing import Any, Literal

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field, field_validator

from deeptutor.multi_user.context import get_current_user
from deeptutor.multi_user.identity import get_user_by_id
from deeptutor.services.live_session_prep.notify import (
    notify_current_user,
    notify_mentor_staff,
    notify_user_by_id,
)
from deeptutor.services.live_session_prep.store import (
    DraftRow,
    RequestRow,
    get_live_session_prep_store,
    is_past_session_start,
)

router = APIRouter()

MAX_TOPIC = 200
MAX_NOTE = 5000
MAX_ITEM = 500
MAX_ITEMS = 24
MAX_TITLE = 200
MAX_DESC = 4000
MAX_ATTACH = 32

DraftStatus = Literal["draft", "ready", "submitted"]
IntentType = Literal[
    "doubt",
    "concept_clarification",
    "code_review",
    "career_advice",
    "project_help",
    "other",
]
Priority = Literal["high", "medium", "low"]
MentorStatus = Literal["open", "reviewed", "planned", "answered", "deferred"]


def _is_staff(role: str) -> bool:
    return role in {"admin", "mentor", "institution"}


def _trim_lines(raw: list[str], *, max_each: int, max_count: int) -> list[str]:
    out: list[str] = []
    for line in raw[:max_count]:
        s = str(line).strip()
        if not s:
            continue
        out.append(s[:max_each])
    return out


def _validate_attachment_list(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    if len(items) > MAX_ATTACH:
        raise ValueError(f"At most {MAX_ATTACH} attachments")
    cleaned: list[dict[str, Any]] = []
    for it in items:
        if not isinstance(it, dict):
            continue
        kind = str(it.get("type") or it.get("kind") or "link")
        if kind == "link":
            href = str(it.get("href") or it.get("url") or "").strip()
            if not href or len(href) > 2000:
                continue
            label = str(it.get("label") or "")[:200]
            cleaned.append({"type": "link", "href": href, "label": label})
    return cleaned


class AttachmentItem(BaseModel):
    type: Literal["link"] = "link"
    href: str = Field(min_length=1, max_length=2000)
    label: str = Field(default="", max_length=200)


class DraftCreate(BaseModel):
    session_id: str = Field(min_length=1, max_length=128)
    topic: str = Field(min_length=1, max_length=MAX_TOPIC)
    goals: list[str] = Field(default_factory=list)
    questions: list[str] = Field(default_factory=list)
    notes: str = Field(default="", max_length=MAX_NOTE)
    attachments: list[AttachmentItem] = Field(default_factory=list)
    status: DraftStatus = "draft"

    @field_validator("session_id")
    @classmethod
    def session_id_safe(cls, v: str) -> str:
        v = v.strip()
        if not re.match(r"^[A-Za-z0-9_.\-]{1,128}$", v):
            raise ValueError("session_id must be alphanumeric (dots, dashes, underscores allowed)")
        return v


class DraftPatch(BaseModel):
    topic: str | None = Field(default=None, min_length=1, max_length=MAX_TOPIC)
    goals: list[str] | None = None
    questions: list[str] | None = None
    notes: str | None = Field(default=None, max_length=MAX_NOTE)
    attachments: list[AttachmentItem] | None = None
    status: DraftStatus | None = None


class PreSessionCreate(BaseModel):
    session_id: str = Field(min_length=1, max_length=128)
    draft_id: str | None = Field(default=None, max_length=80)
    title: str = Field(min_length=1, max_length=MAX_TITLE)
    description: str = Field(min_length=1, max_length=MAX_DESC)
    intent_type: IntentType
    priority: Priority = "medium"
    anonymous: bool = False
    attachments: list[AttachmentItem] = Field(default_factory=list)
    live_session_starts_at: str | None = Field(default=None, max_length=64)

    @field_validator("session_id")
    @classmethod
    def session_id_safe(cls, v: str) -> str:
        v = v.strip()
        if not re.match(r"^[A-Za-z0-9_.\-]{1,128}$", v):
            raise ValueError("session_id must be alphanumeric (dots, dashes, underscores allowed)")
        return v


class PreSessionPatch(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=MAX_TITLE)
    description: str | None = Field(default=None, min_length=1, max_length=MAX_DESC)
    intent_type: IntentType | None = None
    priority: Priority | None = None
    anonymous: bool | None = None
    draft_id: str | None = None
    attachments: list[AttachmentItem] | None = None
    live_session_starts_at: str | None = Field(default=None, max_length=64)


class MentorStatusBody(BaseModel):
    mentor_status: MentorStatus


class ReorderBody(BaseModel):
    session_id: str = Field(min_length=1, max_length=128)
    ordered_ids: list[str] = Field(min_length=1)

    @field_validator("session_id")
    @classmethod
    def session_id_safe(cls, v: str) -> str:
        v = v.strip()
        if not re.match(r"^[A-Za-z0-9_.\-]{1,128}$", v):
            raise ValueError("invalid session_id")
        return v


def _draft_payload(row: DraftRow) -> dict[str, Any]:
    return {
        "id": row.id,
        "user_id": row.user_id,
        "session_id": row.session_id,
        "topic": row.topic,
        "goals": row.goals,
        "questions": row.questions,
        "notes": row.notes,
        "attachments": row.attachments,
        "status": row.status,
        "created_at": row.created_at,
        "updated_at": row.updated_at,
    }


def _request_public(
    row: RequestRow,
    *,
    viewer_is_staff: bool,
    viewer_user_id: str | None = None,
    username_by_id: dict[str, str] | None = None,
) -> dict[str, Any]:
    display_name = row.student_username or row.user_id
    if username_by_id and row.user_id in username_by_id:
        display_name = username_by_id[row.user_id]
    if row.anonymous:
        if viewer_user_id == row.user_id:
            display_name = f"{row.student_username} (anonymous to mentors)"
        elif viewer_is_staff:
            display_name = f"Anonymous ({row.user_id})"
        else:
            display_name = "Anonymous"
    base: dict[str, Any] = {
        "id": row.id,
        "session_id": row.session_id,
        "draft_id": row.draft_id,
        "title": row.title,
        "description": row.description,
        "intent_type": row.intent_type,
        "priority": row.priority,
        "anonymous": row.anonymous,
        "mentor_status": row.mentor_status,
        "queue_position": row.queue_position,
        "attachments": row.attachments,
        "live_session_starts_at": row.live_session_starts_at,
        "locked": is_past_session_start(row.live_session_starts_at),
        "created_at": row.created_at,
        "updated_at": row.updated_at,
        "student_display": display_name,
        "user_id": row.user_id,
    }
    if viewer_is_staff:
        base["student_username"] = row.student_username
    return base


def _validate_draft_content(
    *,
    topic: str,
    goals: list[str],
    questions: list[str],
    require_goals_or_questions: bool,
) -> None:
    _ = topic
    if require_goals_or_questions and not goals and not questions:
        raise HTTPException(
            status_code=422,
            detail="Add at least one learning goal or one question",
        )


@router.get("/session-drafts")
async def list_drafts(
    session_id: str | None = Query(default=None, max_length=128),
) -> dict[str, Any]:
    user = get_current_user()
    rows = get_live_session_prep_store().list_drafts(user_id=user.id, session_id=session_id)
    return {"items": [_draft_payload(r) for r in rows]}


@router.post("/session-drafts")
async def create_draft(body: DraftCreate) -> dict[str, Any]:
    user = get_current_user()
    goals = _trim_lines(body.goals, max_each=MAX_ITEM, max_count=MAX_ITEMS)
    questions = _trim_lines(body.questions, max_each=MAX_ITEM, max_count=MAX_ITEMS)
    _validate_draft_content(
        topic=body.topic,
        goals=goals,
        questions=questions,
        require_goals_or_questions=True,
    )
    attachments = _validate_attachment_list([a.model_dump() for a in body.attachments])
    row = get_live_session_prep_store().create_draft(
        user_id=user.id,
        session_id=body.session_id.strip(),
        topic=body.topic.strip(),
        goals=goals,
        questions=questions,
        notes=body.notes.strip(),
        attachments=attachments,
        status=body.status,
    )
    notify_current_user(
        {
            "type": "live_session_draft",
            "title": "Draft saved",
            "message": f"Your preparation draft for session {body.session_id} was saved.",
            "action_label": "Open calendar",
            "action_href": "/calendar",
            "metadata": {"draft_id": row.id, "session_id": body.session_id},
        }
    )
    return _draft_payload(row)


@router.get("/session-drafts/{draft_id}")
async def get_draft(draft_id: str) -> dict[str, Any]:
    user = get_current_user()
    row = get_live_session_prep_store().get_draft(draft_id)
    if row is None or row.user_id != user.id:
        raise HTTPException(status_code=404, detail="Draft not found")
    return _draft_payload(row)


@router.patch("/session-drafts/{draft_id}")
async def patch_draft(draft_id: str, body: DraftPatch) -> dict[str, Any]:
    user = get_current_user()
    store = get_live_session_prep_store()
    existing = store.get_draft(draft_id)
    if existing is None or existing.user_id != user.id:
        raise HTTPException(status_code=404, detail="Draft not found")
    if existing.status == "submitted":
        raise HTTPException(status_code=400, detail="Submitted drafts cannot be edited")
    goals = (
        _trim_lines(body.goals, max_each=MAX_ITEM, max_count=MAX_ITEMS)
        if body.goals is not None
        else None
    )
    questions = (
        _trim_lines(body.questions, max_each=MAX_ITEM, max_count=MAX_ITEMS)
        if body.questions is not None
        else None
    )
    eff_goals = goals if goals is not None else existing.goals
    eff_questions = questions if questions is not None else existing.questions
    eff_topic = body.topic.strip() if body.topic is not None else existing.topic
    _validate_draft_content(
        topic=eff_topic,
        goals=eff_goals,
        questions=eff_questions,
        require_goals_or_questions=True,
    )
    attachments: list[dict[str, Any]] | None = None
    if body.attachments is not None:
        attachments = _validate_attachment_list([a.model_dump() for a in body.attachments])
    row = store.update_draft(
        draft_id,
        user_id=user.id,
        topic=body.topic.strip() if body.topic is not None else None,
        goals=goals,
        questions=questions,
        notes=body.notes if body.notes is not None else None,
        attachments=attachments,
        status=body.status,
    )
    if row is None:
        raise HTTPException(status_code=400, detail="Update failed")
    return _draft_payload(row)


@router.delete("/session-drafts/{draft_id}")
async def delete_draft(draft_id: str) -> dict[str, Any]:
    user = get_current_user()
    ok = get_live_session_prep_store().delete_draft(draft_id, user_id=user.id)
    if not ok:
        raise HTTPException(status_code=404, detail="Draft not found")
    return {"deleted": True, "id": draft_id}


@router.post("/session-drafts/{draft_id}/mark-ready")
async def mark_ready(draft_id: str) -> dict[str, Any]:
    user = get_current_user()
    store = get_live_session_prep_store()
    existing = store.get_draft(draft_id)
    if existing is None or existing.user_id != user.id:
        raise HTTPException(status_code=404, detail="Draft not found")
    if existing.status == "submitted":
        raise HTTPException(status_code=400, detail="Submitted drafts cannot change status")
    _validate_draft_content(
        topic=existing.topic,
        goals=existing.goals,
        questions=existing.questions,
        require_goals_or_questions=True,
    )
    row = store.update_draft(draft_id, user_id=user.id, status="ready")
    if row is None:
        raise HTTPException(status_code=404, detail="Draft not found or not editable")
    return _draft_payload(row)


@router.post("/session-drafts/{draft_id}/submit")
async def submit_draft(draft_id: str) -> dict[str, Any]:
    user = get_current_user()
    store = get_live_session_prep_store()
    existing = store.get_draft(draft_id)
    if existing is None or existing.user_id != user.id:
        raise HTTPException(status_code=404, detail="Draft not found")
    _validate_draft_content(
        topic=existing.topic,
        goals=existing.goals,
        questions=existing.questions,
        require_goals_or_questions=True,
    )
    row = store.update_draft(draft_id, user_id=user.id, status="submitted")
    if row is None:
        raise HTTPException(status_code=400, detail="Could not submit draft")
    notify_current_user(
        {
            "type": "live_session_draft",
            "title": "Draft submitted",
            "message": "Your draft is marked as submitted for this session.",
            "metadata": {"draft_id": row.id, "session_id": row.session_id},
        }
    )
    return _draft_payload(row)


@router.post("/pre-session-requests")
async def create_pre_session(body: PreSessionCreate) -> dict[str, Any]:
    user = get_current_user()
    attachments = _validate_attachment_list([a.model_dump() for a in body.attachments])
    row = get_live_session_prep_store().create_request(
        user_id=user.id,
        session_id=body.session_id.strip(),
        draft_id=body.draft_id.strip() if body.draft_id else None,
        title=body.title.strip(),
        description=body.description.strip(),
        intent_type=body.intent_type,
        priority=body.priority,
        anonymous=body.anonymous,
        attachments=attachments,
        live_session_starts_at=body.live_session_starts_at,
        student_username=user.username,
    )
    if row is None:
        raise HTTPException(status_code=400, detail="Invalid draft reference")
    notify_current_user(
        {
            "type": "live_session_queue",
            "title": "Pre-session request submitted",
            "message": f"“{row.title}” is in the mentor queue.",
            "metadata": {"request_id": row.id, "session_id": row.session_id},
        }
    )
    notify_mentor_staff(
        {
            "type": "live_session_queue",
            "title": "New pre-session request",
            "message": f"{user.username}: {row.title}",
            "action_label": "Review queue",
            "action_href": "/mentor/pre-session",
            "metadata": {"request_id": row.id, "session_id": row.session_id},
        }
    )
    return _request_public(row, viewer_is_staff=False, viewer_user_id=user.id)


@router.get("/pre-session-requests")
async def list_pre_session_requests(
    session_id: str | None = Query(default=None, max_length=128),
    priority: Priority | None = Query(default=None),
    intent_type: IntentType | None = Query(default=None),
    search: str | None = Query(default=None, max_length=200),
) -> dict[str, Any]:
    user = get_current_user()
    store = get_live_session_prep_store()
    if _is_staff(user.role):
        rows = store.list_requests_mentor(
            session_id=session_id,
            priority=priority,
            intent_type=intent_type,
            search=search,
        )
        names: dict[str, str] = {}
        for r in rows:
            pair = get_user_by_id(r.user_id)
            if pair:
                names[r.user_id] = pair[0]
        return {
            "items": [
                _request_public(
                    r,
                    viewer_is_staff=True,
                    viewer_user_id=user.id,
                    username_by_id=names,
                )
                for r in rows
            ]
        }
    rows = store.list_requests_for_student(user_id=user.id, session_id=session_id)
    return {
        "items": [
            _request_public(r, viewer_is_staff=False, viewer_user_id=user.id) for r in rows
        ]
    }


@router.get("/pre-session-requests/{request_id}")
async def get_pre_session_request(request_id: str) -> dict[str, Any]:
    user = get_current_user()
    store = get_live_session_prep_store()
    row = store.get_request(request_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Request not found")
    if _is_staff(user.role):
        pair = get_user_by_id(row.user_id)
        names = {row.user_id: pair[0]} if pair else {}
        return _request_public(
            row,
            viewer_is_staff=True,
            viewer_user_id=user.id,
            username_by_id=names,
        )
    if row.user_id != user.id:
        raise HTTPException(status_code=404, detail="Request not found")
    return _request_public(row, viewer_is_staff=False, viewer_user_id=user.id)


@router.patch("/pre-session-requests/{request_id}")
async def patch_pre_session(request_id: str, body: PreSessionPatch) -> dict[str, Any]:
    user = get_current_user()
    store = get_live_session_prep_store()
    existing = store.get_request(request_id)
    if existing is None or existing.user_id != user.id:
        raise HTTPException(status_code=404, detail="Request not found")
    if is_past_session_start(existing.live_session_starts_at):
        raise HTTPException(status_code=400, detail="Session has started; edits are locked")
    attachments = (
        _validate_attachment_list([a.model_dump() for a in body.attachments])
        if body.attachments is not None
        else None
    )
    update_draft_id = body.draft_id is not None
    draft_val: str | None = None
    if update_draft_id:
        raw = body.draft_id or ""
        draft_val = raw.strip() if raw.strip() else None
    row = store.update_request_student(
        request_id,
        user_id=user.id,
        title=body.title.strip() if body.title is not None else None,
        description=body.description.strip() if body.description is not None else None,
        intent_type=body.intent_type,
        priority=body.priority,
        anonymous=body.anonymous,
        draft_id=draft_val,
        update_draft_id=update_draft_id,
        attachments=attachments,
        live_session_starts_at=body.live_session_starts_at,
    )
    if row is None:
        raise HTTPException(status_code=400, detail="Update failed")
    return _request_public(row, viewer_is_staff=False, viewer_user_id=user.id)


@router.patch("/pre-session-requests/{request_id}/mentor")
async def mentor_update_request(request_id: str, body: MentorStatusBody) -> dict[str, Any]:
    user = get_current_user()
    if not _is_staff(user.role):
        raise HTTPException(status_code=403, detail="Mentor or admin access required")
    store = get_live_session_prep_store()
    prev = store.get_request(request_id)
    if prev is None:
        raise HTTPException(status_code=404, detail="Request not found")
    row = store.update_request_mentor(request_id, mentor_status=body.mentor_status)
    if row is None:
        raise HTTPException(status_code=404, detail="Request not found")
    if (
        body.mentor_status == "reviewed"
        and prev.mentor_status != "reviewed"
        and prev.user_id
    ):
        pair = get_user_by_id(prev.user_id)
        role = str(pair[1].get("role") or "student") if pair else "student"
        notify_user_by_id(
            prev.user_id,
            role=role,
            payload={
                "type": "live_session_queue",
                "title": "Mentor reviewed your request",
                "message": f"“{prev.title}” was marked reviewed.",
                "metadata": {"request_id": request_id, "session_id": prev.session_id},
            },
        )
    pair = get_user_by_id(row.user_id)
    names = {row.user_id: pair[0]} if pair else {}
    return _request_public(
        row,
        viewer_is_staff=True,
        viewer_user_id=user.id,
        username_by_id=names,
    )


@router.post("/pre-session-requests/reorder")
async def reorder_pre_session(body: ReorderBody) -> dict[str, Any]:
    user = get_current_user()
    if not _is_staff(user.role):
        raise HTTPException(status_code=403, detail="Mentor or admin access required")
    ok = get_live_session_prep_store().reorder_requests(
        session_id=body.session_id.strip(),
        ordered_ids=body.ordered_ids,
    )
    if not ok:
        raise HTTPException(
            status_code=400,
            detail="Reorder set must match all requests for this session",
        )
    return {"ok": True}


__all__ = ["router"]
