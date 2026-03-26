"""POST /ai/transcribe-strokes — proxy handwriting strokes to Mathpix v3 Strokes API."""

import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.services.cost_tracker import fire_cost, record_cost, MATHPIX_STROKES_PER_SESSION

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


class StrokeData(BaseModel):
    x: list[float] = Field(..., max_length=2000)
    y: list[float] = Field(..., max_length=2000)


class TranscribeStrokesRequest(BaseModel):
    strokes: list[StrokeData] = Field(..., max_length=100)
    session_id: str | None = None
    app_token: str | None = None


class TranscribeStrokesResponse(BaseModel):
    latex: str
    raw_latex: str = ""  # Unsanitized Mathpix output for LLM eval
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
        fire_cost(record_cost(user.id, "transcribe", "mathpix_strokes", MATHPIX_STROKES_PER_SESSION))
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

    # Use the client's session for temporal continuity, fall back to pool if not provided
    if body.app_token and body.session_id:
        token = body.app_token
        sid = body.session_id
    else:
        from app.services.mathpix_pool import acquire_session
        token, sid, _ = await acquire_session()

    headers = {"app_token": token, "Content-Type": "application/json"}

    payload: dict = {
        "strokes": {
            "strokes": {
                "x": [s.x for s in body.strokes],
                "y": [s.y for s in body.strokes],
            }
        },
        "strokes_session_id": sid,
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

    raw_latex = data.get("latex", data.get("text", ""))
    session_id = data.get("strokes_session_id", data.get("session_id"))

    # Return raw Mathpix output directly — no sanitization, no wrapping
    return TranscribeStrokesResponse(latex=raw_latex, raw_latex=raw_latex, session_id=session_id)
