"""Tests for POST /render-latex endpoint and the latex_renderer service."""

import io
import struct
import zlib
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.auth import AuthenticatedUser, get_current_user
from app.main import app
from app.services.latex_renderer import _parse_segments, _build_lines, render_latex_to_png


# ---------------------------------------------------------------------------
# Auth override
# ---------------------------------------------------------------------------

def _fake_user():
    return AuthenticatedUser(sub="test-user", email="test@test.com", role="authenticated")


app.dependency_overrides[get_current_user] = _fake_user
client = TestClient(app)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _is_valid_png(data: bytes) -> bool:
    """Return True if *data* starts with the PNG magic bytes."""
    return data[:8] == b"\x89PNG\r\n\x1a\n"


def _png_dimensions(data: bytes) -> tuple[int, int]:
    """Return (width, height) from a PNG IHDR chunk (bytes 16-24)."""
    return struct.unpack(">II", data[16:24])


# ---------------------------------------------------------------------------
# Unit tests: _parse_segments
# ---------------------------------------------------------------------------

class TestParseSegments:
    def test_plain_text_only(self):
        segs = _parse_segments("Hello world")
        assert len(segs) == 1
        assert segs[0].text == "Hello world"
        assert not segs[0].is_inline_math
        assert not segs[0].is_display_math

    def test_inline_math(self):
        segs = _parse_segments("See $x^2$ here")
        assert len(segs) == 3
        assert segs[0].text == "See "
        assert segs[1].is_inline_math
        assert segs[1].text == "$x^2$"
        assert segs[2].text == " here"

    def test_display_math(self):
        segs = _parse_segments(r"\[ E = mc^2 \]")
        assert len(segs) == 1
        assert segs[0].is_display_math
        assert "E = mc^2" in segs[0].text

    def test_mixed_inline_and_display(self):
        text = r"Recall $P(A)$ and \[ P(B) = 0.5 \] done"
        segs = _parse_segments(text)
        # Should have: "Recall ", inline, " and ", display, " done"
        types = [(s.is_inline_math, s.is_display_math) for s in segs]
        inline_count = sum(1 for im, _ in types if im)
        display_count = sum(1 for _, dm in types if dm)
        assert inline_count == 1
        assert display_count == 1

    def test_empty_string(self):
        segs = _parse_segments("")
        assert segs == []

    def test_multiple_inline(self):
        text = "We have $a$ and $b$."
        segs = _parse_segments(text)
        inline_segs = [s for s in segs if s.is_inline_math]
        assert len(inline_segs) == 2


# ---------------------------------------------------------------------------
# Unit tests: render_latex_to_png
# ---------------------------------------------------------------------------

class TestRenderLatexToPng:
    def test_returns_bytes(self):
        result = render_latex_to_png("Hello world")
        assert isinstance(result, bytes)

    def test_output_is_valid_png(self):
        result = render_latex_to_png("Hello world")
        assert _is_valid_png(result)

    def test_inline_math_renders(self):
        result = render_latex_to_png("The value is $x^2 + y^2 = r^2$.")
        assert _is_valid_png(result)
        assert len(result) > 100  # Non-trivial output

    def test_display_math_renders(self):
        text = r"Result: \[ P(A \cap B) = P(A \mid B)P(B) \]"
        result = render_latex_to_png(text)
        assert _is_valid_png(result)

    def test_mixed_text_and_math(self):
        text = (
            r"Remember that $P(A \cap B) = P(A \mid B)P(B)$ "
            r"— you've got both those numbers handy."
        )
        result = render_latex_to_png(text)
        assert _is_valid_png(result)

    def test_multiline_display_math(self):
        text = (
            r"\[ P(A \cap B) = P(A \mid B)P(B) \]"
            "\n"
            r"\[ P(A \cap B) = 0.3 \times 0.8 = 0.24 \]"
        )
        result = render_latex_to_png(text)
        assert _is_valid_png(result)

    def test_custom_font_size(self):
        result_small = render_latex_to_png("Hello", font_size=10.0)
        result_large = render_latex_to_png("Hello", font_size=24.0)
        assert _is_valid_png(result_small)
        assert _is_valid_png(result_large)
        # Larger font → taller image
        _, h_small = _png_dimensions(result_small)
        _, h_large = _png_dimensions(result_large)
        assert h_large > h_small

    def test_custom_max_width(self):
        long_text = "This is a moderately long sentence that might wrap differently."
        narrow = render_latex_to_png(long_text, max_width=150)
        wide = render_latex_to_png(long_text, max_width=600)
        assert _is_valid_png(narrow)
        assert _is_valid_png(wide)

    def test_empty_text_returns_png(self):
        # Should not raise; returns a minimal valid PNG.
        result = render_latex_to_png("")
        assert _is_valid_png(result)


