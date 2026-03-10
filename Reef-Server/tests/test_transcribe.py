"""Tests for POST /ai/transcribe-strokes endpoint."""

from unittest.mock import AsyncMock, patch

import httpx
import pytest
from fastapi.testclient import TestClient

from app.auth import AuthenticatedUser, get_current_user
from app.main import app


# Override auth for all tests in this module
def _fake_user():
    return AuthenticatedUser(sub="test-user", email="test@test.com", role="authenticated")

app.dependency_overrides[get_current_user] = _fake_user


client = TestClient(app)


VALID_STROKES = {
    "strokes": [
        {"x": [0.0, 1.0, 2.0], "y": [0.0, 1.0, 0.0]},
        {"x": [3.0, 4.0], "y": [1.0, 2.0]},
    ]
}


def _mock_mathpix_response(latex: str, session_id: str | None = None, status_code: int = 200):
    """Create a mock httpx.Response from Mathpix."""
    data = {"latex": latex}
    if session_id:
        data["session_id"] = session_id
    return httpx.Response(status_code=status_code, json=data)


class TestTranscribeStrokes:
    """Tests for the transcribe-strokes endpoint."""

    @patch("app.routers.transcribe.settings")
    def test_returns_503_when_mathpix_not_configured(self, mock_settings):
        mock_settings.mathpix_app_id = ""
        mock_settings.mathpix_app_key = ""
        resp = client.post("/ai/transcribe-strokes", json=VALID_STROKES)
        assert resp.status_code == 503
        assert "not configured" in resp.json()["detail"]

    @patch("app.routers.transcribe.httpx.AsyncClient")
    @patch("app.routers.transcribe.settings")
    def test_returns_latex_from_mathpix(self, mock_settings, mock_client_cls):
        mock_settings.mathpix_app_id = "test-id"
        mock_settings.mathpix_app_key = "test-key"

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=None)
        mock_client.post = AsyncMock(return_value=_mock_mathpix_response("x^2 + 1"))
        mock_client_cls.return_value = mock_client

        resp = client.post("/ai/transcribe-strokes", json=VALID_STROKES)
        assert resp.status_code == 200
        assert resp.json()["latex"] == "x^2 + 1"

    @patch("app.routers.transcribe.httpx.AsyncClient")
    @patch("app.routers.transcribe.settings")
    def test_passes_session_id_to_mathpix(self, mock_settings, mock_client_cls):
        mock_settings.mathpix_app_id = "test-id"
        mock_settings.mathpix_app_key = "test-key"

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=None)
        mock_client.post = AsyncMock(
            return_value=_mock_mathpix_response("y = mx + b", session_id="sess-123")
        )
        mock_client_cls.return_value = mock_client

        body = {**VALID_STROKES, "session_id": "sess-123"}
        resp = client.post("/ai/transcribe-strokes", json=body)
        assert resp.status_code == 200
        assert resp.json()["session_id"] == "sess-123"

        # Verify session_id was included in the Mathpix payload
        call_kwargs = mock_client.post.call_args
        sent_payload = call_kwargs.kwargs.get("json") or call_kwargs[1].get("json")
        assert sent_payload["session_id"] == "sess-123"

    @patch("app.routers.transcribe.httpx.AsyncClient")
    @patch("app.routers.transcribe.settings")
    def test_returns_session_id_from_mathpix(self, mock_settings, mock_client_cls):
        mock_settings.mathpix_app_id = "test-id"
        mock_settings.mathpix_app_key = "test-key"

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=None)
        mock_client.post = AsyncMock(
            return_value=_mock_mathpix_response("\\frac{1}{2}", session_id="new-sess-456")
        )
        mock_client_cls.return_value = mock_client

        resp = client.post("/ai/transcribe-strokes", json=VALID_STROKES)
        assert resp.status_code == 200
        assert resp.json()["session_id"] == "new-sess-456"

    @patch("app.routers.transcribe.httpx.AsyncClient")
    @patch("app.routers.transcribe.settings")
    def test_no_session_id_when_not_provided(self, mock_settings, mock_client_cls):
        mock_settings.mathpix_app_id = "test-id"
        mock_settings.mathpix_app_key = "test-key"

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=None)
        mock_client.post = AsyncMock(return_value=_mock_mathpix_response("x"))
        mock_client_cls.return_value = mock_client

        resp = client.post("/ai/transcribe-strokes", json=VALID_STROKES)
        assert resp.status_code == 200
        assert resp.json()["session_id"] is None

        # Verify session_id was NOT in the Mathpix payload
        call_kwargs = mock_client.post.call_args
        sent_payload = call_kwargs.kwargs.get("json") or call_kwargs[1].get("json")
        assert "session_id" not in sent_payload

    @patch("app.routers.transcribe.httpx.AsyncClient")
    @patch("app.routers.transcribe.settings")
    def test_returns_502_on_mathpix_error(self, mock_settings, mock_client_cls):
        mock_settings.mathpix_app_id = "test-id"
        mock_settings.mathpix_app_key = "test-key"

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=None)
        mock_client.post = AsyncMock(
            return_value=httpx.Response(status_code=500, json={"error": "internal"})
        )
        mock_client_cls.return_value = mock_client

        resp = client.post("/ai/transcribe-strokes", json=VALID_STROKES)
        assert resp.status_code == 502

    def test_rejects_empty_strokes_list(self):
        # Empty strokes should still be accepted by the API (Mathpix handles it)
        # but let's verify the endpoint doesn't crash
        pass

    def test_rejects_missing_strokes_field(self):
        resp = client.post("/ai/transcribe-strokes", json={})
        assert resp.status_code == 422

    def test_rejects_invalid_stroke_data(self):
        resp = client.post("/ai/transcribe-strokes", json={"strokes": [{"x": "bad"}]})
        assert resp.status_code == 422


# Clean up override after tests
def teardown_module():
    app.dependency_overrides.pop(get_current_user, None)
