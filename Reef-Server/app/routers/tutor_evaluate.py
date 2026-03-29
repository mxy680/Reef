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
from app.services.cost_tracker import fire_cost, record_llm_cost, MATHPIX_STROKES_PER_SESSION, record_cost
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
        expired = [k for k, (_, _, ts) in list(_answer_key_cache.items()) if now - ts > _AK_CACHE_TTL]
        for k in expired:
            del _answer_key_cache[k]

    return answer, question_json


def _resolve_steps(answer_key: QuestionAnswer, part_label: str | None) -> list:
    """Find the correct steps list for the given part label.

    Fallback order matches iOS ``currentSteps``: parts first, then top-level steps.
    """
    if part_label is None:
        # No part — try first part's steps, then top-level
        # Must match iOS CanvasViewModel.currentSteps exactly
        if answer_key.parts:
            first = answer_key.parts[0]
            if first.steps:
                return first.steps
            # First part has no steps — check sub-parts
            if first.parts and first.parts[0].steps:
                return first.parts[0].steps
        return answer_key.steps

    # Search for matching part label (supports one level of nesting)
    for part in answer_key.parts:
        if part.label == part_label:
            return part.steps
        for sub in part.parts:
            if sub.label == part_label:
                return sub.steps

    return []


def _supabase_headers() -> dict[str, str]:
    return {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/json",
    }


async def _fetch_chat_history(document_id: str, question_label: str, user_id: str) -> list[dict]:
    """Fetch last 15 chat messages from chat_history table."""
    url = f"{settings.supabase_url}/rest/v1/chat_history"
    params = {
        "user_id": f"eq.{user_id}",
        "document_id": f"eq.{document_id}",
        "question_label": f"eq.{question_label}",
        "select": "role,text",
        "order": "created_at.desc",
        "limit": "15",
    }
    async with httpx.AsyncClient(timeout=5) as client:
        resp = await client.get(url, params=params, headers=_supabase_headers())
        if resp.status_code != 200:
            return []
    rows = resp.json()
    rows.reverse()  # oldest first
    return rows


async def _append_chat(user_id: str, document_id: str, question_label: str, role: str, text: str) -> None:
    """Insert a chat message. Fire-and-forget safe."""
    url = f"{settings.supabase_url}/rest/v1/chat_history"
    row = {
        "user_id": user_id,
        "document_id": document_id,
        "question_label": question_label,
        "role": role,
        "text": text,
    }
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            await client.post(url, json=row, headers=_supabase_headers())
    except Exception as e:
        log.warning(f"[chat-history] Failed to write: {e}")


async def _fetch_student_work(document_id: str, question_label: str, user_id: str) -> tuple[str, str]:
    """Fetch transcription from canvas_strokes.latex. Returns (display, raw) — both same value."""
    url = f"{settings.supabase_url}/rest/v1/canvas_strokes"
    params = {
        "document_id": f"eq.{document_id}",
        "question_label": f"eq.{question_label}",
        "user_id": f"eq.{user_id}",
        "select": "latex",
    }
    async with httpx.AsyncClient(timeout=5) as client:
        resp = await client.get(url, params=params, headers=_supabase_headers())
        if resp.status_code != 200:
            log.warning(f"[student-work] Failed to fetch: {resp.status_code}")
            return ("", "")
    rows = resp.json()
    if not rows:
        return ("", "")
    latex = rows[0].get("latex", "")
    return (latex, latex)


_MATHPIX_CHUNK_SIZE = 50


