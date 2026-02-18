"""Reasoning push — sends adaptive tutoring results to iOS via SSE.

Called by mathpix_client.py when the reasoning model decides to "speak".
Registers TTS text and publishes an SSE event so the client can stream audio.
"""

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

    tts_id = register_tts(message)
    await publish_event(session_id, "reasoning", {
        "action": action,
        "message": message,
        "tts_id": tts_id,
    })
    print(f"[reasoning] Pushed to session={session_id}: {message[:60]}")
