"""POST /ai/demo-problem — generate a practice problem for onboarding demo.
POST /ai/demo-chat — chat with tutor about the demo problem (no auth required).
POST /ai/demo-document — generate a problem, compile to PDF, and store in Supabase."""

import asyncio
import hashlib
import logging
import uuid

import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.models.answer_key import QuestionAnswer
from app.models.demo import (
    DemoChatRequest, DemoChatResponse,
    DemoProblem, DemoProblemRequest, DemoProblemResponse,
    DemoDocumentRequest, DemoDocumentResponse,
    WalkthroughReactRequest, WalkthroughReactResponse,
    WalkthroughTTSRequest, WalkthroughTTSResponse,
)
from app.models.question import Question
from app.models.tutor import TutorChatLLMOutput
from app.services.latex_compiler import LaTeXCompiler
from app.services.llm_client import LLMClient
from app.services.question_to_latex import question_to_latex

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

TUTOR_MODEL = "google/gemini-3-flash-preview"

DEMO_PROBLEM_SYSTEM = """\
You are a math and science problem generator for college students. Generate a single practice problem \
on the given topic that is interesting, clear, and solvable in 2-3 steps. The problem should be \
challenging enough to be worth solving but not so hard that a student would give up.
"""

DEMO_PROBLEM_PROMPT = """\
Generate a simple, straightforward practice problem about: {topic}
Student level: {student_type}

Requirements:
- This is for an onboarding demo — the student should be able to solve it in under 2 minutes
- Keep it SIMPLE. Think "first homework assignment" level, not exam level
- 2 steps max. Each step should be one clear operation (not multi-part)
- Use basic numbers and clean expressions — avoid fractions of fractions, nested radicals, or complex setups
- Use $...$ for inline math and \\[...\\] for display math in the question text
- The tutor_intro should be casual and friendly — like a TA saying "let's try this"
- DO NOT generate word problems or story problems. Just a clean math/science problem.

Examples of good difficulty:
- "Find the derivative of $f(x) = 3x^2 + 5x - 2$"
- "Solve for $x$: $2x + 7 = 15$"
- "Find the integral of $\\int 4x^3 \\, dx$"
- "A 5 kg object accelerates at $2 \\, m/s^2$. Find the net force."
"""

DEMO_CHAT_SYSTEM = """\
You are a chill TA hanging out with a student during office hours. You're their friend who happens to know the subject well.

## Output
Return a JSON object with two fields:

- `reply` — Written response. One or two sentences max. Use $...$ for inline math if discussing the problem.
- `speech` — Same response for speaking aloud. NO math notation, NO LaTeX. Say formulas in words. One or two sentences max.

## CRITICAL rules
- One or two sentences max. NEVER more.
- If the student is asking about the problem: give a helpful nudge, don't reveal the answer.
- If the student is chatting about something else: just answer like a friend. NEVER redirect them back to the problem.
- Never say "I".
"""

DEMO_CHAT_PROMPT = """\
## Problem
{question_text}

## Solution steps (for your reference — don't reveal these)
{steps_overview}

## Current step
{current_step_description}

## Student's work so far
{student_work}

## Conversation so far
{conversation_history}

## Student says now
<<<USER_MESSAGE_START>>>
{user_message}
<<<USER_MESSAGE_END>>>
"""


@router.post("/demo-problem", response_model=DemoProblemResponse)
async def demo_problem(body: DemoProblemRequest, user: AuthenticatedUser = Depends(get_current_user)):
    """Generate a demo problem — no auth required (onboarding use only)."""
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter not configured")

    prompt = DEMO_PROBLEM_PROMPT.format(
        topic=body.topic[:200],
        student_type=body.student_type,
    )

    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    result = await asyncio.to_thread(
        llm.generate,
        prompt=prompt,
        system_prompt=DEMO_PROBLEM_SYSTEM,
        response_schema=DemoProblem.model_json_schema(),
        timeout=30.0,
    )

    problem = DemoProblem.model_validate_json(result.content)

    log.info(
        f"[demo-problem] topic='{body.topic}' "
        f"steps={len(problem.steps)} "
        f"({result.input_tokens}in/{result.output_tokens}out)"
    )

    return DemoProblemResponse(
        question_text=problem.question_text,
        steps=problem.steps,
        final_answer=problem.final_answer,
        tutor_intro=problem.tutor_intro,
    )


