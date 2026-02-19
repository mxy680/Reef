"""Unit tests for lib/mathpix_client.py — Mathpix session management."""
import asyncio
import os
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from lib.mathpix_client import (
    MathpixSession,
    _debounce_tasks,
    _last_stroke_hash,
    _reasoning_tasks,
    _sessions,
    cleanup_sessions,
    create_session,
    get_or_create_session,
    invalidate_session,
)


def _make_session(minutes_until_expiry: int = 10) -> MathpixSession:
    """Return a MathpixSession that expires in the future by default."""
    return MathpixSession(
        strokes_session_id="mpx_123",
        app_token="tok_abc",
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=minutes_until_expiry),
    )


class TestCreateSession:
    async def test_returns_mathpix_session(self):
        mock_response = MagicMock()
        mock_response.json.return_value = {
            "strokes_session_id": "mpx_123",
            "app_token": "tok_abc",
        }
        mock_response.raise_for_status = MagicMock()

        mock_client = AsyncMock()
        mock_client.post = AsyncMock(return_value=mock_response)
        mock_async_context = MagicMock()
        mock_async_context.__aenter__ = AsyncMock(return_value=mock_client)
        mock_async_context.__aexit__ = AsyncMock(return_value=False)

        with patch.dict(os.environ, {"MATHPIX_APP_ID": "test_id", "MATHPIX_APP_KEY": "test_key"}):
            with patch("lib.mathpix_client.httpx.AsyncClient", return_value=mock_async_context):
                result = await create_session()

        assert isinstance(result, MathpixSession)
        assert result.strokes_session_id == "mpx_123"
        assert result.app_token == "tok_abc"
        assert result.expires_at > datetime.now(timezone.utc)


class TestGetOrCreateSession:
    async def test_cache_hit_reuses(self):
        key = ("sid", 1)
        cached = _make_session()
        _sessions[key] = cached
        try:
            with patch("lib.mathpix_client.create_session") as mock_create:
                result = await get_or_create_session("sid", 1)
            assert result is cached
            mock_create.assert_not_called()
        finally:
            _sessions.pop(key, None)

    async def test_cache_miss_creates_new(self):
        key = ("sid", 1)
        _sessions.pop(key, None)
        new_session = _make_session()
        try:
            with patch(
                "lib.mathpix_client.create_session",
                new=AsyncMock(return_value=new_session),
            ):
                result = await get_or_create_session("sid", 1)
            assert result is new_session
            assert _sessions[key] is new_session
        finally:
            _sessions.pop(key, None)


class TestInvalidateSession:
    def test_removes_from_all_dicts(self):
        key = ("sid", 1)
        _sessions[key] = _make_session()
        _last_stroke_hash[key] = "abc123"
        mock_debounce = MagicMock()
        mock_reasoning = MagicMock()
        _debounce_tasks[key] = mock_debounce
        _reasoning_tasks[key] = mock_reasoning

        try:
            invalidate_session("sid", 1)

            assert key not in _sessions
            assert key not in _last_stroke_hash
            assert key not in _debounce_tasks
            assert key not in _reasoning_tasks
            mock_debounce.cancel.assert_called_once()
            mock_reasoning.cancel.assert_called_once()
        finally:
            _sessions.pop(key, None)
            _last_stroke_hash.pop(key, None)
            _debounce_tasks.pop(key, None)
            _reasoning_tasks.pop(key, None)


class TestCleanupSessions:
    def test_removes_all_pages_for_session(self):
        key1 = ("sid", 1)
        key2 = ("sid", 2)
        other_key = ("other", 1)

        _sessions[key1] = _make_session()
        _sessions[key2] = _make_session()
        _sessions[other_key] = _make_session()

        _last_stroke_hash[key1] = "hash1"
        _last_stroke_hash[key2] = "hash2"
        _last_stroke_hash[other_key] = "hash_other"

        mock_reasoning_1 = MagicMock()
        mock_reasoning_2 = MagicMock()
        _reasoning_tasks[key1] = mock_reasoning_1
        _reasoning_tasks[key2] = mock_reasoning_2

        try:
            cleanup_sessions("sid")

            assert key1 not in _sessions
            assert key2 not in _sessions
            assert other_key in _sessions

            assert key1 not in _last_stroke_hash
            assert key2 not in _last_stroke_hash
            assert other_key in _last_stroke_hash

            assert key1 not in _reasoning_tasks
            assert key2 not in _reasoning_tasks

            mock_reasoning_1.cancel.assert_called_once()
            mock_reasoning_2.cancel.assert_called_once()
        finally:
            _sessions.pop(key1, None)
            _sessions.pop(key2, None)
            _sessions.pop(other_key, None)
            _last_stroke_hash.pop(key1, None)
            _last_stroke_hash.pop(key2, None)
            _last_stroke_hash.pop(other_key, None)
            _reasoning_tasks.pop(key1, None)
            _reasoning_tasks.pop(key2, None)
