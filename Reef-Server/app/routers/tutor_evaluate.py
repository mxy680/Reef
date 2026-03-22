"""POST /ai/tutor-evaluate — real-time evaluation of student handwriting against answer key."""

import asyncio
import base64
import json
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.models.answer_key import QuestionAnswer
from app.models.tutor import (
    TutorChatLLMOutput, TutorChatRequest, TutorChatResponse,
    TutorEvaluateRequest, TutorEvaluateResponse, TutorEvaluation,
)
from app.services.llm_client import LLMClient
from app.services.prompts import (
    TUTOR_CHAT_PROMPT, TUTOR_CHAT_SYSTEM,
    TUTOR_EVALUATE_PROMPT, TUTOR_EVALUATE_SYSTEM,
)

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

TUTOR_MODEL = "google/gemini-3-flash-preview"


async def _fetch_answer_key(document_id: str, question_number: int, user_id: str) -> QuestionAnswer:
    """Fetch a single answer key row from Supabase, verifying ownership via the documents table."""
    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
    }

    async with httpx.AsyncClient(timeout=10) as client:
        # Verify document ownership before fetching the answer key
        doc_url = f"{settings.supabase_url}/rest/v1/documents"
        doc_params = {
            "id": f"eq.{document_id}",
            "user_id": f"eq.{user_id}",
            "select": "id",
        }
        doc_resp = await client.get(doc_url, params=doc_params, headers=headers)
        doc_resp.raise_for_status()
        if not doc_resp.json():
            raise HTTPException(status_code=403, detail="Access denied")

        # Fetch the answer key
        url = f"{settings.supabase_url}/rest/v1/answer_keys"
        params = {
            "document_id": f"eq.{document_id}",
            "question_number": f"eq.{question_number}",
            "select": "answer_text,question_json",
        }
        resp = await client.get(url, params=params, headers=headers)
        resp.raise_for_status()

    rows = resp.json()
    if not rows:
        raise HTTPException(status_code=404, detail="Answer key not found")

    return QuestionAnswer.model_validate_json(rows[0]["answer_text"])


def _resolve_steps(answer_key: QuestionAnswer, part_label: str | None) -> list:
    """Find the correct steps list for the given part label.

    Fallback order matches iOS ``currentSteps``: parts first, then top-level steps.
    """
    if part_label is None:
        # No part — try first part's steps, then top-level (matches iOS priority)
        if answer_key.parts and answer_key.parts[0].steps:
            return answer_key.parts[0].steps
        return answer_key.steps

    # Search for matching part label (supports one level of nesting)
    for part in answer_key.parts:
        if part.label == part_label:
            return part.steps
        for sub in part.parts:
            if sub.label == part_label:
                return sub.steps

    return []


async def _download_images(urls: list[str]) -> list[bytes]:
    """Download figure images from signed Supabase storage URLs."""
    if not urls:
        return []
    images = []
    async with httpx.AsyncClient(timeout=15) as client:
        for url in urls[:4]:  # Cap at 4 images to limit token cost
            if not url.startswith(settings.supabase_url):
                log.warning(f"Rejected figure URL not from Supabase storage: {url[:80]}")
                continue
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

    # Fetch answer key (ownership verified inside)
    answer_key = await _fetch_answer_key(body.document_id, body.question_number, user.id)

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

    # Wrap student input in delimiters to prevent prompt injection
    delimited_student_work = (
        "<<<STUDENT_WORK_START>>>\n"
        + body.student_latex
        + "\n<<<STUDENT_WORK_END>>>"
    )

    # Build prompt
    prompt = TUTOR_EVALUATE_PROMPT.format(
        question_text=f"Question {answer_key.question_number}",
        steps_overview=steps_overview,
        current_step_num=body.step_index + 1,
        current_step_description=current_step.description,
        current_step_work=current_step.work,
        student_work=delimited_student_work,
    )

    # Collect images: figure URLs + student drawing
    images = await _download_images(body.figure_urls)
    if body.student_image:
        try:
            images.append(base64.b64decode(body.student_image))
        except Exception:
            pass

    # Call LLM
    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    result = await asyncio.to_thread(
        llm.generate,
        prompt=prompt,
        system_prompt=TUTOR_EVALUATE_SYSTEM,
        images=images or None,
        response_schema=TutorEvaluation.model_json_schema(),
        timeout=30.0,
    )

    evaluation = TutorEvaluation.model_validate_json(result.content)

    # Validate mistake explanation LaTeX if present
    if evaluation.mistake_explanation:
        from app.services.katex_validator import _validate_and_fix_field
        evaluation.mistake_explanation = await _validate_and_fix_field(
            evaluation.mistake_explanation, llm, max_attempts=1,
        )

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