# ---------------------------------------------------------------------------
# Integration tests: POST /render-latex
# ---------------------------------------------------------------------------

VALID_BODY = {
    "text": "The value is $x^2$.",
    "font_size": 14,
    "max_width": 260,
}


class TestRenderLatexEndpoint:
    def test_returns_401_without_auth(self):
        app.dependency_overrides.pop(get_current_user, None)
        try:
            no_auth = TestClient(app, raise_server_exceptions=False)
            resp = no_auth.post("/render-latex", json=VALID_BODY)
            assert resp.status_code == 403
        finally:
            app.dependency_overrides[get_current_user] = _fake_user

    def test_returns_422_with_missing_text(self):
        resp = client.post("/render-latex", json={"font_size": 14})
        assert resp.status_code == 422

    def test_returns_422_with_empty_text(self):
        resp = client.post("/render-latex", json={"text": ""})
        assert resp.status_code == 422

    def test_returns_422_with_font_size_out_of_range(self):
        resp = client.post("/render-latex", json={"text": "Hi", "font_size": 200})
        assert resp.status_code == 422

    def test_returns_png_content_type(self):
        resp = client.post("/render-latex", json=VALID_BODY)
        assert resp.status_code == 200
        assert resp.headers["content-type"] == "image/png"

    def test_response_is_valid_png(self):
        resp = client.post("/render-latex", json=VALID_BODY)
        assert resp.status_code == 200
        assert _is_valid_png(resp.content)

    def test_inline_math_request(self):
        body = {
            "text": r"Remember that $P(A \cap B) = P(A \mid B)P(B)$ — handy.",
            "font_size": 14,
            "max_width": 260,
        }
        resp = client.post("/render-latex", json=body)
        assert resp.status_code == 200
        assert _is_valid_png(resp.content)

    def test_display_math_request(self):
        body = {
            "text": r"\[ P(A \cap B) = P(A \mid B)P(B) \]" + "\n" + r"\[ P(A \cap B) = 0.24 \]",
            "font_size": 14,
            "max_width": 260,
        }
        resp = client.post("/render-latex", json=body)
        assert resp.status_code == 200
        assert _is_valid_png(resp.content)

    def test_returns_500_on_renderer_failure(self):
        with patch("app.routers.render_latex.render_latex_to_png", side_effect=RuntimeError("boom")):
            resp = client.post("/render-latex", json=VALID_BODY)
        assert resp.status_code == 500
        assert "rendering failed" in resp.json()["detail"].lower()

    def test_cache_control_header_present(self):
        resp = client.post("/render-latex", json=VALID_BODY)
        assert resp.status_code == 200
        assert "cache-control" in resp.headers

    def test_default_values_used_when_omitted(self):
        # Only `text` is required; font_size and max_width should default.
        resp = client.post("/render-latex", json={"text": "Plain text only."})
        assert resp.status_code == 200
        assert _is_valid_png(resp.content)


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

def teardown_module():
    app.dependency_overrides.pop(get_current_user, None)
