"""In-process WebSocket connection manager for single-worker mode."""
import asyncio
import json
import logging

from fastapi import WebSocket

log = logging.getLogger(__name__)

# user_id -> WebSocket
_connections: dict[str, WebSocket] = {}
_lock = asyncio.Lock()


async def register(user_id: str, ws: WebSocket) -> None:
    async with _lock:
        _connections[user_id] = ws


async def unregister(user_id: str) -> None:
    async with _lock:
        _connections.pop(user_id, None)


async def send_to_user(user_id: str, message: dict) -> bool:
    """Send a JSON message to a connected user. Returns True if sent."""
    async with _lock:
        ws = _connections.get(user_id)
    if ws is None:
        return False
    try:
        await ws.send_text(json.dumps(message))
        return True
    except Exception as e:
        log.warning(f"[ws-manager] Failed to send to {user_id}: {e}")
        return False
