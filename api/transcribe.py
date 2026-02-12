"""
POST /ai/transcribe — send a cluster image to Gemini Flash for handwriting transcription.

Uses the OpenAI client directly (not LLMClient) so we can read usage from
the response object and report token counts + cost back to the caller.
"""

import asyncio
import base64
import os

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from openai import OpenAI

router = APIRouter()

# Gemini 2.5 Flash Lite pricing (per 1M tokens)
INPUT_COST_PER_M = 0.10
OUTPUT_COST_PER_M = 0.40

TRANSCRIBE_PROMPT = (
    "Transcribe the handwritten text in this image exactly as written, using LaTeX notation. "
    "Return only the transcribed LaTeX, nothing else."
)


class TranscribeRequest(BaseModel):
    image: str  # base64-encoded JPEG
    cluster_id: str = ""


class UsageInfo(BaseModel):
    prompt_tokens: int
    completion_tokens: int
    cost: float


class TranscribeResponse(BaseModel):
    text: str
    cluster_id: str
    usage: UsageInfo


def _call_gemini(image_b64: str, api_key: str) -> tuple[str, int, int]:
    """Blocking call to Gemini Flash via OpenRouter. Returns (text, prompt_tokens, completion_tokens)."""
    client = OpenAI(
        api_key=api_key,
        base_url="https://openrouter.ai/api/v1",
    )

    response = client.chat.completions.create(
        model="google/gemini-2.5-flash-lite",
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": TRANSCRIBE_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                    },
                ],
            }
        ],
    )

    text = response.choices[0].message.content or ""
    prompt_tokens = response.usage.prompt_tokens if response.usage else 0
    completion_tokens = response.usage.completion_tokens if response.usage else 0
    return text, prompt_tokens, completion_tokens


@router.post("/ai/transcribe", response_model=TranscribeResponse)
async def ai_transcribe(req: TranscribeRequest):
    """Transcribe a handwritten cluster image via Gemini Flash vision."""
    # Validate that the base64 decodes to real bytes
    try:
        raw = base64.b64decode(req.image)
        if len(raw) < 100:
            raise ValueError("image too small")
    except Exception:
        raise HTTPException(status_code=422, detail="Invalid base64 image data")

    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="OPENROUTER_API_KEY not configured")

    try:
        text, prompt_tokens, completion_tokens = await asyncio.to_thread(
            _call_gemini, req.image, api_key
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Gemini API error: {e}")

    cost = (prompt_tokens * INPUT_COST_PER_M + completion_tokens * OUTPUT_COST_PER_M) / 1_000_000

    return TranscribeResponse(
        text=text,
        cluster_id=req.cluster_id,
        usage=UsageInfo(
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            cost=cost,
        ),
    )
