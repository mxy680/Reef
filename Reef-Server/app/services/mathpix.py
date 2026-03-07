"""Mathpix API client for handwriting recognition and PDF processing.

Strokes: session-based endpoint for live handwriting recognition.
PDF: async endpoint for full-document OCR → Mathpix Markdown.
Docs: https://docs.mathpix.com/reference/
"""

import asyncio

import httpx

from app.config import settings

BASE_URL = "https://api.mathpix.com"


def _auth_headers() -> dict[str, str]:
    return {
        "app_id": settings.mathpix_app_id,
        "app_key": settings.mathpix_app_key,
        "Content-Type": "application/json",
    }


# ---------------------------------------------------------------------------
# PDF processing (Convert API)
# ---------------------------------------------------------------------------


async def submit_pdf(pdf_bytes: bytes, filename: str = "document.pdf") -> str:
    """Submit a PDF for OCR processing. Returns pdf_id."""
    headers = {
        "app_id": settings.mathpix_app_id,
        "app_key": settings.mathpix_app_key,
    }
    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(
            f"{BASE_URL}/v3/pdf",
            headers=headers,
            files={"file": (filename, pdf_bytes, "application/pdf")},
            data={
                "options_json": (
                    '{"conversion_formats": {},'
                    ' "math_inline_delimiters": ["$", "$"],'
                    ' "math_display_delimiters": ["$$", "$$"]}'
                )
            },
        )
        resp.raise_for_status()
        return resp.json()["pdf_id"]


async def poll_pdf(pdf_id: str, interval: float = 2.0, timeout: float = 120.0) -> dict:
    """Poll until PDF processing completes. Returns final status dict."""
    headers = _auth_headers()
    elapsed = 0.0
    async with httpx.AsyncClient(timeout=30.0) as client:
        while elapsed < timeout:
            resp = await client.get(f"{BASE_URL}/v3/pdf/{pdf_id}", headers=headers)
            resp.raise_for_status()
            data = resp.json()
            status = data.get("status", "unknown")
            if status == "completed":
                return data
            if status == "error":
                raise RuntimeError(f"Mathpix PDF processing failed: {data}")
            await asyncio.sleep(interval)
            elapsed += interval
    raise TimeoutError(f"Mathpix PDF processing timed out after {timeout}s")


async def download_mmd(pdf_id: str) -> str:
    """Download Mathpix Markdown (.mmd) result for a processed PDF."""
    headers = _auth_headers()
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(f"{BASE_URL}/v3/pdf/{pdf_id}.mmd", headers=headers)
        resp.raise_for_status()
        return resp.text


async def pdf_to_mmd(pdf_bytes: bytes, filename: str = "document.pdf") -> str:
    """Full pipeline: submit PDF → poll → download MMD. Returns Mathpix Markdown."""
    pdf_id = await submit_pdf(pdf_bytes, filename)
    await poll_pdf(pdf_id)
    return await download_mmd(pdf_id)


async def create_strokes_session(expires: int = 300) -> dict:
    """Request an app token with a strokes_session_id for live updates.

    Returns dict with 'app_token' and 'strokes_session_id'.
    """
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{BASE_URL}/v3/app-tokens",
            headers=_auth_headers(),
            json={
                "include_strokes_session_id": True,
                "expires": expires,
            },
        )
        resp.raise_for_status()
        return resp.json()


async def send_strokes(
    strokes_x: list[list[float]],
    strokes_y: list[list[float]],
    session_id: str | None = None,
    app_token: str | None = None,
) -> dict:
    """Send stroke coordinates to Mathpix for recognition.

    Args:
        strokes_x: List of x-coordinate arrays, one per stroke.
        strokes_y: List of y-coordinate arrays, one per stroke.
        session_id: Optional strokes_session_id for live session updates.
        app_token: Required when using session_id (from create_strokes_session).

    Returns:
        Mathpix response with 'latex_styled', 'text', 'confidence', etc.
    """
    if session_id and app_token:
        headers = {
            "app_token": app_token,
            "Content-Type": "application/json",
        }
    else:
        headers = _auth_headers()

    body: dict = {
        "strokes": {
            "strokes": {
                "x": strokes_x,
                "y": strokes_y,
            }
        },
    }

    if session_id:
        body["strokes_session_id"] = session_id

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{BASE_URL}/v3/strokes",
            headers=headers,
            json=body,
            timeout=10.0,
        )
        resp.raise_for_status()
        return resp.json()
