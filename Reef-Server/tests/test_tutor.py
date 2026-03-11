"""Tests for POST /ai/evaluate-step endpoint."""

import json
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.auth import AuthenticatedUser, get_current_user
from app.main import app
from app.services.llm_client import LLMResult


# Override auth for all tests in this module
def _fake_user():
    return AuthenticatedUser(sub="test-user", email="test@test.com", role="authenticated")


app.dependency_overrides[get_current_user] = _fake_user

client = TestClient(app)

VALID_BODY = {
    "question_text": "Solve for x: 2x + 4 = 10",
    "student_work": "2x = 6",
    "steps": [
        {"description": "Subtract 4 from both sides to isolate the variable term", "work": "2x = 6"},
        {"description": "Divide both sides by 2", "work": "x = 3"},
    ],
    "current_step_index": 0,
    "completed_step_indices": [],
}


def _make_llm_result(progress: float, status: str) -> LLMResult:
    """Build a fake LLMResult with the given evaluation fields."""
    content = json.dumps({"progress": progress, "status": status})
    return LLMResult(content=content, input_tokens=10, output_tokens=5)


class TestEvaluateStep:
    """Tests for the evaluate-step endpoint."""

    def test_returns_401_without_auth_token(self):
        # Remove the dependency override temporarily by using a fresh client
        # that does NOT have the override applied.
        app.dependency_overrides.pop(get_current_user, None)
        try:
            no_auth_client = TestClient(app, raise_server_exceptions=False)
            resp = no_auth_client.post("/ai/evaluate-step", json=VALID_BODY)
            assert resp.status_code == 403  # HTTPBearer returns 403 for missing credentials
        finally:
            # Restore the fake-user override for the rest of the tests
            app.dependency_overrides[get_current_user] = _fake_user

    def test_returns_422_with_missing_fields(self):
        resp = client.post("/ai/evaluate-step", json={})
        assert resp.status_code == 422

    def test_returns_422_with_partial_fields(self):
        partial = {"question_text": "Q", "student_work": "S"}
        resp = client.post("/ai/evaluate-step", json=partial)
        assert resp.status_code == 422

    @patch("app.routers.tutor.settings")
    def test_returns_503_when_openrouter_not_configured(self, mock_settings):
        mock_settings.openrouter_api_key = ""
        resp = client.post("/ai/evaluate-step", json=VALID_BODY)
        assert resp.status_code == 503
        assert "not configured" in resp.json()["detail"]

    @patch("app.routers.tutor.asyncio.to_thread")
    @patch("app.routers.tutor.LLMClient")
    @patch("app.routers.tutor.settings")
    def test_returns_200_with_mocked_llm(self, mock_settings, mock_llm_cls, mock_to_thread):
        mock_settings.openrouter_api_key = "test-key"

        mock_llm_instance = MagicMock()
        mock_llm_cls.return_value = mock_llm_instance

        # asyncio.to_thread is awaited in the endpoint, so return a coroutine
        import asyncio

        async def _fake_to_thread(fn, **kwargs):
            return _make_llm_result(progress=1.0, status="completed")

        mock_to_thread.side_effect = _fake_to_thread

        resp = client.post("/ai/evaluate-step", json=VALID_BODY)
        assert resp.status_code == 200
        data = resp.json()
        assert data["progress"] == 1.0
        assert data["status"] == "completed"

    @patch("app.routers.tutor.asyncio.to_thread")
    @patch("app.routers.tutor.LLMClient")
    @patch("app.routers.tutor.settings")
    def test_returns_idle_status_for_empty_work(self, mock_settings, mock_llm_cls, mock_to_thread):
        mock_settings.openrouter_api_key = "test-key"

        mock_llm_cls.return_value = MagicMock()

        async def _fake_to_thread(fn, **kwargs):
            return _make_llm_result(progress=0.0, status="idle")

        mock_to_thread.side_effect = _fake_to_thread

        body = {**VALID_BODY, "student_work": ""}
        resp = client.post("/ai/evaluate-step", json=body)
        assert resp.status_code == 200
        data = resp.json()
        assert data["progress"] == 0.0
        assert data["status"] == "idle"

    @patch("app.routers.tutor.asyncio.to_thread")
    @patch("app.routers.tutor.LLMClient")
    @patch("app.routers.tutor.settings")
    def test_returns_500_on_llm_failure(self, mock_settings, mock_llm_cls, mock_to_thread):
        mock_settings.openrouter_api_key = "test-key"

        mock_llm_cls.return_value = MagicMock()

        async def _fake_to_thread(fn, **kwargs):
            raise RuntimeError("LLM unavailable")

        mock_to_thread.side_effect = _fake_to_thread

        resp = client.post("/ai/evaluate-step", json=VALID_BODY)
        assert resp.status_code == 500
        assert "evaluation failed" in resp.json()["detail"]

    @patch("app.routers.tutor.asyncio.to_thread")
    @patch("app.routers.tutor.LLMClient")
    @patch("app.routers.tutor.settings")
    def test_llm_client_created_with_correct_model_and_base_url(
        self, mock_settings, mock_llm_cls, mock_to_thread
    ):
        mock_settings.openrouter_api_key = "my-openrouter-key"

        mock_llm_instance = MagicMock()
        mock_llm_cls.return_value = mock_llm_instance

        async def _fake_to_thread(fn, **kwargs):
            return _make_llm_result(progress=0.5, status="working")

        mock_to_thread.side_effect = _fake_to_thread

        client.post("/ai/evaluate-step", json=VALID_BODY)

        mock_llm_cls.assert_called_once_with(
            api_key="my-openrouter-key",
            model="google/gemini-3-flash-preview",
            base_url="https://openrouter.ai/api/v1",
        )


# Clean up override after tests
def teardown_module():
    app.dependency_overrides.pop(get_current_user, None)
