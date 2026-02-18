"""SSE endpoint for server→client push events.

Replaces WebSocket /ws/reasoning with plain HTTP Server-Sent Events.
Works through any proxy (Cloudflare, nginx) without WebSocket upgrade.
"""

import asyncio
import json

from fastapi import APIRouter, Query
from fastapi.responses import StreamingResponse

router = APIRouter()

# session_id → set of subscriber queues
_event_queues: dict[str, set[asyncio.Queue]] = {}


async def publish_event(session_id: str, event_type: str, data: dict) -> None:
    """Push an event to all SSE subscribers for a session."""
    queues = _event_queues.get(session_id)
    if not queues:
        print(f"[sse] No subscribers for session={session_id}, dropping {event_type}")
        return
    payload = json.dumps(data)
    for q in list(queues):  # snapshot to avoid concurrent modification
        await q.put((event_type, payload))
    print(f"[sse] Published {event_type} to {len(queues)} subscriber(s) for session={session_id}")


def remove_session(session_id: str) -> None:
    """Remove all subscribers for a session."""
    _event_queues.pop(session_id, None)


@router.get("/api/events")
async def sse_events(session_id: str = Query(...)):
    """Server-Sent Events stream for a session.

    Pushes reasoning results, TTS notifications, and other events.
    Sends keepalive comments every 25s to prevent idle disconnect.
    """

    async def event_generator():
        queue: asyncio.Queue = asyncio.Queue()
        # Register this subscriber
        if session_id not in _event_queues:
            _event_queues[session_id] = set()
        _event_queues[session_id].add(queue)
        print(f"[sse] Connected: session={session_id}")

        try:
            while True:
                try:
                    event_type, payload = await asyncio.wait_for(queue.get(), timeout=25)
                    yield f"event: {event_type}\ndata: {payload}\n\n"
                except asyncio.TimeoutError:
                    yield ": keepalive\n\n"
        except asyncio.CancelledError:
            pass
        finally:
            # Cleanup on disconnect
            subscribers = _event_queues.get(session_id)
            if subscribers:
                subscribers.discard(queue)
                if not subscribers:
                    del _event_queues[session_id]
            print(f"[sse] Disconnected: session={session_id}")

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
