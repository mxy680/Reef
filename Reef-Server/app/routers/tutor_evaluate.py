"""POST /ai/tutor-evaluate — real-time evaluation of student handwriting against answer key."""

import asyncio
import json
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.models.answer_key import QuestionAnswer
from app.models.tutor import TutorEvaluateRequest, TutorEvaluateResponse, TutorEvaluation
from app.services.llm_client import LLMClient
from app.services.prompts import TUTOR_EVALUATE_PROMPT

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

TUTOR_MODEL = "google/gemini-3-flash-preview"


async def _fetch_answer_key(document_id: str, question_number: int) -> QuestionAnswer:
    """Fetch a single answer key row from Supabase."""
    url = f"{settings.supabase_url}/rest/v1/answer_keys"
    params = {
        "document_id": f"eq.{document_id}",
        "question_number": f"eq.{question_number}",
        "select": "answer_text,question_json",
    }
    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
    }
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url, params=params, headers=headers)
        resp.raise_for_status()

    rows = resp.json()
    if not rows:
        raise HTTPException(status_code=404, detail="Answer key not found")

    return QuestionAnswer.model_validate_json(rows[0]["answer_text"])


def _resolve_steps(answer_key: QuestionAnswer, part_label: str | None) -> list:
    """Find the correct steps list for the given part label."""
    if part_label is None:
        # No part — use top-level steps or first part's steps
        if answer_key.steps:
            return answer_key.steps
        if answer_key.parts:
            return answer_key.parts[0].steps
        return []

    # Search for matching part label (supports one level of nesting)
    for part in answer_key.parts:
        if part.label == part_label:
            return part.steps
        for sub in part.parts:
            if sub.label == part_label:
                return sub.steps

    return []


def _build_question_text(answer_key: QuestionAnswer, part_label: str | None) -> str:
    """Extract question text from the stored question_json context."""
    # The answer key stores the question context — we reconstruct a readable version
    parts_text = []
    if part_label:
        for part in answer_key.parts:
            if part.label == part_label:
                parts_text.append(f"Part ({part.label}): {part.final_answer}")
                break
    return f"Question {answer_key.question_number}"


async def _download_images(urls: list[str]) -> list[bytes]:
    """Download figure images from signed URLs."""
    if not urls:
        return []
    images = []
    async with httpx.AsyncClient(timeout=15) as client:
        for url in urls[:4]:  # Cap at 4 images to limit token cost
            try:
                resp = await client.get(url)
                if resp.status_code == 200:
                    images.append(resp.content)
            except Exception as e:
                log.warning(f"Failed to download figure: {e}")
    return images


@router.post("/tutor-evaluate", response_model=TutorEvaluateResponse)
async def tutor_evaluate(
    body: TutorEvaluateRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter not configured")

    # Fetch answer key
    answer_key = await _fetch_answer_key(body.document_id, body.question_number)

    # Resolve steps for the target part
    steps = _resolve_steps(answer_key, body.part_label)
    if not steps or body.step_index >= len(steps):
        raise HTTPException(status_code=400, detail="Invalid step index")

    current_step = steps[body.step_index]

    # Build steps overview
    steps_overview = "\n".join(
        f"Step {i + 1}: {s.description} — {s.work}"
        for i, s in enumerate(steps)
    )

    # Build prompt
    prompt = TUTOR_EVALUATE_PROMPT.format(
        question_text=f"Question {answer_key.question_number}",
        steps_overview=steps_overview,
        current_step_num=body.step_index + 1,
        current_step_description=current_step.description,
        current_step_work=current_step.work,
        student_work=body.student_latex,
    )

    # Download figure images if provided (vision model)
    images = await _download_images(body.figure_urls)

    # Call LLM
    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    result = await asyncio.to_thread(
        llm.generate,
        prompt=prompt,
        images=images or None,
        response_schema=TutorEvaluation.model_json_schema(),
        timeout=30.0,
    )

    evaluation = TutorEvaluation.model_validate_json(result.content)

    log.info(
        f"[tutor-eval] Q{body.question_number} step {body.step_index + 1}: "
        f"status={evaluation.status} progress={evaluation.progress:.0%} "
        f"({result.input_tokens}in/{result.output_tokens}out)"
    )

    return TutorEvaluateResponse(
        progress=evaluation.progress,
        status=evaluation.status,
        mistake_explanation=evaluation.mistake_explanation,
    )
