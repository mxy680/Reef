"""Semantic chunked transcription manager.

Splits handwriting strokes into semantic chunks, caches transcription results
per chunk fingerprint, and merges/seals chunks based on LaTeX completeness.

This avoids re-transcribing unchanged strokes on every evaluation call.
"""

import asyncio
import hashlib
import json
import logging
from collections.abc import Awaitable, Callable
from dataclasses import asdict, dataclass

from app.services.latex_completeness import is_semantically_complete

log = logging.getLogger(__name__)

INITIAL_CHUNK_SIZE = 20
MAX_CHUNK_SIZE = 60


@dataclass
class ChunkMeta:
    start_index: int
    end_index: int
    fingerprint: str
    latex: str
    sealed: bool

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> "ChunkMeta":
        return cls(
            start_index=d["start_index"],
            end_index=d["end_index"],
            fingerprint=d["fingerprint"],
            latex=d.get("latex", ""),
            sealed=d.get("sealed", False),
        )


def _fingerprint_strokes(strokes: list[dict]) -> str:
    """Produce a 16-char MD5 hex fingerprint for a list of stroke dicts."""
    canonical = json.dumps(
        [
            {
                "x": [round(v, 2) for v in s["x"]],
                "y": [round(v, 2) for v in s["y"]],
            }
            for s in strokes
        ],
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.md5(canonical.encode()).hexdigest()[:16]


async def transcribe_with_chunks(
    all_strokes: list[dict],
    user_id: str,
    document_id: str,
    question_label: str,
    persisted_chunks: list[dict] | None,
    transcribe_fn: Callable[[list[dict]], Awaitable[str]],
) -> tuple[str, list[dict]]:
    """Transcribe strokes using semantic chunking with caching.

    Args:
        all_strokes: Complete list of strokes for the question.
        user_id: User identifier (for logging).
        document_id: Document identifier (for logging).
        question_label: Question label (for logging).
        persisted_chunks: Previously saved chunk metadata from the database.
        transcribe_fn: Async callable that takes a list of strokes and returns LaTeX.

    Returns:
        A tuple of (combined_latex, updated_chunks_as_dicts).
    """
    if not all_strokes:
        return ("", [])

    total = len(all_strokes)

    # --- Reconstruct chunks from persisted data ---
    chunks: list[ChunkMeta] = []
    if persisted_chunks:
        for d in persisted_chunks:
            chunk = ChunkMeta.from_dict(d)
            # Discard chunks whose boundaries exceed available strokes
            if chunk.start_index >= total:
                break
            # Truncate end_index if it exceeds total
            if chunk.end_index > total:
                chunk = ChunkMeta(
                    start_index=chunk.start_index,
                    end_index=total,
                    fingerprint=chunk.fingerprint,
                    latex=chunk.latex,
                    sealed=False,  # boundary changed, unseal
                )
            chunks.append(chunk)

    # --- Validate sealed chunks (fingerprint check) ---
    for i, chunk in enumerate(chunks):
        if not chunk.sealed:
            continue
        stroke_slice = all_strokes[chunk.start_index : chunk.end_index]
        current_fp = _fingerprint_strokes(stroke_slice)
        if current_fp == chunk.fingerprint:
            # Unchanged — keep cached latex
            continue
        # Strokes changed — re-transcribe
        log.debug(
            f"[chunks] {question_label} chunk[{i}] fingerprint changed, re-transcribing"
        )
        new_latex = await transcribe_fn(stroke_slice)
        complete = is_semantically_complete(new_latex)
        chunks[i] = ChunkMeta(
            start_index=chunk.start_index,
            end_index=chunk.end_index,
            fingerprint=current_fp,
            latex=new_latex,
            sealed=complete,
        )

    # --- Cover new strokes beyond last chunk ---
    last_covered = chunks[-1].end_index if chunks else 0

    i = last_covered
    while i < total:
        chunk_end = min(i + INITIAL_CHUNK_SIZE, total)
        stroke_slice = all_strokes[i:chunk_end]
        fp = _fingerprint_strokes(stroke_slice)
        size = chunk_end - i

        # The last chunk with fewer than INITIAL_CHUNK_SIZE strokes stays unsealed (active)
        is_last_partial = chunk_end == total and size < INITIAL_CHUNK_SIZE

        new_latex = await transcribe_fn(stroke_slice)
        complete = (not is_last_partial) and (is_semantically_complete(new_latex) or size >= MAX_CHUNK_SIZE)
        chunks.append(
            ChunkMeta(
                start_index=i,
                end_index=chunk_end,
                fingerprint=fp,
                latex=new_latex,
                sealed=complete,
            )
        )
        i = chunk_end

    # --- Merge adjacent unsealed chunks ---
    # Run after all chunks (persisted + new) are present so new incomplete
    # chunks are merged with any preceding unsealed persisted chunks.
    merged_any = True
    while merged_any:
        merged_any = False
        new_chunks: list[ChunkMeta] = []
        i = 0
        while i < len(chunks):
            if i + 1 < len(chunks) and not chunks[i].sealed and not chunks[i + 1].sealed:
                # Merge the two unsealed chunks
                merged_start = chunks[i].start_index
                merged_end = chunks[i + 1].end_index
                stroke_slice = all_strokes[merged_start:merged_end]
                size = merged_end - merged_start
                fp = _fingerprint_strokes(stroke_slice)
                new_latex = await transcribe_fn(stroke_slice)
                # Is this the partial last chunk?
                is_last_partial = merged_end == total and size < MAX_CHUNK_SIZE and size < INITIAL_CHUNK_SIZE * 2
                complete = (not is_last_partial) and (is_semantically_complete(new_latex) or size >= MAX_CHUNK_SIZE)
                new_chunks.append(
                    ChunkMeta(
                        start_index=merged_start,
                        end_index=merged_end,
                        fingerprint=fp,
                        latex=new_latex,
                        sealed=complete,
                    )
                )
                i += 2
                merged_any = True
            else:
                new_chunks.append(chunks[i])
                i += 1
        chunks = new_chunks

    # --- Force-seal any chunk that reaches MAX_CHUNK_SIZE ---
    for i, chunk in enumerate(chunks):
        if (chunk.end_index - chunk.start_index) >= MAX_CHUNK_SIZE and not chunk.sealed:
            chunks[i] = ChunkMeta(
                start_index=chunk.start_index,
                end_index=chunk.end_index,
                fingerprint=chunk.fingerprint,
                latex=chunk.latex,
                sealed=True,
            )

    # --- Summary logging ---
    sealed_count = sum(1 for c in chunks if c.sealed)
    dirty_count = sum(
        1 for c in chunks
        if not c.sealed and c.start_index < last_covered
    )
    new_count = sum(
        1 for c in chunks
        if c.start_index >= last_covered
    )
    log.info(
        f"[chunks] {question_label}: {sealed_count} sealed, {dirty_count} dirty, {new_count} new"
    )

    final_latex = " ".join(c.latex for c in chunks if c.latex.strip())
    return (final_latex, [c.to_dict() for c in chunks])


def clear_cache_for_question(user_id: str, document_id: str, question_label: str) -> None:
    """No-op placeholder — chunking state lives in the database, not in-process memory.

    This function exists as a hook for future in-process caching layers.
    """
    log.debug(f"[chunks] cache clear requested for {question_label} (user={user_id}, doc={document_id})")
