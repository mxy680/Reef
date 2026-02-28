"""Reasoning push — sends adaptive tutoring results to iOS via SSE.

Called by mathpix_client.py when the reasoning model decides to "speak".
Registers TTS text and publishes an SSE event so the client can stream audio.
"""

import time

from fastapi import APIRouter

router = APIRouter()


async def push_reasoning(session_id: str, action: str, message: str) -> None:
    """Push a reasoning result to the connected iOS client via SSE.

    Only sends when action is "speak". Silent results are not pushed.
    Registers TTS text and includes the tts_id so the client can fetch audio.
    """
    if action != "speak":
        return

    from api.tts_stream import register_tts
    from api.events import publish_event

    t0 = time.perf_counter()
    tts_id = register_tts(message)
    await publish_event(session_id, "reasoning", {
        "action": action,
        "message": message,
        "tts_id": tts_id,
    })
    t1 = time.perf_counter()
    print(f"[reasoning] Pushed to session={session_id} ({t1 - t0:.3f}s): {message[:60]}")


async def push_reasoning_streaming(session_id: str) -> tuple[str, "asyncio.Queue"]:
    """Register a streaming TTS entry and push SSE event immediately.

    iOS gets the tts_id right away and starts connecting to the TTS endpoint
    while the LLM is still generating.

    Returns (tts_id, queue) for the caller to feed sentences into.
    """
    import asyncio
    from api.tts_stream import register_tts_stream
    from api.events import publish_event

    tts_id, queue = register_tts_stream()
    await publish_event(session_id, "reasoning", {
        "action": "speak",
        "message": "",
        "tts_id": tts_id,
    })
    print(f"[reasoning] Pushed streaming tts_id={tts_id[:8]} to session={session_id}")
    return tts_id, queue
