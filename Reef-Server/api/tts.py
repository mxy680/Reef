"""
WebSocket TTS endpoint — streams PCM audio chunks from Modal Kokoro TTS.

Protocol:
  Client sends:  {"type": "synthesize", "text": "...", "voice": "af_heart", "speed": 0.95}
  Server sends:  {"type": "tts_start", "sample_rate": 24000, "channels": 1, "sample_width": 2}
  Server sends:  binary PCM chunks (repeated)
  Server sends:  {"type": "tts_end"}
"""

import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from lib.tts_client import stream_tts

router = APIRouter()


@router.websocket("/ws/tts")
async def ws_tts(ws: WebSocket):
    """Long-lived WebSocket for streaming TTS synthesis."""
    await ws.accept()

    try:
        while True:
            raw = await ws.receive_text()
            msg = json.loads(raw)

            if msg.get("type") != "synthesize":
                await ws.send_json({"type": "error", "detail": "Unknown message type"})
                continue

            text = msg.get("text", "")
            voice = msg.get("voice", "af_heart")
            speed = msg.get("speed", 0.95)

            if not text:
                await ws.send_json({"type": "error", "detail": "Empty text"})
                continue

            # Signal start
            await ws.send_json({
                "type": "tts_start",
                "sample_rate": 24000,
                "channels": 1,
                "sample_width": 2,
            })

            # Stream PCM chunks from Modal via a thread (blocking HTTP)
            queue: asyncio.Queue[bytes | None] = asyncio.Queue()

            def _stream_to_queue():
                try:
                    for chunk in stream_tts(text, voice=voice, speed=speed):
                        queue.put_nowait(chunk)
                finally:
                    queue.put_nowait(None)  # sentinel

            loop = asyncio.get_event_loop()
            loop.run_in_executor(None, _stream_to_queue)

            while True:
                chunk = await queue.get()
                if chunk is None:
                    break
                await ws.send_bytes(chunk)

            # Signal end
            await ws.send_json({"type": "tts_end"})

    except WebSocketDisconnect:
        pass
    except Exception as e:
        try:
            await ws.send_json({"type": "error", "detail": str(e)})
        except Exception:
            pass
