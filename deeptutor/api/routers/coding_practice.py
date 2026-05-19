"""Coding practice lab — multi-language problems, compile/run, XP + streaks."""

from __future__ import annotations

import asyncio
import logging
import os
import shutil
import time
from typing import Any

from fastapi import APIRouter, Body, Header, HTTPException, Query
from pydantic import BaseModel, Field

from deeptutor.analytics.emit import emit_domain_event
from deeptutor.services.coding_practice import (
    CodingProblemEntry,
    drop_problem,
    generate_problem,
    get_problem,
    normalize_coding_language,
    run_tests,
    store_problem,
)
from deeptutor.services.coding_practice.generator import _offline_problem
from deeptutor.services.coding_practice.proctoring import (
    BLACKLIST_CONSECUTIVE_THRESHOLD,
    code_lab_dev_bypass_enabled,
    get_exam_guard_store,
)
from deeptutor.services.coding_practice.toolchains import get_toolchain_status, require_toolchain
from deeptutor.services.gamification import get_gamification_store
from deeptutor.services.path_service import get_path_service

logger = logging.getLogger(__name__)

router = APIRouter()


def _guard_blacklisted() -> None:
    try:
        get_exam_guard_store().assert_not_blacklisted()
    except PermissionError as exc:
        raise HTTPException(
            status_code=403,
            detail=(
                "You are blacklisted from Code lab after repeated exam integrity "
                "violations. Contact an administrator."
            ),
        ) from exc


class ProblemResponse(BaseModel):
    problem_id: str
    title: str
    description: str
    starter_code: str
    topic: str
    difficulty: str
    language: str
    entrypoint: str
    sample_tests: list[dict[str, Any]] = Field(
        default_factory=list,
        description="First example cases (args + expected); full suite is hidden until submit.",
    )
    hints: list[str]
    offline: bool = Field(
        default=False,
        description="True when served from the curated offline bank (LLM unavailable).",
    )


class RunRequest(BaseModel):
    problem_id: str = Field(min_length=4, max_length=80)
    code: str = Field(min_length=1, max_length=120_000)


class SubmitRequest(BaseModel):
    problem_id: str = Field(min_length=4, max_length=80)
    code: str = Field(min_length=1, max_length=120_000)
    solve_seconds: int | None = Field(
        default=None,
        ge=0,
        le=86_400,
        description="Optional client-side solve timer in seconds (analytics only).",
    )


class TestCaseResult(BaseModel):
    ok: bool
    index: int
    got: str | None = None
    expected: str | None = None
    error: str | None = None


class RunResponse(BaseModel):
    stdout: str
    stderr: str
    exit_code: int
    elapsed_ms: float
    all_passed: bool = False
    tests: list[TestCaseResult] = Field(default_factory=list)


class SubmitResponse(BaseModel):
    all_passed: bool
    awarded_xp: int
    tests: list[TestCaseResult]
    stdout: str
    stderr: str
    exit_code: int
    streak_current: int
    total_xp: int
    solve_seconds: int | None = None


class ExamStatusResponse(BaseModel):
    blacklisted: bool
    consecutive_violations: int
    violations_until_blacklist: int
    active: bool
    session_id: str | None = None
    warning_message: str | None = None
    blacklist_threshold: int = BLACKLIST_CONSECUTIVE_THRESHOLD


class ExamStartRequest(BaseModel):
    problem_id: str | None = Field(default=None, max_length=80)


class ExamStartResponse(ExamStatusResponse):
    session_id: str


class ExamViolationRequest(BaseModel):
    session_id: str = Field(min_length=8, max_length=64)
    reason: str = Field(min_length=3, max_length=40)


class ExamViolationResponse(ExamStatusResponse):
    new_violation: bool = False
    reason: str | None = None
    just_blacklisted: bool = False


class ExamEndRequest(BaseModel):
    session_id: str = Field(min_length=8, max_length=64)
    submitted: bool = False


