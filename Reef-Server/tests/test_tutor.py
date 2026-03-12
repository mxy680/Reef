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


def _make_llm_result(progress: float, status: str, feedback: str = "") -> LLMResult:
    """Build a fake LLMResult with the given evaluation fields."""
    content = json.dumps({"progress": progress, "status": status, "feedback": feedback})
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
            assert resp.status_code in (401, 403)  # HTTPBearer returns 401 or 403 depending on version
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


class TestNormalizeLatex:
    """Tests for _normalize_latex helper."""

    def test_strips_dollar_signs(self):
        from app.routers.tutor import _normalize_latex
        assert _normalize_latex("$x = 4$") == "x=4"

    def test_strips_display_delimiters(self):
        from app.routers.tutor import _normalize_latex
        assert _normalize_latex(r"\[x = 4\]") == "x=4"

    def test_strips_left_right(self):
        from app.routers.tutor import _normalize_latex
        # Braces are also stripped, so full normalization gives:
        assert _normalize_latex(r"\left(\frac{a}{b}\right)") == "(\\fracab)"

    def test_strips_text_command(self):
        from app.routers.tutor import _normalize_latex
        assert _normalize_latex(r"\text{kg}") == "kg"

    def test_strips_whitespace_and_lowercases(self):
        from app.routers.tutor import _normalize_latex
        assert _normalize_latex("  X  =  4  ") == "x=4"


class TestExtractKeyResult:
    """Tests for _extract_key_result helper."""

    def test_simple_equation(self):
        from app.routers.tutor import _extract_key_result
        assert _extract_key_result("x = 4").strip() == "4"

    def test_chained_equals(self):
        from app.routers.tutor import _extract_key_result
        assert _extract_key_result("a = b = c").strip() == "c"

    def test_multiline_takes_last(self):
        from app.routers.tutor import _extract_key_result
        result = _extract_key_result("2x = 8\nx = 4")
        assert result.strip() == "4"

    def test_no_equals(self):
        from app.routers.tutor import _extract_key_result
        assert _extract_key_result("\\frac{1}{2}") == "\\frac{1}{2}"


class TestStudentWorkContainsExpected:
    """Tests for _student_work_contains_expected helper."""

    def test_matching_result(self):
        from app.routers.tutor import _student_work_contains_expected
        assert _student_work_contains_expected("$x = 4$", "x = 4") is True

    def test_missing_result(self):
        from app.routers.tutor import _student_work_contains_expected
        # Use a longer expected result so the min-length guard doesn't skip
        assert _student_work_contains_expected("$2x = 8$", r"x = \frac{-3}{2}") is False

    def test_accumulated_work(self):
        from app.routers.tutor import _student_work_contains_expected
        # Student has work from prior steps plus the current result
        student = "$2x + 4 = 10$ $2x = 6$ $x = 3$"
        assert _student_work_contains_expected(student, "x = 3") is True

    def test_short_expression_skips_check(self):
        from app.routers.tutor import _student_work_contains_expected
        # "x = 4" extracts "4" → 1 char → skip validation → always True
        assert _student_work_contains_expected("anything", "x = 4") is True

    def test_multiline_expected_work(self):
        from app.routers.tutor import _student_work_contains_expected
        expected = "2x = 8\nx = 4"
        student = "$x = 4$"
        assert _student_work_contains_expected(student, expected) is True


class TestCompletionOverride:
    """Tests that LLM 'completed' is overridden when student work is missing expected result."""

    @patch("app.routers.tutor.asyncio.to_thread")
    @patch("app.routers.tutor.LLMClient")
    @patch("app.routers.tutor.settings")
    def test_overrides_completed_when_result_missing(self, mock_settings, mock_llm_cls, mock_to_thread):
        mock_settings.openrouter_api_key = "test-key"
        mock_llm_cls.return_value = MagicMock()

        async def _fake_to_thread(fn, **kwargs):
            return _make_llm_result(progress=1.0, status="completed")

        mock_to_thread.side_effect = _fake_to_thread

        # Use steps with a longer expected result (>= 2 chars after normalization)
        # so the min-length guard doesn't skip validation
        body = {
            "question_text": "Find the derivative of f(x) = 3x^2 + 2x",
            "student_work": "$6x$",  # missing the "+ 2" part
            "steps": [
                {"description": "Apply power rule", "work": "f'(x) = 6x + 2"},
            ],
            "current_step_index": 0,
            "completed_step_indices": [],
        }
        resp = client.post("/ai/evaluate-step", json=body)
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "working"
        assert data["progress"] <= 0.95

    @patch("app.routers.tutor.asyncio.to_thread")
    @patch("app.routers.tutor.LLMClient")
    @patch("app.routers.tutor.settings")
    def test_allows_completed_when_result_present(self, mock_settings, mock_llm_cls, mock_to_thread):
        mock_settings.openrouter_api_key = "test-key"
        mock_llm_cls.return_value = MagicMock()

        async def _fake_to_thread(fn, **kwargs):
            return _make_llm_result(progress=1.0, status="completed")

        mock_to_thread.side_effect = _fake_to_thread

        # Student has written the expected result
        body = {
            "question_text": "Find the derivative of f(x) = 3x^2 + 2x",
            "student_work": "$f'(x) = 6x + 2$",
            "steps": [
                {"description": "Apply power rule", "work": "f'(x) = 6x + 2"},
            ],
            "current_step_index": 0,
            "completed_step_indices": [],
        }
        resp = client.post("/ai/evaluate-step", json=body)
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "completed"
        assert data["progress"] == 1.0


# Clean up override after tests
def teardown_module():
    app.dependency_overrides.pop(get_current_user, None)
