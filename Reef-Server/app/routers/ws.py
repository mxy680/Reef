import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.auth import ws_authenticate
from app.ws.manager import manager

router = APIRouter(tags=["websocket"])


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

            await websocket.send_json(
                {"type": "echo", "received": msg_type, "data": message}
            )
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        await manager.disconnect(user.id)
