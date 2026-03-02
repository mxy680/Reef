import asyncio
from dataclasses import dataclass

from fastapi import WebSocket


@dataclass
class Connection:
    websocket: WebSocket
    user_id: str


class ConnectionManager:
    def __init__(self):
        self._connections: dict[str, Connection] = {}
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, user_id: str) -> Connection:
        await websocket.accept()
        conn = Connection(websocket=websocket, user_id=user_id)
        async with self._lock:
            if user_id in self._connections:
                old = self._connections[user_id]
                try:
                    await old.websocket.close(code=4000, reason="New connection")
                except Exception:
                    pass
            self._connections[user_id] = conn
        return conn

    async def disconnect(self, user_id: str):
        async with self._lock:
            self._connections.pop(user_id, None)

    async def send_json(self, user_id: str, data: dict):
        async with self._lock:
            conn = self._connections.get(user_id)
        if conn:
            await conn.websocket.send_json(data)

    @property
    def active_count(self) -> int:
        return len(self._connections)


manager = ConnectionManager()
