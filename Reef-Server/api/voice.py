"""REST endpoints for voice transcription.

Replaces WebSocket /ws/voice with plain HTTP POST endpoints.
Works through any proxy without WebSocket upgrade.
"""

import asyncio
import time

from fastapi import APIRouter, UploadFile, File, Form

from lib.database import get_pool
from lib.groq_transcribe import transcribe
from lib.reasoning import run_question_reasoning_streaming
from api.reasoning import push_reasoning_streaming

router = APIRouter()


@router.post("/api/voice/transcribe")
async def voice_transcribe(
    audio: UploadFile = File(...),
    session_id: str = Form(...),
    user_id: str = Form(""),
    page: int = Form(0),
):
    """Transcribe voice audio and store in DB.

    Accepts multipart form with WAV audio file.
    Returns the transcription text.
    """
    audio_bytes = await audio.read()
    if not audio_bytes:
        return {"error": "No audio received"}

    t_start = time.perf_counter()
    print(f"[voice] Transcribing {len(audio_bytes)} bytes for session={session_id[:8]}...")
    text = await asyncio.to_thread(transcribe, audio_bytes)
    t_transcribed = time.perf_counter()
    print(f"[voice] Transcription: {text}")
    print(f"[latency] voice_transcribe: whisper={t_transcribed - t_start:.3f}s")

    # Store in DB
    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO stroke_logs
                    (session_id, page, strokes, event_type, message, user_id)
                VALUES ($1, $2, '[]'::jsonb, 'voice', $3, $4)
                """,
                session_id,
                page,
                text,
                user_id,
            )
        print("[voice] Stored in DB")

    return {"transcription": text}


@router.post("/api/voice/question")
async def voice_question(
    audio: UploadFile = File(...),
    session_id: str = Form(...),
    user_id: str = Form(""),
    page: int = Form(0),
):
    """Transcribe voice question and trigger async reasoning.

    Returns transcription immediately. Reasoning result arrives via SSE.
    """
    audio_bytes = await audio.read()
    if not audio_bytes:
        return {"error": "No audio received"}

    t_start = time.perf_counter()
    print(f"[voice] Question: transcribing {len(audio_bytes)} bytes for session={session_id[:8]}...")
    text = await asyncio.to_thread(transcribe, audio_bytes)
    t_transcribed = time.perf_counter()
    print(f"[voice] Question transcription: {text}")
    print(f"[latency] voice_question: whisper={t_transcribed - t_start:.3f}s")

    # Store in DB
    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO stroke_logs
                    (session_id, page, strokes, event_type, message, user_id)
                VALUES ($1, $2, '[]'::jsonb, 'voice', $3, $4)
                """,
                session_id,
                page,
                text,
                user_id,
            )

    # Kick off reasoning in background — result arrives via SSE
    if text.strip():
        asyncio.create_task(_async_question_reasoning(session_id, page, text))

    return {"transcription": text}


async def _async_question_reasoning(session_id: str, page: int, text: str) -> None:
    """Background task: stream LLM → TTS pipeline via queue.

    1. Register streaming TTS + push SSE event (iOS starts connecting immediately)
    2. Stream LLM response, feeding sentences to the TTS queue as they're detected
    """
    try:
        tts_id, queue = await push_reasoning_streaming(session_id)
        await run_question_reasoning_streaming(session_id, page, text, queue)
    except Exception as e:
        print(f"[voice] Question reasoning failed: {e}")
