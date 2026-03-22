"""POST /ai/transcribe-audio — transcribe uploaded audio via Groq Whisper."""

import logging

import httpx
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/transcribe-audio")
async def transcribe_audio(
    file: UploadFile = File(...),
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.groq_api_key:
        raise HTTPException(status_code=503, detail="Groq API key not configured")

    # Validate content type
    allowed_types = {"audio/m4a", "audio/aac", "audio/mpeg", "audio/wav", "audio/mp4", "audio/webm", "audio/x-m4a"}
    if not file.content_type or file.content_type not in allowed_types:
        raise HTTPException(status_code=415, detail="Unsupported audio format")

    audio_data = await file.read()
    if len(audio_data) > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=413, detail="Audio file too large")

    # Call Groq Whisper API
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            "https://api.groq.com/openai/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {settings.groq_api_key}"},
            files={"file": (file.filename or "audio.m4a", audio_data, file.content_type or "audio/m4a")},
            data={"model": "whisper-large-v3", "language": "en"},
        )

    if resp.status_code != 200:
        log.warning(f"Groq Whisper API returned {resp.status_code}: {resp.text[:200]}")
        raise HTTPException(status_code=502, detail="Transcription failed")

    text = resp.json().get("text", "").strip()
    log.info(f"[transcribe-audio] {len(audio_data)} bytes → {len(text)} chars")

    return {"text": text}
