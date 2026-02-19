"""Integration tests for api/users.py — profile CRUD with mock pool."""

import pytest
from httpx import ASGITransport, AsyncClient


@pytest.fixture
def patch_pool(mocker, mock_pool):
    """Patch get_pool in users module to return mock_pool."""
    mocker.patch("api.users.get_pool", return_value=mock_pool)
    return mock_pool


@pytest.fixture
def patch_pool_none(mocker):
    """Patch get_pool to return None."""
    mocker.patch("api.users.get_pool", return_value=None)


@pytest.fixture
async def client():
    from api.index import app
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


class TestUpsertProfile:
    async def test_put_valid_bearer(self, client, patch_pool, mock_conn):
        mock_conn.fetchrow.return_value = {
            "apple_user_id": "user123",
            "display_name": "Test",
            "email": "test@example.com",
        }
        resp = await client.put(
            "/users/profile",
            json={"display_name": "Test", "email": "test@example.com"},
            headers={"Authorization": "Bearer user123"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["apple_user_id"] == "user123"

    async def test_put_without_authorization(self, client, patch_pool):
        resp = await client.put(
            "/users/profile",
            json={"display_name": "Test"},
        )
        assert resp.status_code == 422

    async def test_put_invalid_auth_prefix(self, client, patch_pool):
        resp = await client.put(
            "/users/profile",
            json={"display_name": "Test"},
            headers={"Authorization": "Token xyz"},
        )
        assert resp.status_code == 401


class TestGetProfile:
    async def test_get_found(self, client, patch_pool, mock_conn):
        mock_conn.fetchrow.return_value = {
            "apple_user_id": "user123",
            "display_name": "Test",
            "email": None,
        }
        resp = await client.get(
            "/users/profile",
            headers={"Authorization": "Bearer user123"},
        )
        assert resp.status_code == 200
        assert resp.json()["apple_user_id"] == "user123"

    async def test_get_not_found(self, client, patch_pool, mock_conn):
        mock_conn.fetchrow.return_value = None
        resp = await client.get(
            "/users/profile",
            headers={"Authorization": "Bearer user123"},
        )
        assert resp.status_code == 404


class TestDeleteProfile:
    async def test_delete_success(self, client, patch_pool, mock_conn):
        mock_conn.execute.return_value = "DELETE 1"
        resp = await client.delete(
            "/users/profile",
            headers={"Authorization": "Bearer user123"},
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "deleted"

    async def test_delete_not_found(self, client, patch_pool, mock_conn):
        mock_conn.execute.return_value = "DELETE 0"
        resp = await client.delete(
            "/users/profile",
            headers={"Authorization": "Bearer user123"},
        )
        assert resp.status_code == 404


class TestNoDatabase:
    async def test_put_no_db(self, client, patch_pool_none):
        resp = await client.put(
            "/users/profile",
            json={"display_name": "Test"},
            headers={"Authorization": "Bearer user123"},
        )
        assert resp.status_code == 503

    async def test_get_no_db(self, client, patch_pool_none):
        resp = await client.get(
            "/users/profile",
            headers={"Authorization": "Bearer user123"},
        )
        assert resp.status_code == 503

    async def test_delete_no_db(self, client, patch_pool_none):
        resp = await client.delete(
            "/users/profile",
            headers={"Authorization": "Bearer user123"},
        )
        assert resp.status_code == 503
