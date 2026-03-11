"""POST /ai/transcribe-strokes — proxy handwriting strokes to Mathpix v3."""

import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["transcribe"])


class StrokeData(BaseModel):
    x: list[float]
    y: list[float]


class TranscribeStrokesRequest(BaseModel):
    strokes: list[StrokeData]
    session_id: str | None = None


class TranscribeStrokesResponse(BaseModel):
    latex: str
    session_id: str | None = None


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

    # Log stroke coordinate ranges for debugging
    print(f"[transcribe] {len(body.strokes)} strokes, session_id={body.session_id}")
    for i, s in enumerate(body.strokes):
        if s.x and s.y:
            print(
                f"[transcribe] Stroke {i}: x=[{min(s.x):.1f}..{max(s.x):.1f}] "
                f"y=[{min(s.y):.1f}..{max(s.y):.1f}] pts={len(s.x)}"
            )

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            "https://api.mathpix.com/v3/strokes",
            json=payload,
            headers={
                "app_id": settings.mathpix_app_id,
                "app_key": settings.mathpix_app_key,
                "Content-Type": "application/json",
            },
        )

    print(f"[transcribe] Mathpix status={resp.status_code} body={resp.text[:500]}")

    if resp.status_code != 200:
        logger.warning(f"Mathpix strokes API returned {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=502, detail="Mathpix transcription failed")

    data = resp.json()
    if "error" in data:
        print(f"[transcribe] Mathpix error: {data}")
        raise HTTPException(status_code=502, detail=f"Mathpix error: {data.get('error')}")
    latex = data.get("latex", data.get("text", ""))
    session_id = data.get("strokes_session_id", data.get("session_id"))
    return TranscribeStrokesResponse(latex=latex, session_id=session_id)
