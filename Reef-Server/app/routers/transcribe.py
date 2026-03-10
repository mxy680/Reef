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


class TranscribeStrokesResponse(BaseModel):
    latex: str


@router.post("/transcribe-strokes", response_model=TranscribeStrokesResponse)
async def transcribe_strokes(
    body: TranscribeStrokesRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.mathpix_app_id or not settings.mathpix_app_key:
        raise HTTPException(status_code=503, detail="Mathpix credentials not configured")

    payload = {
        "strokes": [{"x": s.x, "y": s.y} for s in body.strokes],
    }

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

    if resp.status_code != 200:
        logger.warning(f"Mathpix strokes API returned {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=502, detail="Mathpix transcription failed")

    data = resp.json()
    latex = data.get("latex", data.get("text", ""))
    return TranscribeStrokesResponse(latex=latex)
