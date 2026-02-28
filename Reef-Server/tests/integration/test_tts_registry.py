"""Integration tests for api/tts_stream.py — TTS registry functions."""

import time

import pytest

from api.tts_stream import (
    _pending_tts,
    cleanup_stale_tts,
    register_tts,
    register_tts_stream,
)


@pytest.fixture(autouse=True)
def clear_pending_tts():
    """Clear _pending_tts before and after each test."""
    _pending_tts.clear()
    yield
    _pending_tts.clear()


class TestRegisterTts:
    def test_returns_hex_string(self):
        tts_id = register_tts("hello world")
        assert isinstance(tts_id, str)
        assert len(tts_id) == 32  # uuid4().hex
        int(tts_id, 16)  # valid hex

    def test_entry_in_pending(self):
        tts_id = register_tts("hello")
        assert tts_id in _pending_tts
        assert _pending_tts[tts_id]["text"] == "hello"
        assert "created_at" in _pending_tts[tts_id]


class TestRegisterTtsStream:
    def test_returns_id_and_queue(self):
        tts_id, queue = register_tts_stream()
        assert isinstance(tts_id, str)
        assert len(tts_id) == 32
        assert tts_id in _pending_tts
        assert "queue" in _pending_tts[tts_id]

    def test_queue_is_usable(self):
        _, queue = register_tts_stream()
        queue.put_nowait("test sentence")
        assert queue.get_nowait() == "test sentence"


class TestCleanupStaleTts:
    async def test_removes_old_entries(self):
        tts_id = register_tts("old")
        # Backdate created_at to 10 minutes ago
        _pending_tts[tts_id]["created_at"] = time.time() - 600
        await cleanup_stale_tts()
        assert tts_id not in _pending_tts

    async def test_keeps_fresh_entries(self):
        tts_id = register_tts("fresh")
        await cleanup_stale_tts()
        assert tts_id in _pending_tts
