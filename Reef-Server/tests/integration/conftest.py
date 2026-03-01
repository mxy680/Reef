"""
Integration test fixtures — real PostgreSQL database lifecycle.

Requires a local PostgreSQL server on localhost:5432 with CREATE DATABASE permission.
"""

import asyncio
import os

import asyncpg
import pytest
from fastapi.testclient import TestClient


@pytest.fixture(scope="session", autouse=True)
def test_database():
    """Create reef_test database before the session, drop it after."""

    async def _setup():
        conn = await asyncpg.connect(
            host="localhost", port=5432, user=os.getenv("PGUSER", os.getenv("USER")),
            database="postgres",
        )
        # Drop if leftover from a crashed run
        await conn.execute("DROP DATABASE IF EXISTS reef_test")
        await conn.execute("CREATE DATABASE reef_test")
        await conn.close()

    async def _teardown():
        conn = await asyncpg.connect(
            host="localhost", port=5432, user=os.getenv("PGUSER", os.getenv("USER")),
            database="postgres",
        )
        await conn.execute("DROP DATABASE IF EXISTS reef_test")
        await conn.close()

    asyncio.run(_setup())
    os.environ["DATABASE_URL"] = "postgresql://localhost:5432/reef_test"

    yield

    os.environ.pop("DATABASE_URL", None)
    asyncio.run(_teardown())


@pytest.fixture(scope="module")
def client():
    """TestClient that triggers app lifespan (init_db / close_db)."""
    from api.index import app

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture
async def db(client):
    """Direct asyncpg connection for SQL data setup in tests."""
    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    yield conn
    await conn.close()
