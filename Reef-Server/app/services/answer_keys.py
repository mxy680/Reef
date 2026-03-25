"""Fire-and-forget answer key generation for extracted questions.

After the reconstruction pipeline extracts structured Question objects,
this module generates step-by-step solutions using DeepSeek R1 via
OpenRouter and stores them in the Supabase ``answer_keys`` table.
Each question is solved independently so a single failure never
blocks the rest.
"""

import asyncio
import json
import logging

import httpx

from app.config import settings
from app.models.answer_key import PartAnswer, QuestionAnswer
from app.services.inference_client import extract_json
from app.services.katex_validator import validate_and_fix_answer_key
from app.services.llm_client import LLMClient
from app.services.prompts import ANSWER_KEY_PROMPT

logger = logging.getLogger(__name__)

ANSWER_KEY_MODEL = "deepseek/deepseek-r1"


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
    figure_images: list[bytes] | None = None,
) -> None:
    """Generate and store the answer for one question. Never raises."""
    try:
        prompt = ANSWER_KEY_PROMPT.format(
            question_json=json.dumps(question_dict, indent=2),
        )

        if figure_images:
            prompt += (
                "\n\n## Attached Figures\n"
                f"{len(figure_images)} figure image(s) are attached. These are the diagrams "
                "referenced in the question (e.g. free body diagrams, circuits, beam layouts, "
                "geometric configurations). Examine them carefully — the values, angles, "
                "dimensions, and labels in the figures are critical for generating correct solutions."
            )

        # Add JSON schema instructions for non-structured-output APIs
        schema_instruction = (
            "\n\n## CRITICAL: Output Format\n"
            "Return ONLY a valid JSON object matching this schema. No markdown, no explanation, no code fences.\n"
            f"```json\n{json.dumps(QuestionAnswer.model_json_schema(), indent=2)}\n```"
        )

        model_used = ANSWER_KEY_MODEL
        input_tokens = 0
        output_tokens = 0

        llm_client = LLMClient(
            api_key=settings.openrouter_api_key,
            model=ANSWER_KEY_MODEL,
            base_url="https://openrouter.ai/api/v1",
        )
        result = await asyncio.to_thread(
            llm_client.generate,
            prompt=prompt + schema_instruction,
            images=figure_images,
            response_schema=QuestionAnswer.model_json_schema(),
            timeout=180.0,
        )
        content = extract_json(result.content)
        answer = QuestionAnswer.model_validate_json(content)
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
        answer = await validate_and_fix_answer_key(answer, llm_client)

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
    image_data: dict[str, bytes] | None = None,
) -> None:
    """Generate answer keys for all questions in parallel. Fire-and-forget.

    Args:
        document_id: Supabase document ID.
        questions: list of ``(question_number, question_dict)`` tuples.
        image_data: dict of ``{filename: image_bytes}`` from Mathpix OCR.
    """
    if not questions or not settings.supabase_service_role_key:
        return

    def _get_question_images(q_dict: dict) -> list[bytes] | None:
        """Collect figure image bytes for a question and its parts."""
        if not image_data:
            return None
        figures: set[str] = set(q_dict.get("figures", []))
        for part in q_dict.get("parts", []):
            figures.update(part.get("figures", []))
            for sub in part.get("parts", []):
                figures.update(sub.get("figures", []))
        imgs = [image_data[f] for f in figures if f in image_data]
        return imgs if imgs else None

    # Run answer key generation in parallel (inference API supports concurrent agents)
    tasks = [
        _generate_single_answer(document_id, q_num, q_dict, figure_images=_get_question_images(q_dict))
        for q_num, q_dict in questions
    ]

    await asyncio.gather(*tasks)
    logger.info(
        f"  [answer-key] Completed {len(tasks)} answer keys for {document_id}"
    )
