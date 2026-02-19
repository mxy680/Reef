"""Tests for lib/reasoning.py -> _flush_sentences()."""

import asyncio

from lib.reasoning import _flush_sentences


def _drain_queue(q: asyncio.Queue) -> list[str]:
    """Pull all items from queue without blocking."""
    items = []
    while not q.empty():
        items.append(q.get_nowait())
    return items


class TestFlushSentences:
    def test_one_complete_sentence(self):
        q = asyncio.Queue()
        remainder = _flush_sentences("Nice work. more", q)
        assert _drain_queue(q) == ["Nice work."]
        assert remainder == "more"

    def test_two_complete_sentences(self):
        q = asyncio.Queue()
        remainder = _flush_sentences("First. Second! more text", q)
        items = _drain_queue(q)
        assert items == ["First.", "Second!"]
        assert remainder == "more text"

    def test_no_sentence_boundary(self):
        q = asyncio.Queue()
        remainder = _flush_sentences("no boundary here", q)
        assert _drain_queue(q) == []
        assert remainder == "no boundary here"

    def test_empty_string(self):
        q = asyncio.Queue()
        remainder = _flush_sentences("", q)
        assert _drain_queue(q) == []
        assert remainder == ""

    def test_trailing_space_not_flushed(self):
        # Regex requires \S lookahead — trailing "done. " should NOT flush
        q = asyncio.Queue()
        remainder = _flush_sentences("done. ", q)
        assert _drain_queue(q) == []
        assert remainder == "done. "

    def test_question_mark_boundary(self):
        q = asyncio.Queue()
        remainder = _flush_sentences("Really? Yes", q)
        assert _drain_queue(q) == ["Really?"]
        assert remainder == "Yes"
