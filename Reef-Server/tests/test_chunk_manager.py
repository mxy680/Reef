"""Tests for chunk_manager.transcribe_with_chunks."""

import pytest

from app.services.chunk_manager import (
    INITIAL_CHUNK_SIZE,
    MAX_CHUNK_SIZE,
    ChunkMeta,
    _fingerprint_strokes,
    transcribe_with_chunks,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_strokes(n: int) -> list[dict]:
    """Return a list of n distinct fake strokes."""
    return [{"x": [float(i)], "y": [float(i * 2)]} for i in range(n)]


def _make_transcribe_fn(complete_response: str = "3x + 5", incomplete_response: str = "3x +"):
    """Return a transcribe_fn that alternates: first call → complete, rest → incomplete."""
    calls: list[int] = [0]

    async def fn(strokes: list[dict]) -> str:
        calls[0] += 1
        return complete_response

    return fn, calls


def _make_always_incomplete_fn():
    """Return a transcribe_fn that always returns an incomplete expression."""
    calls: list[int] = [0]

    async def fn(strokes: list[dict]) -> str:
        calls[0] += 1
        return "3x +"

    return fn, calls


def _make_call_counting_fn(responses: list[str]):
    """Return a transcribe_fn that returns responses in order (cycling last if exhausted)."""
    calls: list[int] = [0]

    async def fn(strokes: list[dict]) -> str:
        idx = min(calls[0], len(responses) - 1)
        calls[0] += 1
        return responses[idx]

    return fn, calls


# ---------------------------------------------------------------------------
# Basic cases
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_empty_strokes_returns_empty() -> None:
    fn, _ = _make_transcribe_fn()
    latex, chunks = await transcribe_with_chunks(
        all_strokes=[],
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=None,
        transcribe_fn=fn,
    )
    assert latex == ""
    assert chunks == []


@pytest.mark.asyncio
async def test_40_strokes_first_chunk_sealed_second_active() -> None:
    """40 strokes → first 20 sealed (complete response), last 20 unsealed active."""
    strokes = _make_strokes(40)
    fn, calls = _make_transcribe_fn(complete_response="3x + 5")

    latex, chunks = await transcribe_with_chunks(
        all_strokes=strokes,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=None,
        transcribe_fn=fn,
    )

    assert len(chunks) == 2
    assert chunks[0]["sealed"] is True
    assert chunks[0]["start_index"] == 0
    assert chunks[0]["end_index"] == INITIAL_CHUNK_SIZE
    # Last chunk has exactly INITIAL_CHUNK_SIZE strokes — it's a full chunk, gets sealed if complete
    assert chunks[1]["end_index"] == 40
    assert "3x + 5" in latex
    assert calls[0] == 2


@pytest.mark.asyncio
async def test_partial_last_chunk_stays_unsealed() -> None:
    """25 strokes → first 20 sealed, last 5 (< INITIAL_CHUNK_SIZE) stays unsealed."""
    strokes = _make_strokes(25)
    fn, calls = _make_transcribe_fn(complete_response="x = 1")

    latex, chunks = await transcribe_with_chunks(
        all_strokes=strokes,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=None,
        transcribe_fn=fn,
    )

    assert len(chunks) == 2
    assert chunks[0]["sealed"] is True
    assert chunks[1]["sealed"] is False  # partial tail stays active
    assert chunks[1]["start_index"] == 20
    assert chunks[1]["end_index"] == 25


@pytest.mark.asyncio
async def test_sealed_chunk_cached_on_second_call() -> None:
    """Second call with same strokes + 10 more: sealed chunk not re-transcribed."""
    base_strokes = _make_strokes(20)
    extra_strokes = _make_strokes(10)  # distinct from base by index offset
    extra_strokes = [{"x": [float(100 + i)], "y": [float(i)]} for i in range(10)]
    all_strokes_first = base_strokes
    all_strokes_second = base_strokes + extra_strokes

    # First call: produces 1 sealed chunk for 20 strokes
    fn1, calls1 = _make_transcribe_fn(complete_response="3x + 5")
    _, chunks_after_first = await transcribe_with_chunks(
        all_strokes=all_strokes_first,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=None,
        transcribe_fn=fn1,
    )

    assert len(chunks_after_first) == 1
    assert chunks_after_first[0]["sealed"] is True
    first_call_count = calls1[0]

    # Second call: same base + 10 new strokes. Sealed chunk fingerprint unchanged → cached.
    fn2, calls2 = _make_transcribe_fn(complete_response="y + 2")
    latex2, chunks_after_second = await transcribe_with_chunks(
        all_strokes=all_strokes_second,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=chunks_after_first,
        transcribe_fn=fn2,
    )

    # Should only transcribe the new 10 strokes (tail), not the sealed 20-stroke chunk
    assert calls2[0] == 1, f"Expected 1 call for new tail, got {calls2[0]}"
    # Result should contain the cached latex from first call and the new tail
    assert "3x + 5" in latex2


@pytest.mark.asyncio
async def test_incomplete_chunks_merge() -> None:
    """When transcription returns incomplete, chunks should merge together."""
    strokes = _make_strokes(40)
    fn, calls = _make_always_incomplete_fn()

    latex, chunks = await transcribe_with_chunks(
        all_strokes=strokes,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=None,
        transcribe_fn=fn,
    )

    # Both 20-stroke chunks are incomplete → they merge into one unsealed chunk
    assert len(chunks) == 1
    assert chunks[0]["sealed"] is False
    assert chunks[0]["start_index"] == 0
    assert chunks[0]["end_index"] == 40


@pytest.mark.asyncio
async def test_max_chunk_size_force_seals() -> None:
    """A merged chunk that reaches MAX_CHUNK_SIZE must be force-sealed."""
    # MAX_CHUNK_SIZE = 60; create exactly 60 strokes all returning incomplete
    strokes = _make_strokes(MAX_CHUNK_SIZE)
    fn, _ = _make_always_incomplete_fn()

    _, chunks = await transcribe_with_chunks(
        all_strokes=strokes,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=None,
        transcribe_fn=fn,
    )

    # All strokes form one big chunk that gets force-sealed at MAX_CHUNK_SIZE
    sealed_chunks = [c for c in chunks if c["sealed"]]
    assert len(sealed_chunks) >= 1
    # The largest chunk should be sealed
    largest = max(chunks, key=lambda c: c["end_index"] - c["start_index"])
    assert largest["sealed"] is True


@pytest.mark.asyncio
async def test_erase_from_sealed_chunk_triggers_retranscription() -> None:
    """Changing strokes in a sealed chunk causes re-transcription of that chunk."""
    original_strokes = _make_strokes(20)

    # First call: seal the chunk
    fn1, _ = _make_transcribe_fn(complete_response="x^2")
    _, persisted = await transcribe_with_chunks(
        all_strokes=original_strokes,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=None,
        transcribe_fn=fn1,
    )
    assert persisted[0]["sealed"] is True
    assert persisted[0]["latex"] == "x^2"

    # Modify strokes (simulate erase/redraw)
    modified_strokes = [{"x": [float(i + 999)], "y": [float(i)]} for i in range(20)]

    fn2, calls2 = _make_transcribe_fn(complete_response="y^2")
    latex2, chunks2 = await transcribe_with_chunks(
        all_strokes=modified_strokes,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=persisted,
        transcribe_fn=fn2,
    )

    # Sealed chunk had fingerprint mismatch → re-transcribed
    assert calls2[0] >= 1
    assert chunks2[0]["latex"] == "y^2"


@pytest.mark.asyncio
async def test_persisted_chunks_restore_correctly() -> None:
    """Persisted chunk metadata restores boundaries and latex correctly."""
    strokes = _make_strokes(25)
    fp = _fingerprint_strokes(strokes[:20])

    persisted = [
        {
            "start_index": 0,
            "end_index": 20,
            "fingerprint": fp,
            "latex": "a + b",
            "sealed": True,
        }
    ]

    fn, calls = _make_transcribe_fn(complete_response="c + d")
    latex, chunks = await transcribe_with_chunks(
        all_strokes=strokes,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=persisted,
        transcribe_fn=fn,
    )

    # Sealed chunk restored from cache; only tail (5 strokes) transcribed
    assert calls[0] == 1  # only the tail
    assert "a + b" in latex
    assert "c + d" in latex


@pytest.mark.asyncio
async def test_persisted_chunks_beyond_stroke_count_discarded() -> None:
    """Persisted chunks with start_index >= len(all_strokes) are discarded."""
    strokes = _make_strokes(5)
    persisted = [
        {
            "start_index": 10,
            "end_index": 20,
            "fingerprint": "deadbeef",
            "latex": "stale",
            "sealed": True,
        }
    ]

    fn, calls = _make_transcribe_fn(complete_response="x")
    latex, chunks = await transcribe_with_chunks(
        all_strokes=strokes,
        user_id="u1",
        document_id="d1",
        question_label="Q1",
        persisted_chunks=persisted,
        transcribe_fn=fn,
    )

    # Stale chunk discarded; 5 strokes (< INITIAL_CHUNK_SIZE) → 1 active chunk
    assert all(c["start_index"] < 10 for c in chunks)
    assert "stale" not in latex