@router.post("/demo-chat", response_model=DemoChatResponse)
async def demo_chat(body: DemoChatRequest, user: AuthenticatedUser = Depends(get_current_user)):
    """Chat with tutor about a demo problem — no auth required."""
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter not configured")

    # Build conversation history
    history_text = ""
    if body.history:
        lines = []
        for msg in body.history[-10:]:
            label = "Student" if msg.role == "student" else "Tutor"
            lines.append(f"<<<{label.upper()}_MSG>>>\n{msg.text}\n<<</{label.upper()}_MSG>>>")
        history_text = "\n".join(lines)

    prompt = DEMO_CHAT_PROMPT.format(
        question_text=body.question_text,
        steps_overview=body.steps_overview or "(no steps)",
        current_step_description=body.current_step_description or "(not started)",
        student_work=body.student_work or "(no work yet)",
        conversation_history=history_text or "(no prior conversation)",
        user_message=body.user_message,
    )

    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    result = await asyncio.to_thread(
        llm.generate,
        prompt=prompt,
        system_prompt=DEMO_CHAT_SYSTEM,
        response_schema=TutorChatLLMOutput.model_json_schema(),
        timeout=30.0,
    )

    try:
        output = TutorChatLLMOutput.model_validate_json(result.content)
    except Exception:
        output = TutorChatLLMOutput(reply=result.content.strip(), speech=result.content.strip())

    log.info(
        f"[demo-chat] ({result.input_tokens}in/{result.output_tokens}out)"
    )

    # Generate TTS audio via Groq
    speech_audio = None
    if settings.groq_api_key and output.speech:
        try:
            speech_audio = await _generate_tts(output.speech[:500])
        except Exception as e:
            log.warning(f"[demo-chat] TTS failed: {e}")

    return DemoChatResponse(reply=output.reply, speech_audio=speech_audio)


