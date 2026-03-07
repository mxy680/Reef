import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.auth import ws_authenticate
from app.services.mathpix import create_strokes_session, send_strokes
from app.ws.manager import manager

logger = logging.getLogger(__name__)

router = APIRouter(tags=["websocket"])


async def _handle_strokes_session_start(websocket: WebSocket) -> None:
    """Create a new Mathpix strokes session and return credentials."""
    try:
        session = await create_strokes_session()
        await websocket.send_json({
            "type": "strokes_session_started",
            "app_token": session["app_token"],
            "strokes_session_id": session["strokes_session_id"],
        })
    except Exception as e:
        logger.exception("Failed to create strokes session")
        await websocket.send_json({
            "type": "error",
            "error": f"Failed to create strokes session: {e}",
        })


async def _handle_strokes(websocket: WebSocket, message: dict) -> None:
    """Send strokes to Mathpix and return recognition results."""
    strokes_x = message.get("strokes_x", [])
    strokes_y = message.get("strokes_y", [])
    session_id = message.get("strokes_session_id")
    app_token = message.get("app_token")

    if not strokes_x or not strokes_y:
        await websocket.send_json({
            "type": "error",
            "error": "strokes_x and strokes_y are required",
        })
        return

    try:
        result = await send_strokes(strokes_x, strokes_y, session_id, app_token)
        await websocket.send_json({
            "type": "strokes_result",
            "latex_styled": result.get("latex_styled", ""),
            "text": result.get("text", ""),
            "confidence": result.get("confidence", 0),
            "is_handwritten": result.get("is_handwritten", False),
        })
    except Exception as e:
        logger.exception("Mathpix strokes request failed")
        await websocket.send_json({
            "type": "error",
            "error": f"Strokes recognition failed: {e}",
        })


_MESSAGE_HANDLERS = {
    "start_strokes_session": lambda ws, _msg: _handle_strokes_session_start(ws),
    "strokes": _handle_strokes,
}


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    user = await ws_authenticate(websocket)
    if user is None:
        return

    conn = await manager.connect(websocket, user.id)
    try:
        await websocket.send_json({"type": "connected", "user_id": user.id})

        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            msg_type = message.get("type", "unknown")

            handler = _MESSAGE_HANDLERS.get(msg_type)
            if handler:
                await handler(websocket, message)
            else:
                await websocket.send_json(
                    {"type": "echo", "received": msg_type, "data": message}
                )
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        await manager.disconnect(user.id)
