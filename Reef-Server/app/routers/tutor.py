"""POST /ai/evaluate-step — evaluate student work on a tutor step."""

import asyncio
import json
import logging

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
    mistake_explanation: str | None = None  # Concise LaTeX explanation when status is "mistake"


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
        return EvaluateStepResponse(**data)
    except Exception as e:
        logger.error(f"[evaluate-step] LLM call failed: {e}")
        raise HTTPException(status_code=500, detail="Step evaluation failed")
