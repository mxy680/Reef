"""PostgreSQL connection pool for document storage."""

import os

import asyncpg

_pool: asyncpg.Pool | None = None


async def init_db():
    """Create asyncpg connection pool and ensure tables exist."""
    global _pool

    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        print("[DB] DATABASE_URL not set — skipping database init")
        return

    _pool = await asyncpg.create_pool(database_url, min_size=1, max_size=5)
    async with _pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS documents (
                id SERIAL PRIMARY KEY,
                filename TEXT NOT NULL,
                page_count INT NOT NULL DEFAULT 0,
                total_problems INT NOT NULL DEFAULT 0,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS questions (
                id SERIAL PRIMARY KEY,
                document_id INT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
                number INT NOT NULL,
                label TEXT NOT NULL DEFAULT '',
                text TEXT NOT NULL DEFAULT '',
                parts JSONB NOT NULL DEFAULT '[]'::jsonb,
                figures JSONB NOT NULL DEFAULT '[]'::jsonb,
                annotation_indices JSONB NOT NULL DEFAULT '[]'::jsonb,
                bboxes JSONB NOT NULL DEFAULT '[]'::jsonb,
                answer_space_cm FLOAT NOT NULL DEFAULT 3.0,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_questions_document
            ON questions(document_id)
        """)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS answer_keys (
                id SERIAL PRIMARY KEY,
                question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
                part_label TEXT,
                answer TEXT NOT NULL DEFAULT '',
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_answer_keys_question
            ON answer_keys(question_id)
        """)
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS question_figures (
                id SERIAL PRIMARY KEY,
                question_id INT NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
                filename TEXT NOT NULL,
                image_b64 TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW()
            )
        """)
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_question_figures_question
            ON question_figures(question_id)
        """)
    print("[DB] Connected and tables ready")


async def close_db():
    """Close the connection pool on shutdown."""
    global _pool
    if _pool:
        await _pool.close()
        _pool = None
        print("[DB] Connection pool closed")


def get_pool() -> asyncpg.Pool | None:
    """Return the pool singleton (None if DB not configured)."""
    return _pool