@router.get("/toolchains")
async def toolchains() -> dict:
    """Report which compilers/interpreters are available for each Code lab language."""
    return get_toolchain_status()


@router.get("/exam/status", response_model=ExamStatusResponse)
async def exam_status() -> ExamStatusResponse:
    return ExamStatusResponse(**get_exam_guard_store().get_status().to_dict())


@router.post("/exam/start", response_model=ExamStartResponse)
async def exam_start(
    body: ExamStartRequest = Body(default_factory=ExamStartRequest),
) -> ExamStartResponse:
    _guard_blacklisted()
    pid = body.problem_id
    out = get_exam_guard_store().start_session(problem_id=pid)
    return ExamStartResponse(**out)


@router.post("/exam/violation", response_model=ExamViolationResponse)
async def exam_violation(body: ExamViolationRequest) -> ExamViolationResponse:
    store = get_exam_guard_store()
    allowed = {
        "tab_hidden",
        "fullscreen_exit",
        "window_blur",
        "navigation_attempt",
        "copy_attempt",
        "paste_attempt",
        "context_menu",
        "devtools_hotkey",
        "selection_blocked",
    }
    if body.reason not in allowed:
        raise HTTPException(status_code=400, detail="invalid violation reason")
    try:
        out = store.record_violation(body.session_id, body.reason)  # type: ignore[arg-type]
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return ExamViolationResponse(**out)


@router.post("/exam/end", response_model=ExamStatusResponse)
async def exam_end(body: ExamEndRequest) -> ExamStatusResponse:
    out = get_exam_guard_store().end_session(body.session_id, submitted=body.submitted)
    return ExamStatusResponse(**out)


@router.post("/exam/dev/clear-blacklist", response_model=ExamStatusResponse)
async def exam_dev_clear_blacklist() -> ExamStatusResponse:
    """Clear Code lab suspension for local testing (disabled in production by default)."""
    if not code_lab_dev_bypass_enabled():
        raise HTTPException(
            status_code=403,
            detail="Code lab dev bypass is disabled. Set DEEPTUTOR_CODE_LAB_DEV_BYPASS=1 to enable.",
        )
    out = get_exam_guard_store().clear_blacklist_for_testing()
    return ExamStatusResponse(**out)


def _parse_test_rows(raw_tests: list[Any]) -> list[TestCaseResult]:
    parsed: list[TestCaseResult] = []
    for i, row in enumerate(raw_tests):
        if not isinstance(row, dict):
            continue
        parsed.append(
            TestCaseResult(
                ok=bool(row.get("ok")),
                index=int(row.get("index", i)),
                got=row.get("got") if row.get("got") is not None else None,
                expected=row.get("expected") if row.get("expected") is not None else None,
                error=row.get("error") if row.get("error") is not None else None,
            )
        )
    return parsed


def _build_problem_response(raw: dict[str, Any], lang: str) -> ProblemResponse:
    pid = str(raw["problem_id"])
    entry = CodingProblemEntry(
        problem_id=pid,
        title=str(raw["title"]),
        description=str(raw["description"]),
        starter_code=str(raw["starter_code"]),
        entrypoint=str(raw["entrypoint"]),
        tests=list(raw["tests"]),
        hints=list(raw.get("hints") or []),
        topic=str(raw.get("topic") or "python"),
        difficulty=str(raw.get("difficulty") or "medium"),
        created_at=0.0,
        language=str(raw.get("language") or lang),
        offline=bool(raw.get("offline")),
    )
    store_problem(entry)
    sample: list[dict[str, Any]] = []
    for row in entry.tests[:2]:
        if isinstance(row, dict) and "args" in row and "expected" in row:
            sample.append({"args": row["args"], "expected": row["expected"]})
    return ProblemResponse(
        problem_id=pid,
        title=entry.title,
        description=entry.description,
        starter_code=entry.starter_code,
        topic=entry.topic,
        difficulty=entry.difficulty,
        hints=entry.hints,
        language=entry.language,
        entrypoint=entry.entrypoint,
        sample_tests=sample,
        offline=entry.offline,
    )


