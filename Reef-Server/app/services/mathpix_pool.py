"""Shared Mathpix session — one global session refreshed every 4 minutes.

All users share the same session. Since we send all strokes on every
request (not deltas), the session is stateless from our perspective.
Cost: $0.01 per 4 minutes flat, regardless of user count.
"""

import logging
import time

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

# Refresh 1 minute before expiry to avoid edge cases
_SESSION_TTL = 240  # 4 minutes (Mathpix gives 5 min, we refresh early)


class _SharedSession:
    def __init__(self):
        self.app_token: str | None = None
        self.session_id: str | None = None
        self.expires_at: float = 0  # unix timestamp

    @property
    def is_valid(self) -> bool:
        return (
            self.app_token is not None
            and self.session_id is not None
            and time.time() < self.expires_at
        )


_session = _SharedSession()


async def get_shared_session() -> tuple[str, str, int]:
    """Get or create the shared Mathpix session.

    Returns (app_token, strokes_session_id, expires_at_ms).
    """
    if _session.is_valid:
        return (
            _session.app_token,  # type: ignore
            _session.session_id,  # type: ignore
            int(_session.expires_at * 1000),
        )

    # Create a new session
    if not settings.mathpix_app_key:
        raise RuntimeError("Mathpix credentials not configured")

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            "https://api.mathpix.com/v3/app-tokens",
            headers={"app_key": settings.mathpix_app_key},
            json={"include_strokes_session_id": True, "expires": 300},
        )

    if resp.status_code != 200:
        logger.warning(f"Mathpix app-tokens API returned {resp.status_code}: {resp.text}")
        raise RuntimeError("Failed to create Mathpix session")

    data = resp.json()
    _session.app_token = data["app_token"]
    _session.session_id = data["strokes_session_id"]
    _session.expires_at = time.time() + _SESSION_TTL

    logger.info(f"[mathpix-pool] New shared session: {_session.session_id}")

    return (
        _session.app_token,
        _session.session_id,
        int(_session.expires_at * 1000),
    )
