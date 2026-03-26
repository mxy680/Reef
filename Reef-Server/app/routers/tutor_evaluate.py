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
from app.services.concept_tracker import get_prior_struggles, record_struggle, resolve_struggles
from app.services.cost_tracker import fire_cost, record_llm_cost
from app.services.prompts import (
    TUTOR_CHAT_PROMPT, TUTOR_CHAT_SYSTEM,
    TUTOR_EVALUATE_DYNAMIC, TUTOR_EVALUATE_STATIC, TUTOR_EVALUATE_SYSTEM,
)

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

TUTOR_MODEL = "google/gemini-3-flash-preview"

# In-memory answer key cache: (doc_id, question_number, user_id) → (QuestionAnswer, question_json, timestamp)
# Avoids hitting Supabase on every eval for the same question.
# Entries expire after 10 minutes. User-scoped to prevent cross-user leaks.
_answer_key_cache: dict[tuple[str, int, str], tuple[QuestionAnswer, dict, float]] = {}
_AK_CACHE_TTL = 600  # 10 minutes


async def _fetch_answer_key(document_id: str, question_number: int, user_id: str) -> tuple[QuestionAnswer, dict]:
    """Fetch a single answer key row from Supabase, with in-memory caching."""
    import time as _time

    cache_key = (document_id, question_number, user_id)

    # Check cache (user-scoped to prevent cross-user access)
    if cache_key in _answer_key_cache:
        cached_answer, cached_qjson, ts = _answer_key_cache[cache_key]
        if _time.time() - ts < _AK_CACHE_TTL:
            return cached_answer, cached_qjson
        else:
            del _answer_key_cache[cache_key]

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

    answer = QuestionAnswer.model_validate_json(rows[0]["answer_text"])
    question_json = rows[0].get("question_json") or {}

    # Cache for future evals on the same question
    _answer_key_cache[cache_key] = (answer, question_json, _time.time())

    # Lazy cleanup: remove expired entries if cache grows
    if len(_answer_key_cache) > 100:
        now = _time.time()
        expired = [k for k, (_, _, ts) in _answer_key_cache.items() if now - ts > _AK_CACHE_TTL]
        for k in expired:
            del _answer_key_cache[k]

    return answer, question_json


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


