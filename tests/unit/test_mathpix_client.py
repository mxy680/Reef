"""Unit tests for lib/mathpix_client.py — Mathpix session management."""
import asyncio
import os
from collections import deque
from datetime import datetime, timedelta, timezone

import httpx
import pytest
import respx

from lib.mathpix_client import (
    DELAYED_SPEAK_SECONDS,
    MathpixSession,
    _debounce_tasks,
    _erase_snapshots,
    _last_stroke_hash,
    _pending_delayed,
    _reasoning_tasks,
    _sessions,
    cleanup_sessions,
    create_session,
    get_or_create_session,
    invalidate_session,
    schedule_reasoning,
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


class TestDiagramModeSkipsMathpix:
    """When content_mode is 'diagram', transcription should skip Mathpix
    and go straight to reasoning with an empty page_transcription."""

    async def test_diagram_mode_skips_mathpix_upserts_empty(self, monkeypatch):
        """Diagram mode should upsert page_transcriptions with empty text
        and schedule reasoning without calling Mathpix."""
        import asyncio

        from tests.helpers import FakePool

        pool = FakePool()
        monkeypatch.setattr("lib.mathpix_client.get_pool", lambda: pool)

        # Mock _active_sessions to return diagram mode via the import path
        # _debounced_transcribe imports from api.strokes
        mock_sessions = {"sid": {"content_mode": "diagram"}}
        monkeypatch.setattr("api.strokes._active_sessions", mock_sessions)

        # Track reasoning scheduling
        reasoning_scheduled = []

        def fake_schedule_reasoning(session_id, page):
            reasoning_scheduled.append((session_id, page))

        monkeypatch.setattr(
            "lib.mathpix_client.schedule_reasoning",
            fake_schedule_reasoning,
        )

        from lib.mathpix_client import _debounced_transcribe
        monkeypatch.setattr("lib.mathpix_client.DEBOUNCE_SECONDS", 0)

        await _debounced_transcribe("sid", 1)

        # Should have upserted empty transcription
        assert len(pool.conn.calls) == 1
        query = pool.conn.calls[0][0]
        assert "page_transcriptions" in query
        assert "INSERT" in query

        # Should have scheduled reasoning
        assert ("sid", 1) in reasoning_scheduled


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


class TestEraseSnapshotCapture:
    async def test_erase_event_captures_pre_erase_text(self, monkeypatch):
        """When the most recent stroke event is an erase, the current
        page_transcriptions.text should be snapshotted before Mathpix runs."""

        class SnapshotConn:
            def __init__(self):
                self.calls = []

            async def execute(self, query, *args):
                self.calls.append(("execute", query, *args))

            async def fetchrow(self, query, *args):
                if "page_transcriptions" in query:
                    return {"text": "x^2 + 3x = 0"}
                return None

            async def fetch(self, query, *args):
                if "stroke_logs" in query:
                    # Simulate LIMIT 1 ORDER BY received_at DESC: erase is most recent
                    return [{"id": 2, "strokes": "[]", "event_type": "erase"}]
                return []

        class SnapshotPool:
            def __init__(self):
                self.conn = SnapshotConn()
            def acquire(self):
                from tests.helpers import _FakeAcquireCtx
                return _FakeAcquireCtx(self.conn)

        pool = SnapshotPool()
        monkeypatch.setattr("lib.mathpix_client.get_pool", lambda: pool)
        monkeypatch.setattr("lib.mathpix_client.DEBOUNCE_SECONDS", 0)

        # Math mode (not diagram)
        monkeypatch.setattr("api.strokes._active_sessions", {"sid": {"content_mode": "math"}})

        # No Mathpix credentials — will skip to reasoning after snapshot
        monkeypatch.delenv("MATHPIX_APP_ID", raising=False)
        monkeypatch.delenv("MATHPIX_APP_KEY", raising=False)

        # Stub reasoning
        monkeypatch.setattr("lib.mathpix_client.schedule_reasoning", lambda sid, page: None)

        from lib.mathpix_client import _erase_snapshots, _debounced_transcribe
        key = ("sid", 1)
        _erase_snapshots.pop(key, None)

        try:
            await _debounced_transcribe("sid", 1)
            assert key in _erase_snapshots
            assert list(_erase_snapshots[key]) == ["x^2 + 3x = 0"]
        finally:
            _erase_snapshots.pop(key, None)

    async def test_no_snapshot_when_no_erase(self, monkeypatch):
        """When the most recent event is a draw (not erase), no snapshot is taken."""

        class DrawOnlyConn:
            async def execute(self, query, *args):
                pass
            async def fetchrow(self, query, *args):
                return None
            async def fetch(self, query, *args):
                if "stroke_logs" in query:
                    # Simulate LIMIT 1 ORDER BY received_at DESC: most recent is draw
                    return [{"id": 2, "strokes": "[]", "event_type": "draw"}]
                return []

        class DrawOnlyPool:
            def __init__(self):
                self.conn = DrawOnlyConn()
            def acquire(self):
                from tests.helpers import _FakeAcquireCtx
                return _FakeAcquireCtx(self.conn)

        monkeypatch.setattr("lib.mathpix_client.get_pool", lambda: DrawOnlyPool())
        monkeypatch.setattr("lib.mathpix_client.DEBOUNCE_SECONDS", 0)
        monkeypatch.setattr("api.strokes._active_sessions", {"sid": {"content_mode": "math"}})
        monkeypatch.delenv("MATHPIX_APP_ID", raising=False)
        monkeypatch.delenv("MATHPIX_APP_KEY", raising=False)
        monkeypatch.setattr("lib.mathpix_client.schedule_reasoning", lambda sid, page: None)

        from lib.mathpix_client import _erase_snapshots, _debounced_transcribe
        key = ("sid", 1)
        _erase_snapshots.pop(key, None)

        try:
            await _debounced_transcribe("sid", 1)
            assert key not in _erase_snapshots
        finally:
            _erase_snapshots.pop(key, None)


class TestEraseSnapshotCleanup:
    def test_invalidate_session_clears_erase_snapshots(self):
        key = ("sid", 1)
        _erase_snapshots[key] = deque(["old work"], maxlen=3)
        try:
            invalidate_session("sid", 1)
            assert key not in _erase_snapshots
        finally:
            _erase_snapshots.pop(key, None)

    def test_cleanup_sessions_clears_all_pages(self):
        key1 = ("sid", 1)
        key2 = ("sid", 2)
        other = ("other", 1)
        _erase_snapshots[key1] = deque(["work1"], maxlen=3)
        _erase_snapshots[key2] = deque(["work2"], maxlen=3)
        _erase_snapshots[other] = deque(["keep"], maxlen=3)
        try:
            cleanup_sessions("sid")
            assert key1 not in _erase_snapshots
            assert key2 not in _erase_snapshots
            assert other in _erase_snapshots
        finally:
            _erase_snapshots.pop(key1, None)
            _erase_snapshots.pop(key2, None)
            _erase_snapshots.pop(other, None)


class TestPendingDelayedCleanup:
    async def test_invalidate_session_cancels_pending_delayed(self):
        key = ("sid", 1)
        delayed_task = asyncio.ensure_future(asyncio.sleep(100))
        _pending_delayed[key] = delayed_task
        try:
            invalidate_session("sid", 1)
            assert key not in _pending_delayed
            assert delayed_task.cancelling() > 0
        finally:
            _pending_delayed.pop(key, None)
            delayed_task.cancel()

    async def test_cleanup_sessions_cancels_all_pending_delayed(self):
        key1 = ("sid", 1)
        key2 = ("sid", 2)
        other = ("other", 1)
        t1 = asyncio.ensure_future(asyncio.sleep(100))
        t2 = asyncio.ensure_future(asyncio.sleep(100))
        t3 = asyncio.ensure_future(asyncio.sleep(100))
        _pending_delayed[key1] = t1
        _pending_delayed[key2] = t2
        _pending_delayed[other] = t3
        try:
            cleanup_sessions("sid")
            assert key1 not in _pending_delayed
            assert key2 not in _pending_delayed
            assert other in _pending_delayed
            assert t1.cancelling() > 0
            assert t2.cancelling() > 0
        finally:
            _pending_delayed.pop(key1, None)
            _pending_delayed.pop(key2, None)
            _pending_delayed.pop(other, None)
            t1.cancel()
            t2.cancel()
            t3.cancel()


class TestScheduleReasoningCancelsDelayed:
    async def test_schedule_reasoning_cancels_pending_delayed(self, monkeypatch):
        """When new reasoning is scheduled, any pending delayed-speak should be cancelled."""
        key = ("sid", 1)
        delayed_task = asyncio.ensure_future(asyncio.sleep(100))
        _pending_delayed[key] = delayed_task

        # Stub _debounced_reasoning so schedule_reasoning doesn't actually run reasoning
        async def fake_debounced(sid, page):
            await asyncio.sleep(100)

        monkeypatch.setattr("lib.mathpix_client._debounced_reasoning", fake_debounced)

        try:
            schedule_reasoning("sid", 1)
            assert key not in _pending_delayed
            assert delayed_task.cancelling() > 0
        finally:
            _pending_delayed.pop(key, None)
            task = _reasoning_tasks.pop(key, None)
            if task:
                task.cancel()
            delayed_task.cancel()


class TestDebouncedReasoningDelayedSpeak:
    async def test_delayed_speak_starts_timer(self, monkeypatch):
        """When model returns delayed_speak, a timer task should be stored in _pending_delayed."""
        monkeypatch.setattr("lib.mathpix_client.REASONING_DEBOUNCE_SECONDS", 0)
        monkeypatch.setattr("lib.mathpix_client.DELAYED_SPEAK_SECONDS", 100)  # long so it doesn't fire

        async def fake_run_reasoning(sid, page):
            return {"action": "delayed_speak", "message": "Are you still thinking?"}

        monkeypatch.setattr("lib.reasoning.run_reasoning", fake_run_reasoning)

        pushed = []

        async def fake_push(sid, action, message):
            pushed.append((sid, action, message))

        monkeypatch.setattr("api.reasoning.push_reasoning", fake_push)

        key = ("sid", 1)
        _pending_delayed.pop(key, None)

        try:
            from lib.mathpix_client import _debounced_reasoning
            await _debounced_reasoning("sid", 1)

            # Should NOT have pushed immediately
            assert len(pushed) == 0
            # Should have a pending task
            assert key in _pending_delayed
            assert not _pending_delayed[key].done()
        finally:
            task = _pending_delayed.pop(key, None)
            if task:
                task.cancel()

    async def test_delayed_speak_fires_after_delay(self, monkeypatch):
        """After DELAYED_SPEAK_SECONDS, the message should be pushed as 'speak'."""
        monkeypatch.setattr("lib.mathpix_client.REASONING_DEBOUNCE_SECONDS", 0)
        monkeypatch.setattr("lib.mathpix_client.DELAYED_SPEAK_SECONDS", 0.1)  # 100ms for test speed

        async def fake_run_reasoning(sid, page):
            return {"action": "delayed_speak", "message": "Still working on that?"}

        monkeypatch.setattr("lib.reasoning.run_reasoning", fake_run_reasoning)

        pushed = []

        async def fake_push(sid, action, message):
            pushed.append((sid, action, message))

        monkeypatch.setattr("api.reasoning.push_reasoning", fake_push)

        key = ("sid", 1)
        _pending_delayed.pop(key, None)

        try:
            from lib.mathpix_client import _debounced_reasoning
            await _debounced_reasoning("sid", 1)

            # Not pushed yet
            assert len(pushed) == 0

            # Wait for delay to fire
            await asyncio.sleep(0.2)

            assert len(pushed) == 1
            assert pushed[0] == ("sid", "speak", "Still working on that?")
            assert key not in _pending_delayed
        finally:
            task = _pending_delayed.pop(key, None)
            if task:
                task.cancel()

    async def test_speak_still_pushes_immediately(self, monkeypatch):
        """Regular speak action should still push immediately (no delay)."""
        monkeypatch.setattr("lib.mathpix_client.REASONING_DEBOUNCE_SECONDS", 0)

        async def fake_run_reasoning(sid, page):
            return {"action": "speak", "message": "Check that sign."}

        monkeypatch.setattr("lib.reasoning.run_reasoning", fake_run_reasoning)

        pushed = []

        async def fake_push(sid, action, message):
            pushed.append((sid, action, message))

        monkeypatch.setattr("api.reasoning.push_reasoning", fake_push)

        key = ("sid", 1)
        try:
            from lib.mathpix_client import _debounced_reasoning
            await _debounced_reasoning("sid", 1)

            assert len(pushed) == 1
            assert pushed[0] == ("sid", "speak", "Check that sign.")
            assert key not in _pending_delayed
        finally:
            task = _pending_delayed.pop(key, None)
            if task:
                task.cancel()
