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


class EvaluateStepRequest(BaseModel):
    question_text: str       # Question stem + active subquestion text
    step_description: str    # Current step's description
    step_work: str           # Current step's expected answer/work
    student_work: str        # Transcribed LaTeX from student


class EvaluateStepResponse(BaseModel):
    progress: float          # 0.0–1.0
    status: str              # "idle" | "working" | "mistake" | "completed"


@router.post("/evaluate-step", response_model=EvaluateStepResponse)
async def evaluate_step(
    body: EvaluateStepRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter API key not configured")

    prompt = TUTOR_EVALUATE_PROMPT.format(
        question_text=body.question_text,
        step_description=body.step_description,
        step_work=body.step_work,
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
