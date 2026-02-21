"""Unit tests for reasoning helper functions: _get_part_order, _is_later_part."""

from lib.reasoning import _get_part_order, _is_later_part


class TestGetPartOrder:
    def test_flat_parts(self):
        parts = [
            {"label": "a", "text": "Find x"},
            {"label": "b", "text": "Find y"},
            {"label": "c", "text": "Find z"},
        ]
        assert _get_part_order(parts) == ["a", "b", "c"]

    def test_nested_parts(self):
        parts = [
            {"label": "a", "text": "Part a", "parts": [
                {"label": "i", "text": "Sub i"},
                {"label": "ii", "text": "Sub ii"},
            ]},
            {"label": "b", "text": "Part b"},
        ]
        assert _get_part_order(parts) == ["a", "a.i", "a.ii", "b"]

    def test_empty_parts(self):
        assert _get_part_order([]) == []

    def test_missing_label(self):
        parts = [{"text": "no label"}, {"label": "a", "text": "has label"}]
        assert _get_part_order(parts) == ["a"]

    def test_parts_without_subparts_key(self):
        parts = [{"label": "a", "text": "Part a"}, {"label": "b", "text": "Part b"}]
        assert _get_part_order(parts) == ["a", "b"]


class TestIsLaterPart:
    def test_later_part(self):
        order = ["a", "b", "c"]
        assert _is_later_part("c", "b", order) is True

    def test_earlier_part(self):
        order = ["a", "b", "c"]
        assert _is_later_part("a", "b", order) is False

    def test_same_part(self):
        order = ["a", "b", "c"]
        assert _is_later_part("b", "b", order) is False

    def test_label_not_in_order(self):
        order = ["a", "b"]
        assert _is_later_part("c", "b", order) is False

    def test_active_not_in_order(self):
        order = ["a", "b"]
        assert _is_later_part("a", "c", order) is False

    def test_nested_ordering(self):
        order = ["a", "a.i", "a.ii", "b"]
        assert _is_later_part("b", "a.i", order) is True
        assert _is_later_part("a", "a.ii", order) is False


from collections import deque
from lib.mathpix_client import _erase_snapshots


class TestEraseContextInBuildContext:
    def test_erase_snapshots_included_in_context(self, monkeypatch):
        """build_context should include Previously Erased Work section."""
        import asyncio

        class ContextConn:
            async def fetchrow(self, query, *args):
                if "page_transcriptions" in query:
                    return {"latex": "x=1", "text": "x=1"}
                if "session_question_cache" in query:
                    return None
                return None
            async def fetch(self, query, *args):
                return []
            async def fetchval(self, query, *args):
                return 0

        class ContextPool:
            def acquire(self):
                from tests.helpers import _FakeAcquireCtx
                return _FakeAcquireCtx(ContextConn())

        monkeypatch.setattr("lib.reasoning.get_pool", lambda: ContextPool())
        monkeypatch.setattr("api.strokes._active_sessions", {"sid": {}})

        key = ("sid", 1)
        _erase_snapshots[key] = deque(["x^2 + 3x = 0", "x^2 = -3x"], maxlen=3)

        try:
            from lib.reasoning import build_context
            ctx = asyncio.run(build_context("sid", 1))
            assert "Previously Erased Work" in ctx.text
            assert "x^2 + 3x = 0" in ctx.text
            assert "x^2 = -3x" in ctx.text
            # Most recent should come first (reversed order)
            assert ctx.text.index("x^2 = -3x") < ctx.text.index("x^2 + 3x = 0")
        finally:
            _erase_snapshots.pop(key, None)

    def test_no_section_when_no_erases(self, monkeypatch):
        """build_context should NOT include erase section when no snapshots."""
        import asyncio

        class ContextConn:
            async def fetchrow(self, query, *args):
                if "page_transcriptions" in query:
                    return {"latex": "x=1", "text": "x=1"}
                return None
            async def fetch(self, query, *args):
                return []
            async def fetchval(self, query, *args):
                return 0

        class ContextPool:
            def acquire(self):
                from tests.helpers import _FakeAcquireCtx
                return _FakeAcquireCtx(ContextConn())

        monkeypatch.setattr("lib.reasoning.get_pool", lambda: ContextPool())
        monkeypatch.setattr("api.strokes._active_sessions", {"sid": {}})

        key = ("sid", 1)
        _erase_snapshots.pop(key, None)

        from lib.reasoning import build_context
        ctx = asyncio.run(build_context("sid", 1))
        assert "Previously Erased Work" not in ctx.text