def _offline_problem_response(
    *,
    lang: str,
    topic: str | None,
    difficulty: str | None,
    refresh_nonce: str | None,
) -> ProblemResponse:
    raw = _offline_problem(
        lang,
        (topic or "algorithms").strip().lower() or "algorithms",
        (difficulty or "medium").strip().lower() or "medium",
        refresh_token=refresh_nonce,
    )
    return _build_problem_response(raw, lang)


@router.get("/problem", response_model=ProblemResponse)
async def fetch_problem(
    topic: str | None = None,
    difficulty: str | None = Query(default="medium"),
    language: str | None = Query(default="python"),
    nonce: str | None = Query(default=None, max_length=64),
) -> ProblemResponse:
    _guard_blacklisted()
    lang = normalize_coding_language(language)
    refresh_nonce = (nonce or "").strip() or None
    timeout_seconds = float(os.getenv("CODE_LAB_GENERATION_TIMEOUT_SEC", "15").strip() or 15)
    try:
        raw = await asyncio.wait_for(
            generate_problem(
                topic=topic,
                difficulty=difficulty,
                language=lang,
                refresh_nonce=refresh_nonce,
            ),
            timeout=timeout_seconds,
        )
    except Exception as exc:
        if isinstance(exc, asyncio.TimeoutError):
            logger.warning(
                "coding problem generation timed out after %ss; serving offline fallback",
                timeout_seconds,
            )
        else:
            logger.warning("coding problem generation failed; serving offline fallback: %s", exc)
        return _offline_problem_response(
            lang=lang,
            topic=topic,
            difficulty=difficulty,
            refresh_nonce=refresh_nonce,
        )

    return _build_problem_response(raw, lang)