@router.post("/demo-document", response_model=DemoDocumentResponse)
async def demo_document(
    body: DemoDocumentRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Generate a demo problem, compile to PDF, and store in Supabase."""
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter not configured")
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise HTTPException(status_code=503, detail="Supabase not configured")

    # 1. Generate problem via LLM (same logic as /demo-problem)
    prompt = DEMO_PROBLEM_PROMPT.format(
        topic=body.topic[:200],
        student_type=body.student_type,
    )

    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    result = await asyncio.to_thread(
        llm.generate,
        prompt=prompt,
        system_prompt=DEMO_PROBLEM_SYSTEM,
        response_schema=DemoProblem.model_json_schema(),
        timeout=30.0,
    )

    problem = DemoProblem.model_validate_json(result.content)

    log.info(
        f"[demo-document] topic='{body.topic}' "
        f"steps={len(problem.steps)} "
        f"({result.input_tokens}in/{result.output_tokens}out)"
    )

    # 2. Convert to Question model
    question = Question(number=1, text=problem.question_text, answer_space_cm=5.0)

    # 3. Convert to LaTeX
    latex_body = question_to_latex(question)

    # 4. Compile to PDF
    try:
        compiler = LaTeXCompiler()
        pdf_bytes = await asyncio.to_thread(compiler.compile_latex, latex_body)
    except RuntimeError as e:
        log.error(f"[demo-document] LaTeX compilation failed: {e}")
        raise HTTPException(status_code=500, detail="PDF compilation failed")

    # 5 & 6. Insert document record and upload PDF to Supabase
    doc_id = str(uuid.uuid4())
    filename = f"demo-{body.topic[:30]}.pdf"
    doc_row = {
        "id": doc_id,
        "user_id": user.id,
        "filename": filename,
        "status": "completed",
        "page_count": 1,
        "problem_count": 1,
        "question_pages": [[0, 0]],
    }

    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=15) as client:
        # Insert document row
        resp = await client.post(
            f"{settings.supabase_url}/rest/v1/documents",
            headers=headers,
            json=doc_row,
        )
        if resp.status_code not in (200, 201):
            log.error(f"[demo-document] Failed to insert document: {resp.status_code} {resp.text[:200]}")
            raise HTTPException(status_code=500, detail="Failed to create document record")

        # Upload PDF to storage
        storage_headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
            "Content-Type": "application/pdf",
        }
        storage_path = f"{user.id}/{doc_id}/original.pdf"
        resp = await client.post(
            f"{settings.supabase_url}/storage/v1/object/documents/{storage_path}",
            headers=storage_headers,
            content=pdf_bytes,
        )
        if resp.status_code not in (200, 201):
            log.error(f"[demo-document] Failed to upload PDF: {resp.status_code} {resp.text[:200]}")
            raise HTTPException(status_code=500, detail="Failed to upload PDF")

        # 7. Create answer key record
        # Wrap steps in a part "a" so iOS tutor can resolve via activeQuestionLabel "Q1a"
        from app.models.answer_key import PartAnswer
        answer_key = QuestionAnswer(
            question_number=1,
            parts=[PartAnswer(
                label="a",
                steps=problem.steps,
                final_answer=problem.final_answer,
            )],
        )
        answer_key_row = {
            "document_id": doc_id,
            "question_number": 1,
            "answer_text": answer_key.model_dump_json(),
            "question_json": question.model_dump(),
            "model": TUTOR_MODEL,
            "input_tokens": result.input_tokens,
            "output_tokens": result.output_tokens,
        }
        resp = await client.post(
            f"{settings.supabase_url}/rest/v1/answer_keys",
            headers=headers,
            json=answer_key_row,
        )
        if resp.status_code not in (200, 201):
            log.error(f"[demo-document] Failed to insert answer key: {resp.status_code} {resp.text[:200]}")
            raise HTTPException(status_code=500, detail="Failed to create answer key record")

    # 8. Return summary
    return DemoDocumentResponse(
        document_id=doc_id,
        filename=filename,
        page_count=1,
        problem_count=1,
    )


@router.post("/walkthrough-react", response_model=WalkthroughReactResponse)
async def walkthrough_react(
    body: WalkthroughReactRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """React to what the user drew during the walkthrough with a funny comment."""
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter not configured")

    import base64

    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    images = []
    try:
        images.append(base64.b64decode(body.image))
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image data")

    from app.models.demo import WalkthroughReactLLMOutput

    result = await asyncio.to_thread(
        llm.generate,
        prompt="Look at this image of what a student just drew on their iPad. Give a very short reaction. ONE sentence max. Be specific about what you see.\n\nIMPORTANT: Only be sarcastic if they barely drew anything (a single line, a dot, a basic circle, a scribble). If they drew something recognizable and fun (a smiley face, an animal, a person, a flower, a house, etc.), be genuinely positive and specific about it.",
        system_prompt="You are a chill college TA reacting to a doodle. ONE short sentence only. Be specific about what you see.\n\nIf minimal effort (line, dot, scribble, basic circle): be playfully sarcastic. Examples: 'A line. Groundbreaking.' / 'Bold of you to call that a circle.'\n\nIf actual effort (smiley, animal, person, word, drawing): be genuinely positive. Examples: 'OK that smiley is actually adorable.' / 'A cat! Respect.' / 'That's actually pretty good, not gonna lie.'",
        images=images,
        response_schema=WalkthroughReactLLMOutput.model_json_schema(),
        timeout=15.0,
    )

    try:
        output = WalkthroughReactLLMOutput.model_validate_json(result.content)
    except Exception:
        output = WalkthroughReactLLMOutput(
            reaction="Nice drawing. I think.",
            speech="Nice drawing. I think.",
        )

    log.info(f"[walkthrough-react] ({result.input_tokens}in/{result.output_tokens}out)")

    speech_audio = None
    if settings.groq_api_key and output.speech:
        try:
            speech_audio = await _generate_tts(output.speech[:300])
        except Exception as e:
            log.warning(f"[walkthrough-react] TTS failed: {e}")

    return WalkthroughReactResponse(reaction=output.reaction, speech_audio=speech_audio)


@router.post("/walkthrough-tts", response_model=WalkthroughTTSResponse)
async def walkthrough_tts(
    body: WalkthroughTTSRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Generate TTS for a walkthrough instruction."""
    if not settings.groq_api_key:
        raise HTTPException(status_code=503, detail="Groq not configured")

    from app.models.demo import WalkthroughTTSResponse

    speech_audio = None
    try:
        speech_audio = await _generate_tts(body.text[:500])
    except Exception as e:
        log.warning(f"[walkthrough-tts] TTS failed: {e}")

    return WalkthroughTTSResponse(speech_audio=speech_audio)


TTS_VOICE = "autumn"
TTS_MODEL = "canopylabs/orpheus-v1-english"
TTS_SPEED = 1.15


def _tts_cache_key(text: str) -> str:
    """SHA-256 hash of text+voice+speed+model for cache lookup."""
    raw = f"{text}|{TTS_VOICE}|{TTS_SPEED}|{TTS_MODEL}"
    return hashlib.sha256(raw.encode()).hexdigest()


async def _get_tts_cache(cache_key: str) -> str | None:
    """Look up cached TTS audio from Supabase."""
    if not settings.supabase_url or not settings.supabase_service_role_key:
        return None

    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
    }
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            resp = await client.get(
                f"{settings.supabase_url}/rest/v1/tts_cache",
                headers=headers,
                params={"cache_key": f"eq.{cache_key}", "select": "audio_base64", "limit": "1"},
            )
        if resp.status_code == 200:
            rows = resp.json()
            if rows:
                log.info(f"[tts] Cache HIT for key {cache_key[:12]}...")
                return rows[0]["audio_base64"]
    except Exception as e:
        log.warning(f"[tts] Cache lookup failed: {e}")
    return None


