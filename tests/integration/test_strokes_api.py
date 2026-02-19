"""Integration tests for api/strokes.py — connect/disconnect + session management."""

import pytest
from httpx import ASGITransport, AsyncClient

from api.strokes import _active_sessions


@pytest.fixture(autouse=True)
def clear_active_sessions():
    """Clear _active_sessions before and after each test."""
    _active_sessions.clear()
    yield
    _active_sessions.clear()


@pytest.fixture
def patch_pool(mocker, mock_pool):
    """Patch get_pool in strokes module to return mock_pool."""
    mocker.patch("api.strokes.get_pool", return_value=mock_pool)
    return mock_pool


@pytest.fixture
def patch_pool_none(mocker):
    """Patch get_pool to return None (no DB)."""
    mocker.patch("api.strokes.get_pool", return_value=None)


@pytest.fixture
async def client():
    from api.index import app
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


class TestConnect:
    async def test_connect_without_db(self, client, patch_pool_none):
        resp = await client.post("/api/strokes/connect", json={
            "session_id": "s1",
        })
        assert resp.status_code == 200
        assert "s1" in _active_sessions

    async def test_connect_with_metadata(self, client, patch_pool):
        resp = await client.post("/api/strokes/connect", json={
            "session_id": "s1",
            "document_name": "homework.pdf",
            "question_number": 3,
        })
        assert resp.status_code == 200
        info = _active_sessions["s1"]
        assert info["document_name"] == "homework.pdf"
        assert info["question_number"] == 3

    async def test_second_connect_evicts_first(self, client, patch_pool):
        await client.post("/api/strokes/connect", json={"session_id": "s1"})
        assert "s1" in _active_sessions

        await client.post("/api/strokes/connect", json={"session_id": "s2"})
        assert "s2" in _active_sessions
        assert "s1" not in _active_sessions


class TestDisconnect:
    async def test_disconnect_removes_session(self, client, mocker):
        mocker.patch("api.strokes.cleanup_sessions")
        _active_sessions["s1"] = {"document_name": "", "question_number": None, "last_seen": ""}

        resp = await client.post("/api/strokes/disconnect", json={"session_id": "s1"})
        assert resp.status_code == 200
        assert "s1" not in _active_sessions

    async def test_disconnect_nonexistent(self, client, mocker):
        mocker.patch("api.strokes.cleanup_sessions")
        resp = await client.post("/api/strokes/disconnect", json={"session_id": "nope"})
        assert resp.status_code == 200


class TestStrokeLogs:
    async def test_get_stroke_logs_no_db(self, client, patch_pool_none):
        resp = await client.get("/api/stroke-logs")
        assert resp.status_code == 503