async def _fetch_student_work(document_id: str, question_label: str, user_id: str) -> tuple[str, str]:
    """Fetch latest student transcription from student_work table. Returns (display, raw)."""
    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
    }
    url = f"{settings.supabase_url}/rest/v1/student_work"
    params = {
        "document_id": f"eq.{document_id}",
        "question_label": f"eq.{question_label}",
        "user_id": f"eq.{user_id}",
        "select": "latex_display,latex_raw",
    }
    async with httpx.AsyncClient(timeout=5) as client:
        resp = await client.get(url, params=params, headers=headers)
        if resp.status_code != 200:
            log.warning(f"[student-work] Failed to fetch: {resp.status_code}")
            return ("", "")
    rows = resp.json()
    if not rows:
        return ("", "")
    return (rows[0].get("latex_display", ""), rows[0].get("latex_raw", ""))


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
    answer_key, question_json = await _fetch_answer_key(body.document_id, body.question_number, user.id)

    # Fetch student work from database (iOS writes here on every transcription)
    question_label = f"Q{body.question_number}{body.part_label or ''}"
    db_display, db_raw = await _fetch_student_work(body.document_id, question_label, user.id)
    # Use DB value, fall back to request body for backward compat
    student_latex = db_raw or db_display or body.student_latex
    if not student_latex:
        return TutorEvaluateResponse(progress=0.0, status="idle")

    # Resolve figure URLs from question_json (uploaded during reconstruction)
    figure_storage_urls = question_json.get("figure_storage_urls", {})

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
        + student_latex
        + "\n<<<STUDENT_WORK_END>>>"
    )
    delimited_steps = f"<<<STEPS_START>>>\n{steps_overview}\n<<<STEPS_END>>>"
    delimited_step_work = f"<<<EXPECTED_WORK_START>>>\n{current_step.work}\n<<<EXPECTED_WORK_END>>>"

    # Build remaining steps context (steps after the current one)
    remaining = steps[body.step_index + 1:]
    if remaining:
        remaining_text = "\n".join(
            f"Step {body.step_index + 2 + i}: {s.description} — {s.work}"
            for i, s in enumerate(remaining)
        )
    else:
        remaining_text = "(This is the final step.)"

    # Build tutor feedback history
    history_text = "(no prior feedback)"
    if body.history:
        lines = []
        for msg in body.history[-15:]:
            label = {"student": "Student", "error": "Tutor (mistake)", "reinforcement": "Tutor (encouragement)", "answer": "Tutor (chat)"}.get(msg.role, msg.role)
            lines.append(f"<<<{label}>>>\n{msg.text}\n<<</{label}>>>")
        history_text = "\n".join(lines)

    # Build prompts — static (cacheable) in system, dynamic in user
    static_context = TUTOR_EVALUATE_STATIC.format(
        question_text=f"Question {answer_key.question_number}",
        steps_overview=delimited_steps,
        current_step_num=body.step_index + 1,
        current_step_description=current_step.description,
        current_step_work=delimited_step_work,
        remaining_steps=remaining_text,
    )
    # Combine system instructions + static question context for caching
    system_prompt = TUTOR_EVALUATE_SYSTEM
    if body.is_demo:
        system_prompt += (
            "\n\n## DEMO MODE OVERRIDE\n"
            "This is an onboarding demo. Keep feedback extremely simple:\n"
            "- For mistakes: give a SHORT direct hint, not a Socratic question. One sentence.\n"
            "- For completions: say something encouraging. One sentence. Do NOT ask 'why did that work?' questions.\n"
            "- NEVER ask the student any questions. Just guide them.\n"
        )
    full_system = system_prompt + "\n\n" + static_context

    dynamic_prompt = TUTOR_EVALUATE_DYNAMIC.format(
        student_work=delimited_student_work,
        tutor_history=history_text,
        current_step_num=body.step_index + 1,
    )

    # Query prior concept struggles for cross-question threading
    current_concepts = current_step.concepts or []
    if current_concepts:
        try:
            prior_struggles = await get_prior_struggles(
                user_id=user.id,
                document_id=body.document_id,
                concepts=current_concepts,
                current_question_number=body.question_number,
            )
        except Exception as e:
            log.warning(f"[tutor-eval] concept struggle query failed: {e}")
            prior_struggles = []

        if prior_struggles:
            struggle_lines = []
            for s in prior_struggles:
                struggle_lines.append(
                    f"- Concept '{s['concept']}': struggled in Q{s['question_number']} "
                    f"step {s['step_index'] + 1} ({s.get('mistake_count', 1)} mistake(s))"
                )
            dynamic_prompt += (
                "\n\n## Prior Concept Struggles\n"
                "The student has struggled with these concepts before in this session:\n"
                + "\n".join(struggle_lines)
                + "\nIf the current step involves any of these concepts, BRIEFLY reference "
                "the prior encounter to build continuity. One sentence max."
            )

    # Collect images: server-resolved figures from question_json + client-sent + student drawing
    all_figure_urls = list(figure_storage_urls.values()) + body.figure_urls
    images = await _download_images(all_figure_urls)

    # Build debug prompt (always included, stripped by iOS if not needed)
    debug_prompt_text = (
        f"=== STUDENT WORK SOURCE ===\n"
        f"question_label: {question_label}\n"
        f"from_db: {bool(db_raw or db_display)} | from_body: {bool(body.student_latex)}\n"
        f"latex_raw ({len(db_raw)} chars): {db_raw[:200]}\n\n"
        "=== SYSTEM MESSAGE ===\n\n"
        + full_system
        + "\n\n=== USER MESSAGE ===\n\n"
        + dynamic_prompt
        + f"\n\n=== IMAGES: {len(all_figure_urls)} figure URLs, "
        + f"student_image={'yes' if body.student_image else 'no'}, "
        + f"{len(images)} images downloaded ==="
    )
    if body.student_image:
        try:
            images.append(base64.b64decode(body.student_image))
        except Exception:
            pass

    # Call LLM — static context in system message enables prompt caching
    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    result = await asyncio.to_thread(
        llm.generate,
        prompt=dynamic_prompt,
        system_prompt=full_system,
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
        f"steps_completed={evaluation.steps_completed} "
        f"({result.input_tokens}in/{result.output_tokens}out)"
    )
    fire_cost(record_llm_cost(user.id, "tutor_eval", TUTOR_MODEL, result.input_tokens, result.output_tokens,
              metadata={"document_id": body.document_id, "question": body.question_number, "step": body.step_index}))

    # Fire-and-forget concept struggle tracking
    if current_concepts:
        async def _safe_concept_track(coro):
            try:
                await coro
            except Exception as e:
                log.warning(f"[concept-tracker] {e}")

        if evaluation.status == "mistake":
            asyncio.create_task(_safe_concept_track(record_struggle(
                user_id=user.id,
                document_id=body.document_id,
                concepts=current_concepts,
                question_number=body.question_number,
                step_index=body.step_index,
                part_label=body.part_label,
            )))
        elif evaluation.status == "completed":
            asyncio.create_task(_safe_concept_track(resolve_struggles(
                user_id=user.id,
                document_id=body.document_id,
                concepts=current_concepts,
                question_number=body.question_number,
                step_index=body.step_index,
            )))

    # Cap steps_completed to not exceed remaining steps
    max_steps = len(steps) - body.step_index
    capped_steps = min(evaluation.steps_completed, max_steps)

    # Generate TTS for mistakes or reinforcements
    speech_audio = None
    speech_text = evaluation.mistake_speech or evaluation.reinforcement_speech
    if settings.groq_api_key and speech_text:
        try:
            speech_audio = await _generate_tts(speech_text[:500])
        except Exception as e:
            log.warning(f"[tutor-eval] TTS failed: {e}")

    return TutorEvaluateResponse(
        progress=evaluation.progress,
        status=evaluation.status,
        mistake_explanation=evaluation.mistake_explanation,
        steps_completed=capped_steps,
        speech_audio=speech_audio,
        debug_prompt=debug_prompt_text,
    )


