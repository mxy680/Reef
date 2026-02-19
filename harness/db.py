"""Asyncpg helpers for the harness — insert test data, upsert transcriptions, cleanup."""

import asyncpg

from harness.config import get_database_url


async def create_pool() -> asyncpg.Pool:
    return await asyncpg.create_pool(get_database_url(), min_size=1, max_size=3)


async def insert_document(pool: asyncpg.Pool, filename: str) -> int:
    """Insert a test document and return its id."""
    async with pool.acquire() as conn:
        return await conn.fetchval(
            """
            INSERT INTO documents (filename, page_count, total_problems)
            VALUES ($1, 1, 1) RETURNING id
            """,
            filename,
        )


async def insert_question(
    pool: asyncpg.Pool,
    document_id: int,
    number: int,
    label: str,
    text: str,
    parts: str = "[]",
) -> int:
    """Insert a test question and return its id."""
    async with pool.acquire() as conn:
        return await conn.fetchval(
            """
            INSERT INTO questions (document_id, number, label, text, parts)
            VALUES ($1, $2, $3, $4, $5::jsonb) RETURNING id
            """,
            document_id,
            number,
            label,
            text,
            parts,
        )


async def insert_answer_key(
    pool: asyncpg.Pool,
    question_id: int,
    part_label: str | None,
    answer: str,
) -> None:
    """Insert an answer key entry."""
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO answer_keys (question_id, part_label, answer)
            VALUES ($1, $2, $3)
            """,
            question_id,
            part_label,
            answer,
        )


async def upsert_transcription(
    pool: asyncpg.Pool,
    session_id: str,
    page: int,
    text: str,
) -> None:
    """Insert or update a page transcription."""
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO page_transcriptions (session_id, page, latex, text, confidence, updated_at)
            VALUES ($1, $2, $3, $4, 1.0, NOW())
            ON CONFLICT (session_id, page) DO UPDATE SET
                latex = EXCLUDED.latex,
                text = EXCLUDED.text,
                confidence = EXCLUDED.confidence,
                updated_at = NOW()
            """,
            session_id,
            page,
            text,
            text,
        )


async def get_reasoning_logs(
    pool: asyncpg.Pool,
    session_id: str,
    page: int = 1,
) -> list[dict]:
    """Fetch reasoning logs for a session, ordered by created_at."""
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT action, message, created_at FROM reasoning_logs
            WHERE session_id = $1 AND page = $2
            ORDER BY created_at
            """,
            session_id,
            page,
        )
    return [dict(r) for r in rows]


async def cleanup_session(pool: asyncpg.Pool, session_id: str) -> None:
    """Delete all test data for a session."""
    async with pool.acquire() as conn:
        await conn.execute(
            "DELETE FROM stroke_logs WHERE session_id = $1", session_id
        )
        await conn.execute(
            "DELETE FROM page_transcriptions WHERE session_id = $1", session_id
        )
        await conn.execute(
            "DELETE FROM reasoning_logs WHERE session_id = $1", session_id
        )
        await conn.execute(
            "DELETE FROM session_question_cache WHERE session_id = $1", session_id
        )


async def cleanup_document(pool: asyncpg.Pool, document_id: int) -> None:
    """Delete a test document (cascades to questions + answer_keys)."""
    async with pool.acquire() as conn:
        await conn.execute("DELETE FROM documents WHERE id = $1", document_id)
