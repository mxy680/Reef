"""Fire-and-forget answer key generation for extracted questions.

After the reconstruction pipeline extracts structured Question objects,
this module generates step-by-step solutions using Gemini Flash and stores
them in the Supabase ``answer_keys`` table.  Each question is solved
independently so a single failure never blocks the rest.
"""

import asyncio
import json
import logging

import httpx

from app.config import settings
from app.models.answer_key import QuestionAnswer
from app.services.llm_client import LLMClient
from app.services.prompts import ANSWER_KEY_PROMPT

logger = logging.getLogger(__name__)

ANSWER_KEY_MODEL = "google/gemini-3-flash-preview"


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


async def _generate_single_answer(
    document_id: str,
    question_number: int,
    question_dict: dict,
) -> None:
    """Generate and store the answer for one question. Never raises."""
    try:
        # Each call gets its own LLMClient to avoid thread-safety issues
        # with _strict_json_supported state when using asyncio.to_thread.
        llm_client = LLMClient(
            api_key=settings.openrouter_api_key,
            model=ANSWER_KEY_MODEL,
            base_url="https://openrouter.ai/api/v1",
        )

        prompt = ANSWER_KEY_PROMPT.format(
            question_json=json.dumps(question_dict, indent=2),
        )

        result = await asyncio.to_thread(
            llm_client.generate,
            prompt=prompt,
            response_schema=QuestionAnswer.model_json_schema(),
            timeout=120.0,
        )

        answer = QuestionAnswer.model_validate_json(result.content)

        await _upsert_answer_key(
            document_id=document_id,
            question_number=question_number,
            question_json=question_dict,
            answer_text=answer.model_dump_json(),
            model=ANSWER_KEY_MODEL,
            input_tokens=result.input_tokens,
            output_tokens=result.output_tokens,
        )

        logger.info(
            f"  [answer-key] Q{question_number} for {document_id}: "
            f"{result.input_tokens}in/{result.output_tokens}out tokens"
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
