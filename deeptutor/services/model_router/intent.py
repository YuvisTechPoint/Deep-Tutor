"""Lightweight rule + keyword intent detector for model routing.

Falls back to LLM-based classification only for ambiguous cases.
"""
from __future__ import annotations

from enum import Enum
import re


class Intent(str, Enum):
    CODING = "coding"
    MATH = "math"
    VISION = "vision"
    OCR = "ocr"
    SPEECH = "speech"
    SAFETY = "safety"
    CAREER = "career"
    ASSESSMENT = "assessment"
    GENERAL = "general"


# Ordered patterns — first match wins
_CODING_PATTERNS = re.compile(
    r"\b("
    r"python|javascript|typescript|java|c\+\+|c#|rust|golang|kotlin|swift|ruby|php"
    r"|code|coding|debug|debugg|function|class|algorithm|dsa|leetcode|array|linked.?list"
    r"|binary.?tree|graph|stack|queue|sorting|recursion|dynamic.?programming|dp problem"
    r"|implement|refactor|unit.?test|api.?call|async.?await|lambda|closure"
    r"|compile.?error|syntax.?error|runtime.?error|import|module|library|framework"
    r"|react|vue|angular|django|flask|fastapi|spring|express|node\.?js|nest\.?js"
    r"|sql|mongodb|redis|docker|kubernetes|git|github"
    r")\b",
    re.IGNORECASE,
)

_MATH_PATTERNS = re.compile(
    r"\b("
    r"derivative|integral|calculus|algebra|geometry|trigonometry|matrix|vector"
    r"|probability|statistics|equation|inequality|theorem|proof|limit|series|sequence"
    r"|eigenvalue|differential|polynomial|logarithm|exponential|factorial"
    r"|solve for|simplify|expand|factorise|factorize"
    r"|aptitude|reasoning|quantitative|arithmetic|number.?system"
    r")\b",
    re.IGNORECASE,
)

_VISION_PATTERNS = re.compile(
    r"\b("
    r"image|photo|picture|diagram|chart|graph|screenshot|whiteboard|sketch"
    r"|what.{0,20}(see|show|display|in this|image|photo)"
    r"|explain.{0,20}(image|diagram|chart|figure)"
    r"|describe.{0,20}(image|picture)"
    r")\b",
    re.IGNORECASE,
)

_CAREER_PATTERNS = re.compile(
    r"\b("
    r"career|job|resume|cv|interview|roadmap|skill.?gap|salary|hiring|recruiter"
    r"|job.?ready|placement|internship|portfolio|linkedin|promotion|role|position"
    r"|company|startup|faang|sde|data.?scientist|ml.?engineer"
    r")\b",
    re.IGNORECASE,
)

_ASSESSMENT_PATTERNS = re.compile(
    r"\b("
    r"quiz|test|exam|assessment|mcq|question|evaluate|practice|mock|score"
    r"|jee|neet|gate|gre|gmat|sat|upsc|cat|toefl|ielts|competitive"
    r"|rank|performance|mastery|weak.?topic|revision"
    r")\b",
    re.IGNORECASE,
)


def detect_intent(text: str, has_image: bool = False) -> Intent:
    """Classify query intent with keyword heuristics (no LLM call)."""
    if has_image:
        return Intent.VISION

    if _CODING_PATTERNS.search(text):
        return Intent.CODING

    if _MATH_PATTERNS.search(text):
        return Intent.MATH

    if _CAREER_PATTERNS.search(text):
        return Intent.CAREER

    if _ASSESSMENT_PATTERNS.search(text):
        return Intent.ASSESSMENT

    if _VISION_PATTERNS.search(text):
        return Intent.VISION

    return Intent.GENERAL


def adjust_intent_with_learning_profile(
    intent: Intent,
    profile: dict | None,
) -> Intent:
    """Bias coarse intent using onboarding goals / path (blueprint ch 39)."""
    if not profile or intent not in (Intent.GENERAL, Intent.ASSESSMENT):
        return intent
    blob = " ".join(
        [
            str(profile.get("target_path", "")),
            " ".join(profile.get("goals") or []),
            " ".join(profile.get("preparing_for") or []),
            str(profile.get("experience_level", "")),
        ]
    ).lower()
    exam_markers = (
        "exam",
        "gate",
        "gre",
        "gmat",
        "sat",
        "upsc",
        "cat",
        "jee",
        "neet",
        "toefl",
        "ielts",
        "certification",
    )
    if intent == Intent.GENERAL and any(m in blob for m in exam_markers):
        return Intent.ASSESSMENT
    code_markers = (
        "job",
        "interview",
        "career",
        "leetcode",
        "dsa",
        "developer",
        "coding",
        "system design",
    )
    if intent == Intent.GENERAL and any(m in blob for m in code_markers):
        return Intent.CODING
    return intent
