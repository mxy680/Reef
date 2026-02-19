"""Integration tests for api/events.py — publish_event fanout."""

import asyncio
import json

from api.events import _event_queues, publish_event


class TestPublishEvent:
    async def test_no_subscribers(self):
        # Should not raise
        await publish_event("no-session", "reasoning", {"action": "silent"})

    async def test_one_subscriber(self):
        queue: asyncio.Queue = asyncio.Queue()
        _event_queues["s1"] = {queue}
        try:
            await publish_event("s1", "reasoning", {"action": "speak", "message": "hi"})
            event_type, payload = queue.get_nowait()
            assert event_type == "reasoning"
            data = json.loads(payload)
            assert data["action"] == "speak"
            assert data["message"] == "hi"
        finally:
            _event_queues.pop("s1", None)

    async def test_multiple_subscribers(self):
        q1: asyncio.Queue = asyncio.Queue()
        q2: asyncio.Queue = asyncio.Queue()
        _event_queues["s2"] = {q1, q2}
        try:
            await publish_event("s2", "tts", {"tts_id": "abc"})
            # Both queues should have the event
            for q in (q1, q2):
                event_type, payload = q.get_nowait()
                assert event_type == "tts"
                data = json.loads(payload)
                assert data["tts_id"] == "abc"
        finally:
            _event_queues.pop("s2", None)