@router.post("/tutor-chat", response_model=TutorChatResponse)
async def tutor_chat(
    body: TutorChatRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter not configured")

    # Fetch answer key (ownership verified inside)
    answer_key = await _fetch_answer_key(body.document_id, body.question_number, user.id)
    steps = _resolve_steps(answer_key, body.part_label)

    current_step_desc = ""
    current_step_work = ""
    if steps and body.step_index < len(steps):
        current_step_desc = steps[body.step_index].description
        current_step_work = steps[body.step_index].work

    steps_overview = "\n".join(
        f"Step {i + 1}: {s.description}" for i, s in enumerate(steps)
    )

    delimited_student_work = (
        "<<<STUDENT_WORK_START>>>\n"
        + (body.student_latex or "(no work yet)")
        + "\n<<<STUDENT_WORK_END>>>"
    )
    delimited_user_message = (
        "<<<USER_MESSAGE_START>>>\n"
        + body.user_message
        + "\n<<<USER_MESSAGE_END>>>"
    )

    # Build conversation history (last 10 messages max)
    history_text = ""
    if body.history:
        lines = []
        for msg in body.history[-10:]:
            label = "Student" if msg.role == "student" else "Tutor"
            lines.append(f"{label}: {msg.text}")
        history_text = "\n".join(lines)

    prompt = TUTOR_CHAT_PROMPT.format(
        question_text=f"Question {answer_key.question_number}",
        current_step_num=body.step_index + 1,
        current_step_description=current_step_desc,
        student_work=delimited_student_work,
        conversation_history=history_text or "(no prior conversation)",
        user_message=delimited_user_message,
    )

    # Include student drawing if provided
    chat_images: list[bytes] | None = None
    if body.student_image:
        try:
            chat_images = [base64.b64decode(body.student_image)]
        except Exception:
            pass

    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    result = await asyncio.to_thread(
        llm.generate,
        prompt=prompt,
        system_prompt=TUTOR_CHAT_SYSTEM,
        images=chat_images,
        response_schema=TutorChatLLMOutput.model_json_schema(),
        timeout=30.0,
    )

    try:
        output = TutorChatLLMOutput.model_validate_json(result.content)
    except Exception:
        # Fallback if structured output fails
        output = TutorChatLLMOutput(reply=result.content.strip(), speech=result.content.strip())

    log.info(
        f"[tutor-chat] Q{body.question_number} step {body.step_index + 1}: "
        f"({result.input_tokens}in/{result.output_tokens}out)"
    )

    # Generate TTS audio via Groq
    speech_audio = None
    if settings.groq_api_key and output.speech:
        try:
            speech_audio = await _generate_tts(output.speech[:500])
        except Exception as e:
            log.warning(f"[tutor-chat] TTS failed: {e}")

    return TutorChatResponse(reply=output.reply, speech_audio=speech_audio)


async def _generate_tts(text: str) -> str | None:
    """Generate TTS audio via Groq and return base64-encoded audio."""
    import base64

    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(
            "https://api.groq.com/openai/v1/audio/speech",
            headers={"Authorization": f"Bearer {settings.groq_api_key}"},
            json={
                "model": "canopylabs/orpheus-v1-english",
                "input": text,
                "voice": "autumn",
                "response_format": "wav",
            },
        )
    if resp.status_code != 200:
        log.warning(f"[tts] Groq TTS returned {resp.status_code}: {resp.text[:200]}")
        return None

    return base64.b64encode(resp.content).decode()
