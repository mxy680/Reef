"""
Pytest configuration and fixtures.
"""

import os
from unittest.mock import AsyncMock, MagicMock

import pytest

# Set test environment
os.environ["ENVIRONMENT"] = "development"


@pytest.fixture
def mock_conn():
    """AsyncMock asyncpg connection with sensible defaults."""
    conn = AsyncMock()
    conn.execute = AsyncMock(return_value="UPDATE 1")
    conn.fetchrow = AsyncMock(return_value=None)
    conn.fetch = AsyncMock(return_value=[])
    conn.fetchval = AsyncMock(return_value=0)
    return conn


@pytest.fixture
def mock_pool(mock_conn):
    """MagicMock pool whose acquire() context manager yields mock_conn."""
    pool = MagicMock()
    ctx = AsyncMock()
    ctx.__aenter__ = AsyncMock(return_value=mock_conn)
    ctx.__aexit__ = AsyncMock(return_value=False)
    pool.acquire.return_value = ctx
    return pool
