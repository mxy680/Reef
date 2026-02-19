"""HTTP TTS streaming endpoint.

Replaces binary TTS frames over WebSocket with chunked HTTP responses.
Text is registered via register_tts(), then streamed as PCM audio via GET.
"""

import asyncio
import os
import re
import time
import uuid

import httpx
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse

router = APIRouter()

# TTS config (moved from reasoning.py)
DEEPINFRA_TTS_URL = "https://api.deepinfra.com/v1/openai/audio/speech"
DEEPINFRA_TTS_MODEL = "hexgrad/Kokoro-82M"
TTS_VOICE = "af_heart"
TTS_SPEED = 0.95

# tts_id → {"text": str, "created_at": float}
_pending_tts: dict[str, dict] = {}


def register_tts(text: str) -> str:
    """Register text for TTS and return a tts_id for the client to fetch."""
    tts_id = uuid.uuid4().hex
    _pending_tts[tts_id] = {"text": text, "created_at": time.time()}
    return tts_id


def register_tts_stream() -> tuple[str, asyncio.Queue]:
    """Register a queue-based TTS stream. Caller feeds sentences into the queue.

    Returns (tts_id, queue). Put sentences as strings, None as sentinel when done.
    """
    tts_id = uuid.uuid4().hex
    queue: asyncio.Queue = asyncio.Queue()
    _pending_tts[tts_id] = {"queue": queue, "created_at": time.time()}
    return tts_id, queue


def _split_sentences(text: str) -> list[str]:
    """Split text into sentences for chunked TTS."""
    parts = re.split(r'(?<=[.!?])\s+', text.strip())
    return [p for p in parts if p]


async def _fetch_tts_chunk(client: httpx.AsyncClient, api_key: str, text: str) -> bytes:
    """Fetch TTS audio for a single text chunk."""
    resp = await client.post(
        DEEPINFRA_TTS_URL,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        json={
            "model": DEEPINFRA_TTS_MODEL,
            "input": text,
            "voice": TTS_VOICE,
            "speed": TTS_SPEED,
            "response_format": "pcm",
        },
        timeout=30.0,
    )
    resp.raise_for_status()
    return resp.content


@router.get("/api/tts/stream/{tts_id}")
async def tts_stream(tts_id: str):
    """Stream TTS audio as chunked PCM for a registered tts_id.

    Client reads X-Sample-Rate, X-Channels, X-Sample-Width headers
    to configure audio playback, then receives raw PCM bytes.

    Supports two entry types:
    - text-based (register_tts): all sentences known upfront
    - queue-based (register_tts_stream): sentences arrive dynamically from LLM
    """
    entry = _pending_tts.pop(tts_id, None)
    if not entry:
        raise HTTPException(status_code=404, detail="TTS ID not found or already consumed")

    api_key = os.getenv("DEEPINFRA_API_KEY", "")
    if not api_key:
        raise HTTPException(status_code=503, detail="DEEPINFRA_API_KEY not set")

    if "queue" in entry:
        # Queue-based: sentences arrive dynamically from LLM streaming
        queue: asyncio.Queue = entry["queue"]

        async def pcm_generator_queue():
            async with httpx.AsyncClient() as client:
                i = 0
                while True:
                    sentence = await queue.get()
                    if sentence is None:
                        break
                    try:
                        result = await _fetch_tts_chunk(client, api_key, sentence)
                        if result:
                            yield result
                    except Exception as e:
                        print(f"[tts_stream] Queue chunk {i} failed: {e}")
                    i += 1

        return StreamingResponse(
            pcm_generator_queue(),
            media_type="application/octet-stream",
            headers={
                "X-Sample-Rate": "24000",
                "X-Channels": "1",
                "X-Sample-Width": "2",
            },
        )

    # Text-based: all sentences known upfront
    text = entry["text"]
    sentences = _split_sentences(text)
    if not sentences:
        raise HTTPException(status_code=400, detail="No text to synthesize")

    async def pcm_generator():
        async with httpx.AsyncClient() as client:
            # Fire all sentence requests concurrently
            tasks = [
                asyncio.create_task(_fetch_tts_chunk(client, api_key, s))
                for s in sentences
            ]
            # Yield each in order as it resolves (don't wait for all)
            for i, task in enumerate(tasks):
                try:
                    result = await task
                    if result:
                        yield result
                except Exception as e:
                    print(f"[tts_stream] Chunk {i} failed: {e}")

    return StreamingResponse(
        pcm_generator(),
        media_type="application/octet-stream",
        headers={
            "X-Sample-Rate": "24000",
            "X-Channels": "1",
            "X-Sample-Width": "2",
        },
    )


async def cleanup_stale_tts() -> None:
    """Evict TTS entries older than 5 minutes. Run periodically."""
    cutoff = time.time() - 300
    stale = [k for k, v in _pending_tts.items() if v["created_at"] < cutoff]
    for k in stale:
        del _pending_tts[k]
    if stale:
        print(f"[tts_stream] Cleaned up {len(stale)} stale TTS entries")
