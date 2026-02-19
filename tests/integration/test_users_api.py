"""Integration tests for api/users.py — real DB CRUD via TestClient."""

import uuid


def _uid() -> str:
    """Generate a unique Apple user ID for test isolation."""
    return f"test_{uuid.uuid4().hex[:12]}"


class TestPutThenGet:
    def test_put_creates_and_get_retrieves(self, client):
        uid = _uid()
        resp = client.put(
            "/users/profile",
            json={"display_name": "Alice", "email": "alice@example.com"},
            headers={"Authorization": f"Bearer {uid}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["apple_user_id"] == uid
        assert data["display_name"] == "Alice"
        assert data["email"] == "alice@example.com"

        # GET returns same profile
        resp = client.get("/users/profile", headers={"Authorization": f"Bearer {uid}"})
        assert resp.status_code == 200
        assert resp.json()["display_name"] == "Alice"


class TestUpsertCoalesce:
    def test_put_twice_preserves_non_null_fields(self, client):
        uid = _uid()
        # First PUT sets both fields
        client.put(
            "/users/profile",
            json={"display_name": "Bob", "email": "bob@example.com"},
            headers={"Authorization": f"Bearer {uid}"},
        )
        # Second PUT with null email — should keep existing email
        resp = client.put(
            "/users/profile",
            json={"display_name": "Bobby"},
            headers={"Authorization": f"Bearer {uid}"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["display_name"] == "Bobby"
        assert data["email"] == "bob@example.com"


class TestDeleteThenGet:
    def test_delete_removes_profile(self, client):
        uid = _uid()
        client.put(
            "/users/profile",
            json={"display_name": "Charlie"},
            headers={"Authorization": f"Bearer {uid}"},
        )
        resp = client.delete("/users/profile", headers={"Authorization": f"Bearer {uid}"})
        assert resp.status_code == 200
        assert resp.json()["status"] == "deleted"

        # GET after delete → 404
        resp = client.get("/users/profile", headers={"Authorization": f"Bearer {uid}"})
        assert resp.status_code == 404


class TestGetNonexistent:
    def test_get_unknown_user_returns_404(self, client):
        uid = _uid()
        resp = client.get("/users/profile", headers={"Authorization": f"Bearer {uid}"})
        assert resp.status_code == 404


class TestDeleteNonexistent:
    def test_delete_unknown_user_returns_404(self, client):
        uid = _uid()
        resp = client.delete("/users/profile", headers={"Authorization": f"Bearer {uid}"})
        assert resp.status_code == 404


class TestInvalidAuth:
    def test_bad_prefix_returns_401(self, client):
        resp = client.put(
            "/users/profile",
            json={"display_name": "Test"},
            headers={"Authorization": "Token xyz"},
        )
        assert resp.status_code == 401
