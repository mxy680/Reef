"""Fire-and-forget answer key generation for extracted questions.

After the reconstruction pipeline extracts structured Question objects,
this module generates step-by-step solutions using Claude Opus 4.6 via
the Reef inference API and stores them in the Supabase ``answer_keys``
table.  Each question is solved independently so a single failure never
blocks the rest. Falls back to Gemini Flash via OpenRouter if the
inference API is not configured.
"""

import asyncio
import json
import logging
import re

import httpx

from app.config import settings
from app.models.answer_key import PartAnswer, QuestionAnswer
from app.services.katex_validator import validate_and_fix_answer_key
from app.services.llm_client import LLMClient
from app.services.prompts import ANSWER_KEY_PROMPT

logger = logging.getLogger(__name__)

ANSWER_KEY_MODEL_INFERENCE = "claude-opus-4-6"
ANSWER_KEY_MODEL_FALLBACK = "google/gemini-3-flash-preview"


# ---------------------------------------------------------------------------
# Supabase helpers (same pattern as progress.py)
# ---------------------------------------------------------------------------


def _supabase_headers() -> dict:
    return {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }


async def _upsert_answer_key(
    document_id: str,
    question_number: int,
    question_json: dict,
    answer_text: str,
    model: str,
    input_tokens: int,
    output_tokens: int,
) -> None:
    """Insert or update an answer key row in Supabase."""
    url = f"{settings.supabase_url}/rest/v1/answer_keys"
    payload = {
        "document_id": document_id,
        "question_number": question_number,
        "question_json": question_json,
        "answer_text": answer_text,
        "model": model,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
    }
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            url, json=payload, headers=_supabase_headers(), timeout=10,
        )
        resp.raise_for_status()


# ---------------------------------------------------------------------------
# Per-question generation
# ---------------------------------------------------------------------------


async def _call_inference_api(prompt: str) -> tuple[str, str]:
    """Call the Reef inference API (Claude Opus 4.6) via SSE streaming.

    Returns (content, model_name).
    """
    async with httpx.AsyncClient(timeout=120) as client:
        async with client.stream(
            "POST",
            f"{settings.reef_inference_url}/v1/chat",
            headers={
                "Authorization": f"Bearer {settings.reef_inference_token}",
                "Content-Type": "application/json",
            },
            json={"prompt": prompt, "max_turns": 1},
        ) as resp:
            resp.raise_for_status()
            result_text = ""
            async for line in resp.aiter_lines():
                if not line.startswith("data: "):
                    continue
                payload = line[6:]
                if payload == "[DONE]":
                    break
                try:
                    event = json.loads(payload)
                    if event.get("type") == "done":
                        inner = event.get("data", {})
                        result_text = inner.get("result", "")
                        break
                except json.JSONDecodeError:
                    continue

    if not result_text:
        raise RuntimeError("Inference API returned no result")

    return result_text, ANSWER_KEY_MODEL_INFERENCE


def _extract_json(text: str) -> str:
    """Extract JSON from a response that may contain markdown code fences or explanation."""
    # Try to find JSON in code fences first
    match = re.search(r"```(?:json)?\s*\n?(.*?)\n?```", text, re.DOTALL)
    if match:
        return match.group(1).strip()
    # Try to find raw JSON object
    match = re.search(r"\{[\s\S]*\}", text)
    if match:
        return match.group(0).strip()
    return text.strip()


async def _generate_single_answer(
    document_id: str,
    question_number: int,
    question_dict: dict,
) -> None:
    """Generate and store the answer for one question. Never raises."""
    try:
        prompt = ANSWER_KEY_PROMPT.format(
            question_json=json.dumps(question_dict, indent=2),
        )

        # Add JSON schema instructions for non-structured-output APIs
        schema_instruction = (
            "\n\n## CRITICAL: Output Format\n"
            "Return ONLY a valid JSON object matching this schema. No markdown, no explanation, no code fences.\n"
            f"```json\n{json.dumps(QuestionAnswer.model_json_schema(), indent=2)}\n```"
        )

        model_used = ANSWER_KEY_MODEL_FALLBACK
        input_tokens = 0
        output_tokens = 0

        # Try Reef inference API first (Claude Opus 4.6)
        if settings.reef_inference_token:
            try:
                raw_content, model_used = await _call_inference_api(prompt + schema_instruction)
                content = _extract_json(raw_content)
                answer = QuestionAnswer.model_validate_json(content)
                logger.info(f"  [answer-key] Q{question_number}: using Reef inference (Opus 4.6)")
            except Exception as e:
                logger.warning(f"  [answer-key] Q{question_number}: inference API failed ({e}), falling back to OpenRouter")
                answer = None
        else:
            answer = None

        # Fallback to OpenRouter (Gemini Flash)
        if answer is None:
            llm_client = LLMClient(
                api_key=settings.openrouter_api_key,
                model=ANSWER_KEY_MODEL_FALLBACK,
                base_url="https://openrouter.ai/api/v1",
            )
            result = await asyncio.to_thread(
                llm_client.generate,
                prompt=prompt,
                response_schema=QuestionAnswer.model_json_schema(),
                timeout=120.0,
            )
            answer = QuestionAnswer.model_validate_json(result.content)
            model_used = ANSWER_KEY_MODEL_FALLBACK
            input_tokens = result.input_tokens
            output_tokens = result.output_tokens

        # Normalize: every question must have parts. If the LLM put steps
        # at the top level (no parts), wrap them into a single part "a".
        if answer.steps and not answer.parts:
            answer = QuestionAnswer(
                question_number=answer.question_number,
                steps=[],
                final_answer="",
                parts=[PartAnswer(
                    label="a",
                    steps=answer.steps,
                    final_answer=answer.final_answer,
                )],
            )

        # Validate LaTeX and fix KaTeX rendering errors
        llm_client_for_fix = LLMClient(
            api_key=settings.openrouter_api_key,
            model=ANSWER_KEY_MODEL_FALLBACK,
            base_url="https://openrouter.ai/api/v1",
        )
        answer = await validate_and_fix_answer_key(answer, llm_client_for_fix)

        await _upsert_answer_key(
            document_id=document_id,
            question_number=question_number,
            question_json=question_dict,
            answer_text=answer.model_dump_json(),
            model=model_used,
            input_tokens=input_tokens,
            output_tokens=output_tokens,
        )

        logger.info(
            f"  [answer-key] Q{question_number} for {document_id}: "
            f"model={model_used} {input_tokens}in/{output_tokens}out tokens"
        )
    except Exception as e:
        logger.error(
            f"  [answer-key] Q{question_number} for {document_id} failed: {e}"
        )


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


async def generate_answer_keys(
    document_id: str,
    questions: list[tuple[int, dict]],
) -> None:
    """Generate answer keys for all questions in parallel. Fire-and-forget.

    Args:
        document_id: Supabase document ID.
        questions: list of ``(question_number, question_dict)`` tuples.
    """
    if not questions or not settings.supabase_service_role_key:
        return

    tasks = [
        _generate_single_answer(document_id, q_num, q_dict)
        for q_num, q_dict in questions
    ]

    await asyncio.gather(*tasks)
    logger.info(
        f"  [answer-key] Completed {len(tasks)} answer keys for {document_id}"
    )
