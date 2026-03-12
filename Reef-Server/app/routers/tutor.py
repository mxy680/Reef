"""POST /ai/evaluate-step — evaluate student work on a tutor step."""

import asyncio
import json
import logging
import re

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.services.llm_client import LLMClient
from app.services.prompts import TUTOR_EVALUATE_PROMPT

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["tutor"])

TUTOR_EVAL_MODEL = "google/gemini-3-flash-preview"


class StepInfo(BaseModel):
    description: str
    work: str


class EvaluateStepRequest(BaseModel):
    question_text: str                # Question stem + active subquestion text
    student_work: str                 # Transcribed LaTeX from student
    steps: list[StepInfo]             # ALL steps for the subquestion
    current_step_index: int           # Which step to evaluate (0-based)
    completed_step_indices: list[int]  # Already-completed step indices


class EvaluateStepResponse(BaseModel):
    progress: float          # 0.0–1.0
    status: str              # "idle" | "working" | "mistake" | "completed"
    feedback: str = ""       # LaTeX explanation of mistake (only when status="mistake")


def _normalize_latex(text: str) -> str:
    """Strip LaTeX formatting to get a plain math string for comparison."""
    s = text
    # Remove display/inline delimiters
    for delim in (r"\[", r"\]", r"\(", r"\)", "$"):
        s = s.replace(delim, "")
    # Remove sizing commands
    for cmd in (r"\left", r"\right", r"\bigl", r"\bigr", r"\Bigl", r"\Bigr"):
        s = s.replace(cmd, "")
    # Remove \text{...} → keep contents
    s = re.sub(r"\\text\s*\{([^}]*)\}", r"\1", s)
    # Remove remaining braces
    s = s.replace("{", "").replace("}", "")
    # Remove all whitespace
    s = re.sub(r"\s+", "", s)
    return s.lower()


def _extract_key_result(work: str) -> str:
    """Extract the final result from step work (right side of last '=')."""
    # Split on newlines and take last non-empty line
    lines = [l.strip() for l in work.strip().splitlines() if l.strip()]
    if not lines:
        return work
    last_line = lines[-1]
    # If there's an '=', take the right side of the last one
    if "=" in last_line:
        result = last_line.rsplit("=", 1)[1]
        return result.strip()
    return last_line


def _student_work_contains_expected(student_work: str, expected_work: str) -> bool:
    """Check if the student's work contains the expected key result."""
    key_result = _extract_key_result(expected_work)
    normalized_result = _normalize_latex(key_result)
    # Skip check for very short expressions (bare numbers, single chars)
    if len(normalized_result) < 2:
        return True
    normalized_student = _normalize_latex(student_work)
    return normalized_result in normalized_student


@router.post("/evaluate-step", response_model=EvaluateStepResponse)
async def evaluate_step(
    body: EvaluateStepRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter API key not configured")

    if body.current_step_index < 0 or body.current_step_index >= len(body.steps):
        raise HTTPException(status_code=422, detail="current_step_index out of range")

    # Build step overview with completion markers
    step_lines = []
    for i, step in enumerate(body.steps):
        if i in body.completed_step_indices:
            marker = "✓ COMPLETED"
        elif i == body.current_step_index:
            marker = "→ CURRENT"
        else:
            marker = "  PENDING"
        step_lines.append(f"  [{marker}] Step {i+1}: {step.description}\n    Expected: {step.work}")

    current_step = body.steps[body.current_step_index]
    prompt = TUTOR_EVALUATE_PROMPT.format(
        question_text=body.question_text,
        steps_overview="\n".join(step_lines),
        current_step_num=body.current_step_index + 1,
        current_step_description=current_step.description,
        current_step_work=current_step.work,
        student_work=body.student_work,
    )

    try:
        llm_client = LLMClient(
            api_key=settings.openrouter_api_key,
            model=TUTOR_EVAL_MODEL,
            base_url="https://openrouter.ai/api/v1",
        )

        result = await asyncio.to_thread(
            llm_client.generate,
            prompt=prompt,
            response_schema=EvaluateStepResponse.model_json_schema(),
            temperature=0.0,
            timeout=15.0,
        )

        data = json.loads(result.content)
        response = EvaluateStepResponse(**data)

        logger.info(
            "[evaluate-step] LLM returned: status=%s progress=%.2f feedback=%s",
            response.status, response.progress, response.feedback[:80] if response.feedback else "",
        )
        logger.info(
            "[evaluate-step] student_work (first 200): %s",
            body.student_work[:200],
        )
        logger.info(
            "[evaluate-step] expected step.work: %s",
            current_step.work[:200],
        )

        # Deterministic stop condition: validate that student actually wrote the expected result
        if response.status == "completed":
            expected_work = current_step.work
            key_result = _extract_key_result(expected_work)
            norm_result = _normalize_latex(key_result)
            norm_student = _normalize_latex(body.student_work)
            contains = _student_work_contains_expected(body.student_work, expected_work)
            logger.info(
                "[evaluate-step] Stop condition: key_result=%r norm_result=%r (len=%d) norm_student=%r contains=%s",
                key_result, norm_result, len(norm_result), norm_student[:100], contains,
            )
            if not contains:
                logger.info(
                    "[evaluate-step] Overriding completed → working: "
                    "student work missing expected result"
                )
                response = EvaluateStepResponse(
                    progress=min(response.progress, 0.95),
                    status="working",
                    feedback="",
                )

        logger.info("[evaluate-step] Final response: status=%s progress=%.2f", response.status, response.progress)
        return response
    except Exception as e:
        logger.error(f"[evaluate-step] LLM call failed: {e}")
        raise HTTPException(status_code=500, detail="Step evaluation failed")
