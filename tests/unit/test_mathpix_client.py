"""Unit tests for lib/mathpix_client.py — Mathpix session management."""
import asyncio
import os
from datetime import datetime, timedelta, timezone

import httpx
import pytest
import respx

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
from tests.helpers import load_fixture


def _make_session(minutes_until_expiry: int = 10) -> MathpixSession:
    """Return a MathpixSession that expires in the future by default."""
    return MathpixSession(
        strokes_session_id="mpx_123",
        app_token="tok_abc",
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=minutes_until_expiry),
    )


class TestCreateSession:
    @respx.mock
    async def test_returns_mathpix_session(self):
        fixture = load_fixture("mathpix_session.json")
        respx.post("https://api.mathpix.com/v3/app-tokens").mock(
            return_value=httpx.Response(200, json=fixture)
        )

        with pytest.MonkeyPatch.context() as mp:
            mp.setenv("MATHPIX_APP_ID", "test_id")
            mp.setenv("MATHPIX_APP_KEY", "test_key")
            result = await create_session()

        assert isinstance(result, MathpixSession)
        assert result.strokes_session_id == fixture["strokes_session_id"]
        assert result.app_token == fixture["app_token"]
        assert result.expires_at > datetime.now(timezone.utc)


class TestGetOrCreateSession:
    async def test_cache_hit_reuses(self, monkeypatch):
        key = ("sid", 1)
        cached = _make_session()
        _sessions[key] = cached

        called = False

        async def fake_create_session():
            nonlocal called
            called = True
            return _make_session()

        monkeypatch.setattr("lib.mathpix_client.create_session", fake_create_session)
        try:
            result = await get_or_create_session("sid", 1)
            assert result is cached
            assert not called
        finally:
            _sessions.pop(key, None)

    async def test_cache_miss_creates_new(self, monkeypatch):
        key = ("sid", 1)
        _sessions.pop(key, None)
        new_session = _make_session()

        async def fake_create_session():
            return new_session

        monkeypatch.setattr("lib.mathpix_client.create_session", fake_create_session)
        try:
            result = await get_or_create_session("sid", 1)
            assert result is new_session
            assert _sessions[key] is new_session
        finally:
            _sessions.pop(key, None)


class TestInvalidateSession:
    async def test_removes_from_all_dicts(self):
        key = ("sid", 1)
        _sessions[key] = _make_session()
        _last_stroke_hash[key] = "abc123"
        debounce_task = asyncio.ensure_future(asyncio.sleep(100))
        reasoning_task = asyncio.ensure_future(asyncio.sleep(100))
        _debounce_tasks[key] = debounce_task
        _reasoning_tasks[key] = reasoning_task

        try:
            invalidate_session("sid", 1)

            assert key not in _sessions
            assert key not in _last_stroke_hash
            assert key not in _debounce_tasks
            assert key not in _reasoning_tasks
            assert debounce_task.cancelling() > 0
            assert reasoning_task.cancelling() > 0
        finally:
            _sessions.pop(key, None)
            _last_stroke_hash.pop(key, None)
            _debounce_tasks.pop(key, None)
            _reasoning_tasks.pop(key, None)
            debounce_task.cancel()
            reasoning_task.cancel()


class TestCleanupSessions:
    async def test_removes_all_pages_for_session(self):
        key1 = ("sid", 1)
        key2 = ("sid", 2)
        other_key = ("other", 1)

        _sessions[key1] = _make_session()
        _sessions[key2] = _make_session()
        _sessions[other_key] = _make_session()

        _last_stroke_hash[key1] = "hash1"
        _last_stroke_hash[key2] = "hash2"
        _last_stroke_hash[other_key] = "hash_other"

        reasoning_task_1 = asyncio.ensure_future(asyncio.sleep(100))
        reasoning_task_2 = asyncio.ensure_future(asyncio.sleep(100))
        _reasoning_tasks[key1] = reasoning_task_1
        _reasoning_tasks[key2] = reasoning_task_2

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

            assert reasoning_task_1.cancelling() > 0
            assert reasoning_task_2.cancelling() > 0
        finally:
            _sessions.pop(key1, None)
            _sessions.pop(key2, None)
            _sessions.pop(other_key, None)
            _last_stroke_hash.pop(key1, None)
            _last_stroke_hash.pop(key2, None)
            _last_stroke_hash.pop(other_key, None)
            _reasoning_tasks.pop(key1, None)
            _reasoning_tasks.pop(key2, None)
            reasoning_task_1.cancel()
            reasoning_task_2.cancel()
