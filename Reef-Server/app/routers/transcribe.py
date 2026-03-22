"""POST /ai/transcribe-strokes — proxy handwriting strokes to Mathpix v3 Strokes API."""

import asyncio
import logging
import re as _re

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.services.katex_sanitizer import sanitize_for_katex
from app.services.katex_validator import KATEX_FIX_PROMPT, _validate_katex_expression
from app.services.llm_client import LLMClient

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


class StrokeData(BaseModel):
    x: list[float]
    y: list[float]


class TranscribeStrokesRequest(BaseModel):
    strokes: list[StrokeData]
    session_id: str | None = None
    app_token: str | None = None


class TranscribeStrokesResponse(BaseModel):
    latex: str
    session_id: str | None = None


class CreateSessionResponse(BaseModel):
    app_token: str
    strokes_session_id: str
    expires_at: int  # unix timestamp ms


@router.post("/strokes-session", response_model=CreateSessionResponse)
async def create_strokes_session(
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.mathpix_app_key:
        raise HTTPException(status_code=503, detail="Mathpix credentials not configured")

    try:
        from app.services.mathpix_pool import acquire_session
        token, session_id, expires_at = await acquire_session()
        return CreateSessionResponse(
            app_token=token,
            strokes_session_id=session_id,
            expires_at=expires_at,
        )
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))


@router.post("/transcribe-strokes", response_model=TranscribeStrokesResponse)
async def transcribe_strokes(
    body: TranscribeStrokesRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.mathpix_app_id or not settings.mathpix_app_key:
        raise HTTPException(status_code=503, detail="Mathpix credentials not configured")

    payload: dict = {
        "strokes": {
            "strokes": {
                "x": [s.x for s in body.strokes],
                "y": [s.y for s in body.strokes],
            }
        },
    }
    if body.session_id:
        payload["strokes_session_id"] = body.session_id

    if body.app_token:
        headers = {"app_token": body.app_token, "Content-Type": "application/json"}
    else:
        headers = {
            "app_id": settings.mathpix_app_id,
            "app_key": settings.mathpix_app_key,
            "Content-Type": "application/json",
        }

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            "https://api.mathpix.com/v3/strokes",
            json=payload,
            headers=headers,
        )

    if resp.status_code != 200:
        log.warning(f"Mathpix strokes API returned {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=502, detail="Mathpix transcription failed")

    data = resp.json()
    if "error" in data:
        raise HTTPException(status_code=502, detail=f"Mathpix error: {data.get('error')}")

    latex = data.get("latex", data.get("text", ""))
    session_id = data.get("strokes_session_id", data.get("session_id"))

    # Sanitize for KaTeX compatibility before wrapping
    if latex:
        latex = sanitize_for_katex(latex)

        # Validate — if KaTeX still fails, try LLM fix (once)
        error = await asyncio.to_thread(_validate_katex_expression, latex)
        if error:
            log.warning(f"KaTeX validation failed after sanitize: {error[:80]}")
            try:
                llm = LLMClient(
                    api_key=settings.openrouter_api_key,
                    model="google/gemini-2.0-flash-001",
                    base_url="https://openrouter.ai/api/v1",
                )
                fix_prompt = KATEX_FIX_PROMPT.format(expression=latex, error=error)
                result = await asyncio.to_thread(
                    llm.generate, prompt=fix_prompt, timeout=10.0,
                )
                fixed = result.content.strip()
                if fixed.startswith("```"):
                    fixed = _re.sub(r"^```\w*\n?", "", fixed)
                    fixed = _re.sub(r"\n?```$", "", fixed)
                # Only use fix if it validates
                fix_error = await asyncio.to_thread(_validate_katex_expression, fixed)
                if not fix_error:
                    latex = fixed
                    log.info("KaTeX fix succeeded via LLM")
            except Exception as e:
                log.warning(f"KaTeX LLM fix failed: {e}")

    # Wrap in display math delimiters if not already wrapped
    if latex and not latex.startswith("$") and not latex.startswith("\\[") and not latex.startswith("\\("):
        latex = f"$$ {latex} $$"
    return TranscribeStrokesResponse(latex=latex, session_id=session_id)
