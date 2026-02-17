"""
WebSocket endpoint for voice message transcription.

Protocol:
  Client sends:  {"type": "voice_start", "session_id": "...", "user_id": "...", "page": 1}
  Client sends:  binary audio data (WAV)
  Client sends:  {"type": "voice_end"}
  Server sends:  {"type": "ack", "transcription": "..."}
"""

import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from lib.database import get_pool
from lib.groq_transcribe import transcribe
from lib.reasoning import run_question_reasoning
from api.reasoning import push_reasoning

router = APIRouter()


@router.websocket("/ws/voice")
async def ws_voice(ws: WebSocket):
    """Receive audio from iPad, transcribe with Groq, store in DB."""
    await ws.accept()
    print("[voice_ws] Connection accepted")

    try:
        while True:
            # Wait for voice_start (accept both text and binary frames)
            print("[voice_ws] Waiting for voice_start...")
            ws_msg = await ws.receive()
            print(f"[voice_ws] Received frame: text={('text' in ws_msg)}, bytes={('bytes' in ws_msg)}")

            if "text" in ws_msg:
                msg = json.loads(ws_msg["text"])
            else:
                print("[voice_ws] Unexpected binary frame, skipping")
                continue

            if msg.get("type") != "voice_start":
                print(f"[voice_ws] Unexpected type: {msg.get('type')}")
                await ws.send_json({"type": "error", "detail": "Expected voice_start"})
                continue

            session_id = msg.get("session_id", "")
            user_id = msg.get("user_id", "")
            page = msg.get("page", 0)
            mode = msg.get("mode", "")
            print(f"[voice_ws] voice_start: session={session_id[:8]}..., page={page}")

            # Accumulate binary audio chunks until voice_end
            audio_buffer = bytearray()
            while True:
                ws_msg = await ws.receive()
                if "text" in ws_msg:
                    inner = json.loads(ws_msg["text"])
                    if inner.get("type") == "voice_end":
                        print(f"[voice_ws] voice_end received, {len(audio_buffer)} bytes of audio")
                        break
                elif "bytes" in ws_msg:
                    audio_buffer.extend(ws_msg["bytes"])
                    print(f"[voice_ws] Received audio chunk: {len(ws_msg['bytes'])} bytes (total: {len(audio_buffer)})")

            if not audio_buffer:
                await ws.send_json({"type": "error", "detail": "No audio received"})
                continue

            # Transcribe in a thread (blocking OpenAI SDK call)
            print(f"[voice_ws] Transcribing {len(audio_buffer)} bytes with Groq...")
            text = await asyncio.to_thread(transcribe, bytes(audio_buffer))
            print(f"[voice_ws] Transcription: {text}")

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
                print("[voice_ws] Stored in DB")

            await ws.send_json({"type": "ack", "transcription": text})
            print("[voice_ws] Sent ack")

            # If this is a question, run reasoning immediately and push via reasoning WS
            if mode == "question" and text.strip():
                try:
                    result = await run_question_reasoning(session_id, page, text)
                    await push_reasoning(session_id, result["action"], result["message"])
                except Exception as e:
                    print(f"[voice_ws] Question reasoning failed: {e}")

    except WebSocketDisconnect:
        pass
    except Exception as e:
        try:
            await ws.send_json({"type": "error", "detail": str(e)})
        except Exception:
            pass