async def _fetch_and_transcribe_strokes(
    document_id: str, question_label: str, user_id: str
) -> str:
    """Fetch strokes from canvas_strokes table, transcribe via Mathpix, return LaTeX.

    Strokes are chunked into groups of _MATHPIX_CHUNK_SIZE and transcribed
    sequentially. Results are concatenated with a space separator.
    Returns an empty string if no strokes exist or Mathpix is unavailable.
    """
    if not settings.mathpix_app_id or not settings.mathpix_app_key:
        log.debug("[strokes] Mathpix not configured — skipping stroke transcription")
        return ""

    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
    }

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(
            f"{settings.supabase_url}/rest/v1/canvas_strokes",
            params={
                "user_id": f"eq.{user_id}",
                "document_id": f"eq.{document_id}",
                "question_label": f"eq.{question_label}",
                "select": "strokes",
            },
            headers=headers,
        )

    if resp.status_code != 200:
        log.warning(f"[strokes] Failed to fetch canvas_strokes: {resp.status_code}")
        return ""

    rows = resp.json()
    if not rows:
        return ""

    # Flatten all stroke objects into one list
    all_strokes: list[dict] = []
    for row in rows:
        all_strokes.extend(row.get("strokes", []))

    if not all_strokes:
        return ""

    from app.services.mathpix_pool import acquire_session

    try:
        app_token, session_id, _ = await acquire_session()
    except RuntimeError as e:
        log.warning(f"[strokes] Could not acquire Mathpix session: {e}")
        return ""

    fire_cost(record_cost(user_id, "transcribe", "mathpix_strokes", MATHPIX_STROKES_PER_SESSION))

    mathpix_headers = {"app_token": app_token, "Content-Type": "application/json"}
    latex_parts: list[str] = []

    async with httpx.AsyncClient(timeout=15) as client:
        for i in range(0, len(all_strokes), _MATHPIX_CHUNK_SIZE):
            chunk = all_strokes[i : i + _MATHPIX_CHUNK_SIZE]
            payload = {
                "strokes": {
                    "strokes": {
                        "x": [s["x"] for s in chunk],
                        "y": [s["y"] for s in chunk],
                    }
                },
                "strokes_session_id": session_id,
            }
            try:
                r = await client.post(
                    "https://api.mathpix.com/v3/strokes",
                    json=payload,
                    headers=mathpix_headers,
                )
            except Exception as e:
                log.warning(f"[strokes] Mathpix request error on chunk {i}: {e}")
                continue

            if r.status_code != 200:
                log.warning(f"[strokes] Mathpix returned {r.status_code} on chunk {i}: {r.text[:200]}")
                continue

            data = r.json()
            if "error" in data:
                log.warning(f"[strokes] Mathpix error on chunk {i}: {data['error']}")
                continue

            chunk_latex = data.get("latex", data.get("text", "")).strip()
            if chunk_latex:
                latex_parts.append(chunk_latex)

    return " ".join(latex_parts)


async def _upsert_student_work(
    document_id: str, question_label: str, user_id: str, latex_display: str, latex_raw: str
) -> None:
    """Upsert transcription into canvas_strokes.latex. Fire-and-forget safe."""
    url = f"{settings.supabase_url}/rest/v1/canvas_strokes?user_id=eq.{user_id}&document_id=eq.{document_id}&question_label=eq.{question_label}"
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            await client.patch(url, json={"latex": latex_display}, headers=_supabase_headers())
    except Exception as e:
        log.warning(f"[student-work] Failed to upsert latex: {e}")


async def _update_tutor_state(
    document_id: str, question_label: str, user_id: str,
    progress: float, status: str, step_index: int, steps_completed: int,
) -> None:
    """Write tutor eval state to canvas_strokes for iOS polling. Fire-and-forget safe."""
    url = f"{settings.supabase_url}/rest/v1/canvas_strokes?user_id=eq.{user_id}&document_id=eq.{document_id}&question_label=eq.{question_label}"
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            await client.patch(url, json={
                "tutor_progress": progress,
                "tutor_status": status,
                "tutor_step": step_index,
                "tutor_steps_completed": steps_completed,
            }, headers=_supabase_headers())
    except Exception as e:
        log.warning(f"[tutor-state] Failed to update: {e}")


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


from pydantic import BaseModel as _BaseModel


class TranscribeRequest(_BaseModel):
    document_id: str
    question_label: str


class TranscribeResponse(_BaseModel):
    latex: str