async def _regenerate_answer_key(
    document_id: str,
    question_number: int,
    user_id: str,
    correction: str,
    answer_key: QuestionAnswer,
) -> None:
    """Regenerate an answer key after a student correction, using DeepSeek R1."""
    from app.services.inference_client import extract_json
    from app.services.answer_keys import _supabase_headers

    prompt = (
        f"The following answer key was generated for a homework question, but the student "
        f"pointed out an error in the problem interpretation.\n\n"
        f"## Original Answer Key\n```json\n{answer_key.model_dump_json(indent=2)}\n```\n\n"
        f"## Student's Correction\n{correction}\n\n"
        f"## Task\n"
        f"Regenerate the COMPLETE answer key with the correction applied. Fix all affected steps, "
        f"work, final answers, and reinforcement messages. Keep the same JSON structure.\n"
        f"Return ONLY valid JSON — no markdown, no explanation, no code fences.\n"
        f"```json\n{json.dumps(QuestionAnswer.model_json_schema(), indent=2)}\n```"
    )

    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model="google/gemini-3-flash-preview",
        base_url="https://openrouter.ai/api/v1",
    )
    result = await asyncio.to_thread(
        llm.generate,
        prompt=prompt,
        response_schema=QuestionAnswer.model_json_schema(),
        timeout=120.0,
    )
    content = extract_json(result.content)
    new_answer = QuestionAnswer.model_validate_json(content)
    fire_cost(record_llm_cost(user_id, "answer_key", "google/gemini-3-flash-preview",
              result.input_tokens, result.output_tokens,
              metadata={"document_id": document_id, "question": question_number, "stage": "correction"}))

    # Store updated answer key
    headers = _supabase_headers()
    headers["Prefer"] = "resolution=merge-duplicates,return=minimal"
    async with httpx.AsyncClient(timeout=10) as client:
        await client.post(
            f"{settings.supabase_url}/rest/v1/answer_keys",
            headers=headers,
            json={
                "document_id": document_id,
                "question_number": question_number,
                "answer_text": new_answer.model_dump_json(),
                "model": "deepseek-r1-correction",
                "input_tokens": result.input_tokens,
                "output_tokens": result.output_tokens,
            },
        )

    # Invalidate memory cache
    cache_key = (document_id, question_number, user_id)
    _answer_key_cache.pop(cache_key, None)


@router.post("/tutor-chat", response_model=TutorChatResponse)
async def tutor_chat(
    body: TutorChatRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter not configured")

    # Fetch answer key (ownership verified inside)
    answer_key, _ = await _fetch_answer_key(body.document_id, body.question_number, user.id)
    steps = _resolve_steps(answer_key, body.part_label)

    current_step_desc = ""
    current_step_work = ""
    if steps and body.step_index < len(steps):
        current_step_desc = steps[body.step_index].description
        current_step_work = steps[body.step_index].work

    steps_overview = "\n".join(
        f"Step {i + 1}: {s.description}" for i, s in enumerate(steps)
    )

    # Fetch student work from DB (same as eval endpoint)
    chat_question_label = f"Q{body.question_number}{body.part_label or ''}"
    chat_db_display, chat_db_raw = await _fetch_student_work(body.document_id, chat_question_label, user.id)
    chat_student_latex = chat_db_raw or chat_db_display or body.student_latex or "(no work yet)"

    delimited_student_work = (
        "<<<STUDENT_WORK_START>>>\n"
        + chat_student_latex
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
            lines.append(f"<<<{label.upper()}_MSG>>>\n{msg.text}\n<<</{label.upper()}_MSG>>>")
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
    fire_cost(record_llm_cost(user.id, "tutor_chat", TUTOR_MODEL, result.input_tokens, result.output_tokens,
              metadata={"document_id": body.document_id, "question": body.question_number}))

    # If the LLM detected a problem data correction, regenerate the answer key
    answer_key_updated = False
    if output.correction:
        log.info(f"[tutor-chat] Correction detected for Q{body.question_number}: {output.correction[:100]}")
        try:
            await _regenerate_answer_key(
                document_id=body.document_id,
                question_number=body.question_number,
                user_id=user.id,
                correction=output.correction,
                answer_key=answer_key,
            )
            answer_key_updated = True
            log.info(f"[tutor-chat] Answer key regenerated for Q{body.question_number}")
        except Exception as e:
            log.warning(f"[tutor-chat] Answer key regeneration failed: {e}")

    # Generate TTS audio via Groq
    speech_audio = None
    if settings.groq_api_key and output.speech:
        try:
            speech_audio = await _generate_tts(output.speech[:500])
        except Exception as e:
            log.warning(f"[tutor-chat] TTS failed: {e}")

    return TutorChatResponse(reply=output.reply, speech_audio=speech_audio, answer_key_updated=answer_key_updated)


async def _generate_tts(text: str) -> str | None:
    """Generate TTS audio via Groq with Supabase caching."""
    # Reuse the cached TTS pipeline from demo_problem
    from app.routers.demo_problem import _generate_tts as _cached_tts
    return await _cached_tts(text)
