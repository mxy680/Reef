"""POST /ai/demo-problem — generate a practice problem for onboarding demo.
POST /ai/demo-chat — chat with tutor about the demo problem (no auth required)."""

import asyncio
import logging

import httpx
from fastapi import APIRouter, HTTPException

from app.config import settings
from app.models.demo import (
    DemoChatRequest, DemoChatResponse,
    DemoProblem, DemoProblemRequest, DemoProblemResponse,
)
from app.models.tutor import TutorChatLLMOutput
from app.services.llm_client import LLMClient

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

TUTOR_MODEL = "google/gemini-3-flash-preview"

DEMO_PROBLEM_SYSTEM = """\
You are a math and science problem generator for college students. Generate a single practice problem \
on the given topic that is interesting, clear, and solvable in 2-3 steps. The problem should be \
challenging enough to be worth solving but not so hard that a student would give up.
"""

DEMO_PROBLEM_PROMPT = """\
Generate a practice problem about: {topic}
Student level: {student_type}

Requirements:
- The problem should have 2-3 clear solution steps
- Each step should involve meaningful work (not just "plug in values")
- Use $...$ for inline math and \\[...\\] for display math in the question text
- The tutor_intro should be casual and friendly — like a TA saying "let's try this"
- Keep the problem focused on a single concept
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
async def demo_problem(body: DemoProblemRequest):
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
async def demo_chat(body: DemoChatRequest):
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