@router.post("/run", response_model=RunResponse)
async def run_code_only(body: RunRequest) -> RunResponse:
    """Run learner code against visible sample tests (same harness as submit)."""
    _guard_blacklisted()
    entry = get_problem(body.problem_id)
    if entry is None:
        raise HTTPException(
            status_code=410,
            detail="Problem expired or unknown. Fetch a new problem.",
        )
    sample_tests = [t for t in entry.tests[:2] if isinstance(t, dict)]
    if not sample_tests:
        sample_tests = [t for t in entry.tests if isinstance(t, dict)]
    require_toolchain(entry.language)
    try:
        outcome = await run_tests(
            body.code.strip(),
            entrypoint=entry.entrypoint,
            tests=sample_tests,
            language=entry.language,
            timeout=12,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    raw_tests = outcome.get("tests") or []
    parsed = _parse_test_rows(raw_tests if isinstance(raw_tests, list) else [])
    all_passed = bool(outcome.get("ok")) and bool(parsed) and all(t.ok for t in parsed)
    return RunResponse(
        stdout=str(outcome.get("stdout") or ""),
        stderr=str(outcome.get("stderr") or ""),
        exit_code=int(outcome.get("exit_code") or (-1 if not all_passed else 0)),
        elapsed_ms=float(outcome.get("elapsed_ms") or 0.0),
        all_passed=all_passed,
        tests=parsed,
    )


@router.post("/submit", response_model=SubmitResponse)
async def submit_solution(body: SubmitRequest) -> SubmitResponse:
    _guard_blacklisted()
    entry = get_problem(body.problem_id)
    if entry is None:
        raise HTTPException(
            status_code=410,
            detail="Problem expired or unknown. Fetch a new problem.",
        )
    require_toolchain(entry.language)
    try:
        outcome = await run_tests(
            body.code.strip(),
            entrypoint=entry.entrypoint,
            tests=entry.tests,
            language=entry.language,
            timeout=15,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    raw_tests = outcome.get("tests") or []
    parsed = _parse_test_rows(raw_tests if isinstance(raw_tests, list) else [])

    all_passed = bool(outcome.get("ok")) and bool(parsed) and all(t.ok for t in parsed)
    awarded = 0
    store = get_gamification_store()

    if all_passed:
        awarded = 130
        meta: dict[str, Any] = {
            "problem_id": entry.problem_id,
            "topic": entry.topic,
            "difficulty": entry.difficulty,
            "language": entry.language,
            "entrypoint": entry.entrypoint,
            "tests_passed": len(parsed),
        }
        if body.solve_seconds is not None:
            meta["solve_seconds"] = int(body.solve_seconds)
        store.award(
            action="coding_practice.solve",
            xp=awarded,
            source=f"coding_practice:{entry.topic}",
            metadata=meta,
        )
        drop_problem(entry.problem_id)
        ev_payload: dict[str, Any] = {
            "topic": entry.topic,
            "difficulty": entry.difficulty,
            "awarded_xp": awarded,
        }
        if body.solve_seconds is not None:
            ev_payload["solve_seconds"] = int(body.solve_seconds)
        emit_domain_event(
            "CodingProblemSolved",
            subject_type="CodingPractice",
            subject_id=entry.problem_id,
            payload=ev_payload,
        )
        try:
            from deeptutor.api.routers.career_refresh import schedule_career_refresh

            schedule_career_refresh(
                "coding_solved",
                awarded_xp=awarded,
                topic=entry.topic,
            )
        except Exception:
            pass

    state = store.get_state()
    return SubmitResponse(
        all_passed=all_passed,
        awarded_xp=awarded,
        tests=parsed,
        stdout=str(outcome.get("stdout") or ""),
        stderr=str(outcome.get("stderr") or ""),
        exit_code=int(outcome.get("exit_code") or -1),
        streak_current=int(state.get("streak_current") or 0),
        total_xp=int(state.get("total_xp") or 0),
        solve_seconds=int(body.solve_seconds) if all_passed and body.solve_seconds is not None else None,
    )


__all__ = ["router"]


@router.post("/cache/cleanup")
async def cleanup_compile_cache(
    days: int | None = Query(default=30, ge=1, le=365),
    x_admin_token: str | None = Header(default=None, convert_underscores=False),
) -> dict:
    """Purge compile cache entries older than `days` days.

    This endpoint is intended for administrative maintenance. If the environment
    variable `DEEPTUTOR_ADMIN_TOKEN` is set, callers must provide the same value
    in the `X-Admin-Token` header. Otherwise the endpoint is allowed only when
    `DEEPTUTOR_CODE_LAB_DEV_BYPASS` is enabled.
    """
    # Admin token gating
    admin_tok = (os.environ.get("DEEPTUTOR_ADMIN_TOKEN") or "").strip()
    dev_bypass = code_lab_dev_bypass_enabled()
    if admin_tok:
        if not x_admin_token or x_admin_token != admin_tok:
            raise HTTPException(status_code=403, detail="Invalid admin token")
    else:
        if not dev_bypass:
            raise HTTPException(
                status_code=403,
                detail="Cache cleanup is restricted. Set DEEPTUTOR_ADMIN_TOKEN or enable dev bypass.",
            )

    ps = get_path_service()
    root = ps.get_user_root() / "coding_cache"
    if not root.exists():
        return {"deleted": 0, "checked": 0}
    cutoff = time.time() - float(days) * 24.0 * 3600.0
    deleted = 0
    checked = 0
    for child in list(root.iterdir()):
        try:
            if not child.is_dir():
                continue
            checked += 1
            mtime = child.stat().st_mtime
            if mtime < cutoff:
                shutil.rmtree(child)
                deleted += 1
        except Exception:
            logger.exception("Failed to inspect or remove cache entry: %s", child)
    return {"deleted": deleted, "checked": checked}
