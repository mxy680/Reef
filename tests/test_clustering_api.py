"""API-level tests for the clustering endpoint with mocked database."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock
from fastapi.testclient import TestClient
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from api.index import app


@pytest.fixture
def client():
    return TestClient(app)


def _make_stroke(x: float, y: float) -> dict:
    return {"points": [{"x": x, "y": y}]}


def _make_pool_mock(rows):
    """Build a mock asyncpg pool that returns `rows` on fetch and no-ops on writes."""
    conn = AsyncMock()
    conn.fetch = AsyncMock(return_value=rows)
    conn.execute = AsyncMock()
    conn.executemany = AsyncMock()

    # Support `async with conn.transaction():`
    tx = AsyncMock()
    tx.__aenter__ = AsyncMock(return_value=tx)
    tx.__aexit__ = AsyncMock(return_value=False)
    conn.transaction = MagicMock(return_value=tx)

    # Support `async with pool.acquire() as conn:`
    ctx = AsyncMock()
    ctx.__aenter__ = AsyncMock(return_value=conn)
    ctx.__aexit__ = AsyncMock(return_value=False)

    pool = MagicMock()
    pool.acquire = MagicMock(return_value=ctx)

    return pool, conn


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

class TestClusterStrokesValidation:

    def test_missing_session_id(self, client):
        response = client.post("/api/cluster-strokes", json={"page": 1})
        assert response.status_code == 422

    def test_missing_page(self, client):
        response = client.post("/api/cluster-strokes", json={"session_id": "abc"})
        assert response.status_code == 422

    def test_invalid_eps(self, client):
        response = client.post("/api/cluster-strokes", json={
            "session_id": "abc", "page": 1, "eps": -1
        })
        assert response.status_code == 422

    def test_invalid_min_samples(self, client):
        response = client.post("/api/cluster-strokes", json={
            "session_id": "abc", "page": 1, "min_samples": 0
        })
        assert response.status_code == 422


# ---------------------------------------------------------------------------
# No data
# ---------------------------------------------------------------------------

class TestClusterStrokesNoData:

    @patch("lib.stroke_clustering.get_pool")
    def test_no_strokes_returns_empty(self, mock_get_pool, client):
        pool, _ = _make_pool_mock(rows=[])
        mock_get_pool.return_value = pool

        response = client.post("/api/cluster-strokes", json={
            "session_id": "test-session", "page": 1,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["num_strokes"] == 0
        assert data["num_clusters"] == 0
        assert data["noise_strokes"] == 0
        assert data["clusters"] == []

    @patch("lib.stroke_clustering.get_pool")
    def test_db_not_configured(self, mock_get_pool, client):
        mock_get_pool.return_value = None

        response = client.post("/api/cluster-strokes", json={
            "session_id": "abc", "page": 1,
        })
        assert response.status_code == 503


# ---------------------------------------------------------------------------
# With data
# ---------------------------------------------------------------------------

class TestClusterStrokesWithData:

    @patch("lib.stroke_clustering.get_pool")
    def test_two_clusters(self, mock_get_pool, client):
        rows = [
            {"id": 1, "strokes": [
                _make_stroke(100, 100), _make_stroke(110, 105),
                _make_stroke(1000, 1000), _make_stroke(1010, 1005),
            ]},
        ]
        pool, conn = _make_pool_mock(rows)
        mock_get_pool.return_value = pool

        response = client.post("/api/cluster-strokes", json={
            "session_id": "test-session", "page": 1,
        })
        assert response.status_code == 200
        data = response.json()
        assert data["session_id"] == "test-session"
        assert data["page"] == 1
        assert data["num_strokes"] == 4
        assert data["num_clusters"] == 2
        assert data["noise_strokes"] == 0
        assert len(data["clusters"]) == 2

    @patch("lib.stroke_clustering.get_pool")
    def test_response_shape(self, mock_get_pool, client):
        rows = [
            {"id": 1, "strokes": [_make_stroke(100, 100), _make_stroke(110, 105)]},
        ]
        pool, _ = _make_pool_mock(rows)
        mock_get_pool.return_value = pool

        response = client.post("/api/cluster-strokes", json={
            "session_id": "s1", "page": 2,
        })
        data = response.json()

        # Check top-level keys
        assert set(data.keys()) == {
            "session_id", "page", "num_strokes", "num_clusters",
            "noise_strokes", "clusters",
        }

        # Check cluster shape
        cluster = data["clusters"][0]
        assert set(cluster.keys()) == {
            "cluster_label", "stroke_count", "centroid", "bounding_box",
        }
        assert isinstance(cluster["centroid"], list)
        assert len(cluster["centroid"]) == 2
        assert isinstance(cluster["bounding_box"], list)
        assert len(cluster["bounding_box"]) == 4

    @patch("lib.stroke_clustering.get_pool")
    def test_custom_eps(self, mock_get_pool, client):
        """A very small eps should make nearby points become noise."""
        rows = [
            {"id": 1, "strokes": [_make_stroke(0, 0), _make_stroke(200, 200)]},
        ]
        pool, _ = _make_pool_mock(rows)
        mock_get_pool.return_value = pool

        response = client.post("/api/cluster-strokes", json={
            "session_id": "s1", "page": 1, "eps": 10.0,
        })
        data = response.json()
        assert data["num_clusters"] == 0
        assert data["noise_strokes"] == 2

    @patch("lib.stroke_clustering.get_pool")
    def test_defaults_applied(self, mock_get_pool, client):
        """Omitting eps/min_samples should use defaults (150.0, 2)."""
        rows = [
            {"id": 1, "strokes": [_make_stroke(100, 100), _make_stroke(110, 100)]},
        ]
        pool, _ = _make_pool_mock(rows)
        mock_get_pool.return_value = pool

        response = client.post("/api/cluster-strokes", json={
            "session_id": "s1", "page": 1,
        })
        data = response.json()
        # Distance ~10 < default eps 150, min_samples=2 → 1 cluster
        assert data["num_clusters"] == 1

    @patch("lib.stroke_clustering.get_pool")
    def test_db_writes_called(self, mock_get_pool, client):
        """Verify that cluster data is written to the database."""
        rows = [
            {"id": 1, "strokes": [_make_stroke(100, 100), _make_stroke(110, 100)]},
        ]
        pool, conn = _make_pool_mock(rows)
        mock_get_pool.return_value = pool

        client.post("/api/cluster-strokes", json={
            "session_id": "s1", "page": 1,
        })

        # Should have called: 2 DELETEs + 1 executemany (cluster_classes) + 1 execute (clusters)
        assert conn.execute.call_count >= 3
        assert conn.executemany.call_count == 1
