"""WebSocket endpoint for real-time handwriting transcription via Gemini."""

import asyncio
import base64
import json
import os

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter()

TRANSCRIPTION_PROMPT = (
    "Transcribe this handwritten math/text. "
    "Return the content as plain text. "
    "Use LaTeX notation for math expressions."
)


@router.websocket("/ws/tutor")
async def tutor_websocket(websocket: WebSocket):
    await websocket.accept()
    print("[Tutor WS] Client connected")

    # Create LLM client for this session (Gemini via OpenRouter)
    from lib.openai_client import LLMClient

    llm_client = LLMClient(
        api_key=os.getenv("OPENROUTER_API_KEY"),
        model="google/gemini-2.5-flash",
        base_url="https://openrouter.ai/api/v1",
    )

    try:
        while True:
            raw = await websocket.receive_text()
            msg = json.loads(raw)

            if msg.get("type") != "screenshot":
                continue

            batch_index = msg.get("batch_index", 0)
            image_b64 = msg.get("image", "")
            image_bytes = base64.b64decode(image_b64)

            print(
                f"[Tutor WS] Screenshot received: batch={batch_index}, "
                f"q={msg.get('question_number')}, "
                f"size={len(image_bytes)} bytes"
            )

            # Send start marker
            await websocket.send_json(
                {"type": "transcription_start", "batch_index": batch_index}
            )

            # Stream transcription from Gemini
            full_text = ""
            try:
                stream = await asyncio.to_thread(
                    lambda: list(
                        llm_client.generate_stream(
                            prompt=TRANSCRIPTION_PROMPT,
                            images=[image_bytes],
                        )
                    )
                )
                for chunk in stream:
                    full_text += chunk
                    await websocket.send_json(
                        {
                            "type": "transcription_delta",
                            "text": chunk,
                            "batch_index": batch_index,
                        }
                    )
            except Exception as e:
                print(f"[Tutor WS] Gemini error: {e}")
                await websocket.send_json(
                    {
                        "type": "error",
                        "message": str(e),
                        "batch_index": batch_index,
                    }
                )
                continue

            # Send complete marker
            await websocket.send_json(
                {
                    "type": "transcription_complete",
                    "text": full_text,
                    "batch_index": batch_index,
                }
            )
            print(
                f"[Tutor WS] Transcription complete: batch={batch_index}, "
                f"text={full_text[:80]!r}"
            )

    except WebSocketDisconnect:
        print("[Tutor WS] Client disconnected")
    except Exception as e:
        print(f"[Tutor WS] Error: {e}")