@router.post("/transcribe", response_model=TranscribeResponse)
async def transcribe_strokes(
    body: TranscribeRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Read strokes from canvas_strokes, transcribe via Mathpix, upsert to student_work."""
    latex = await _fetch_and_transcribe_strokes(body.document_id, body.question_label, user.id)
    if latex:
        asyncio.create_task(_upsert_student_work(
            body.document_id, body.question_label, user.id, latex, latex
        ))
    return TranscribeResponse(latex=latex)


@router.post("/tutor-evaluate", response_model=TutorEvaluateResponse)
async def tutor_evaluate(
    body: TutorEvaluateRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter not configured")

    # Fetch answer key (ownership verified inside)
    answer_key, question_json = await _fetch_answer_key(body.document_id, body.question_number, user.id)

    question_label = f"Q{body.question_number}{body.part_label or ''}"

    # Fetch and transcribe strokes directly from canvas_strokes (primary source)
    transcribed_latex = await _fetch_and_transcribe_strokes(body.document_id, question_label, user.id)

    # Fall back to student_work table (legacy iOS writes), then request body
    db_display, db_raw = await _fetch_student_work(body.document_id, question_label, user.id)
    student_latex = transcribed_latex or db_raw or db_display or body.student_latex
    if not student_latex:
        return TutorEvaluateResponse(progress=0.0, status="idle")

    # Keep student_work table in sync when we have fresh transcription
    if transcribed_latex:
        asyncio.create_task(_upsert_student_work(
            body.document_id, question_label, user.id, transcribed_latex, transcribed_latex
        ))

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

    # Build tutor feedback history from DB (fall back to body.history)
    db_history = await _fetch_chat_history(body.document_id, question_label, user.id)
    history_text = "(no prior feedback)"
    history_source = db_history if db_history else [{"role": m.role, "text": m.text} for m in (body.history or [])]
    if history_source:
        lines = []
        for msg in history_source[-15:]:
            label = {"student": "Student", "error": "Tutor (mistake)", "reinforcement": "Tutor (encouragement)", "answer": "Tutor (chat)"}.get(msg["role"], msg["role"])
            lines.append(f"<<<{label}>>>\n{msg['text']}\n<<</{label}>>>")
        history_text = "\n".join(lines)

    # Build actual question text from question_json
    q_text = question_json.get("text", "")
    if body.part_label:
        # Find the matching part's text
        for part in question_json.get("parts", []):
            if part.get("label") == body.part_label:
                part_text = part.get("text", "")
                if part_text:
                    q_text = f"{q_text}\n\nPart ({body.part_label}): {part_text}" if q_text else part_text
                break
    full_question_text = f"Question {answer_key.question_number}: {q_text}" if q_text else f"Question {answer_key.question_number}"

    # Build prompts — static (cacheable) in system, dynamic in user
    static_context = TUTOR_EVALUATE_STATIC.format(
        question_text=full_question_text,
        steps_overview=delimited_steps,
        current_step_num=body.step_index + 1,
        current_step_description=current_step.description,
        current_step_hint=current_step.explanation,
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

    # Build debug prompt (always included)
    work_source = "strokes" if transcribed_latex else ("DB" if (db_raw or db_display) else "body")
    debug_prompt_text = (
        f"=== STUDENT WORK (from {work_source}, {question_label}) ===\n"
        f"{student_latex[:300]}\n\n"
        f"=== SYSTEM (cached) ===\n\n"
        + full_system
        + f"\n\n=== USER (dynamic) ===\n\n"
        + dynamic_prompt
        + f"\n\n=== IMAGES: {len(images)} figures, student_image={'yes' if body.student_image else 'no'} ==="
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

    # Write eval results to chat history (fire-and-forget)
    if evaluation.status == "mistake" and evaluation.mistake_explanation:
        asyncio.create_task(_append_chat(user.id, body.document_id, question_label, "error", evaluation.mistake_explanation))
    elif evaluation.status == "completed" and evaluation.reinforcement_speech:
        asyncio.create_task(_append_chat(user.id, body.document_id, question_label, "reinforcement", evaluation.reinforcement_speech))

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

    # Write tutor state to canvas_strokes so iOS polling can pick it up
    asyncio.create_task(_update_tutor_state(
        body.document_id, question_label, user.id,
        progress=evaluation.progress,
        status=evaluation.status,
        step_index=body.step_index,
        steps_completed=capped_steps,
    ))

    return TutorEvaluateResponse(
        progress=evaluation.progress,
        status=evaluation.status,
        mistake_explanation=evaluation.mistake_explanation,
        steps_completed=capped_steps,
        speech_audio=speech_audio,
        speech_text=speech_text,
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

    # Build conversation history from DB (fall back to body.history)
    chat_db_history = await _fetch_chat_history(body.document_id, chat_question_label, user.id)
    chat_history_source = chat_db_history if chat_db_history else [{"role": m.role, "text": m.text} for m in (body.history or [])]
    history_text = ""
    if chat_history_source:
        lines = []
        for msg in chat_history_source[-10:]:
            label = {
                "student": "Student",
                "error": "Tutor (flagged a mistake)",
                "reinforcement": "Tutor (confirmed step correct)",
                "answer": "Tutor (chat reply)",
            }.get(msg["role"], msg["role"])
            lines.append(f"<<<{label.upper()}_MSG>>>\n{msg['text']}\n<<</{label.upper()}_MSG>>>")
        history_text = "\n".join(lines)

    # Extract recent eval feedback (last 5 error/reinforcement entries) as ground-truth context
    eval_entries = [m for m in chat_history_source if m["role"] in ("error", "reinforcement")][-5:]
    if eval_entries:
        eval_lines = []
        for msg in eval_entries:
            label = "Flagged mistake" if msg["role"] == "error" else "Confirmed correct"
            eval_lines.append(f"- [{label}]: {msg['text']}")
        recent_eval_feedback = "\n".join(eval_lines)
    else:
        recent_eval_feedback = "(none)"

    prompt = TUTOR_CHAT_PROMPT.format(
        question_text=f"Question {answer_key.question_number}",
        current_step_num=body.step_index + 1,
        current_step_description=current_step_desc,
        student_work=delimited_student_work,
        conversation_history=history_text or "(no prior conversation)",
        user_message=delimited_user_message,
        recent_eval_feedback=recent_eval_feedback,
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

    # Write chat messages to DB (fire-and-forget)
    asyncio.create_task(_append_chat(user.id, body.document_id, chat_question_label, "student", body.user_message))
    asyncio.create_task(_append_chat(user.id, body.document_id, chat_question_label, "answer", output.reply))

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
