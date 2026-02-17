"""
WebSocket endpoint for reasoning (adaptive tutoring) results.

Protocol:
  Server pushes: {"type": "reasoning", "action": "speak", "message": "..."}
  Server pushes: {"type": "tts_start", "sample_rate": 24000, "channels": 1, "sample_width": 2}
  Server pushes: binary PCM chunks (repeated)
  Server pushes: {"type": "tts_end"}
  Only "speak" results are pushed; "silent" results are logged but not sent.
"""

import asyncio
import os

import httpx
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query

router = APIRouter()

# session_id → WebSocket connection
_reasoning_connections: dict[str, WebSocket] = {}

DEEPINFRA_TTS_URL = "https://api.deepinfra.com/v1/openai/audio/speech"
DEEPINFRA_TTS_MODEL = "hexgrad/Kokoro-82M"
TTS_VOICE = "af_heart"
TTS_SPEED = 0.95


@router.websocket("/ws/reasoning")
async def ws_reasoning(ws: WebSocket, session_id: str = Query(...)):
    """Maintain a WebSocket connection for pushing reasoning results to iOS."""
    await ws.accept()
    _reasoning_connections[session_id] = ws
    print(f"[reasoning_ws] Connected: session={session_id}")

    try:
        # Keep connection alive — iOS doesn't send data on this socket
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        _reasoning_connections.pop(session_id, None)
        print(f"[reasoning_ws] Disconnected: session={session_id}")


async def _stream_tts(ws: WebSocket, text: str) -> None:
    """Call DeepInfra Kokoro TTS and stream PCM audio over the WebSocket."""
    api_key = os.getenv("DEEPINFRA_API_KEY", "")
    if not api_key:
        print("[reasoning_ws] DEEPINFRA_API_KEY not set, skipping TTS")
        return

    await ws.send_json({
        "type": "tts_start",
        "sample_rate": 24000,
        "channels": 1,
        "sample_width": 2,
    })

    async with httpx.AsyncClient() as client:
        async with client.stream(
            "POST",
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
        ) as resp:
            resp.raise_for_status()
            async for chunk in resp.aiter_bytes(chunk_size=8192):
                if chunk:
                    await ws.send_bytes(chunk)

    await ws.send_json({"type": "tts_end"})


async def push_reasoning(session_id: str, action: str, message: str) -> None:
    """Push a reasoning result to the connected iOS client.

    Only sends when action is "speak". Silent results are not pushed.
    When speaking, also streams Kokoro TTS audio via DeepInfra.
    """
    if action != "speak":
        return

    ws = _reasoning_connections.get(session_id)
    if not ws:
        print(f"[reasoning_ws] No connection for session={session_id}, skipping push")
        return

    try:
        # Send the text message first
        await ws.send_json({
            "type": "reasoning",
            "action": action,
            "message": message,
        })
        print(f"[reasoning_ws] Pushed to session={session_id}: {message[:60]}")

        # Stream TTS audio
        await _stream_tts(ws, message)
        print(f"[reasoning_ws] TTS streamed for session={session_id}")

    except Exception as e:
        print(f"[reasoning_ws] Push/TTS failed for session={session_id}: {e}")
        _reasoning_connections.pop(session_id, None)
