"""Mathpix Strokes API client for real-time handwriting recognition.

Uses session-based strokes endpoint for live updates as the user draws.
Docs: https://docs.mathpix.com/reference/post-v3-strokes
"""

import httpx

from app.config import settings

BASE_URL = "https://api.mathpix.com"


def _auth_headers() -> dict[str, str]:
    return {
        "app_id": settings.mathpix_app_id,
        "app_key": settings.mathpix_app_key,
        "Content-Type": "application/json",
    }


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