async def _set_tts_cache(cache_key: str, text: str, audio_base64: str) -> None:
    """Store TTS audio in Supabase cache."""
    if not settings.supabase_url or not settings.supabase_service_role_key:
        return

    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=ignore-duplicates",
    }
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            await client.post(
                f"{settings.supabase_url}/rest/v1/tts_cache",
                headers=headers,
                json={
                    "cache_key": cache_key,
                    "text_input": text[:500],
                    "audio_base64": audio_base64,
                    "voice": TTS_VOICE,
                    "model": TTS_MODEL,
                    "speed": TTS_SPEED,
                },
            )
        log.info(f"[tts] Cached audio for key {cache_key[:12]}...")
    except Exception as e:
        log.warning(f"[tts] Cache write failed: {e}")


async def _generate_tts(text: str) -> str | None:
    """Generate TTS audio via Groq with Supabase caching."""
    import base64

    cache_key = _tts_cache_key(text)

    # Check cache first
    cached = await _get_tts_cache(cache_key)
    if cached:
        return cached

    # Generate fresh via Groq
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(
            "https://api.groq.com/openai/v1/audio/speech",
            headers={"Authorization": f"Bearer {settings.groq_api_key}"},
            json={
                "model": TTS_MODEL,
                "input": text,
                "voice": TTS_VOICE,
                "response_format": "wav",
                "speed": TTS_SPEED,
            },
        )
    if resp.status_code != 200:
        log.warning(f"[tts] Groq TTS returned {resp.status_code}: {resp.text[:200]}")
        return None

    audio_base64 = base64.b64encode(resp.content).decode()

    # Cache for future requests
    await _set_tts_cache(cache_key, text, audio_base64)

    return audio_base64
