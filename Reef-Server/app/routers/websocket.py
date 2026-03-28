"""WebSocket endpoint for real-time server-to-client push (e.g. simulation strokes)."""

import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.auth import ws_authenticate
from app.services import ws_manager

log = logging.getLogger(__name__)

router = APIRouter(tags=["websocket"])


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    """Single persistent WebSocket connection per user.

    Auth: JWT passed as ?token= query param.
    The server pushes messages (e.g. simulation strokes) through this channel.
    """
    user = await ws_authenticate(websocket)
    if user is None:
        return  # ws_authenticate already closed the socket

    await websocket.accept()
    await ws_manager.register(user.id, websocket)
    log.info(f"[ws] Connected: {user.id}")

    try:
        # Keep the connection alive; we only push server → client here.
        # We still drain incoming frames to detect disconnect.
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        log.info(f"[ws] Disconnected: {user.id}")
    except Exception as e:
        log.warning(f"[ws] Error for {user.id}: {e}")
    finally:
        await ws_manager.unregister(user.id)
