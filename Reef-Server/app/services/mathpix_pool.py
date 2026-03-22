"""Pooled Mathpix sessions — max 10 users per session, auto-scales.

Each session serves up to 10 concurrent users. When all sessions are
full, a new one is created. Sessions expire after 4 minutes and are
cleaned up lazily on the next request.
"""

import logging
import time
from dataclasses import dataclass, field

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

MAX_USERS_PER_SESSION = 10
SESSION_TTL = 240  # 4 minutes (Mathpix gives 5, we refresh early)


@dataclass
class PooledSession:
    app_token: str
    session_id: str
    expires_at: float
    user_count: int = 0

    @property
    def is_valid(self) -> bool:
        return time.time() < self.expires_at

    @property
    def has_capacity(self) -> bool:
        return self.user_count < MAX_USERS_PER_SESSION and self.is_valid


_pool: list[PooledSession] = []


async def acquire_session() -> tuple[str, str, int]:
    """Get a session with capacity, or create a new one.

    Returns (app_token, strokes_session_id, expires_at_ms).
    Increments user_count on the assigned session.
    """
    # Clean up expired sessions
    _pool[:] = [s for s in _pool if s.is_valid]

    # Find a session with capacity
    for session in _pool:
        if session.has_capacity:
            session.user_count += 1
            logger.info(
                f"[mathpix-pool] Assigned session {session.session_id} "
                f"({session.user_count}/{MAX_USERS_PER_SESSION} users)"
            )
            return session.app_token, session.session_id, int(session.expires_at * 1000)

    # No capacity — create a new session
    session = await _create_session()
    session.user_count = 1
    _pool.append(session)
    logger.info(
        f"[mathpix-pool] Created new session {session.session_id} "
        f"(pool size: {len(_pool)})"
    )
    return session.app_token, session.session_id, int(session.expires_at * 1000)


def release_session(session_id: str) -> None:
    """Decrement user count when a user's session expires on the client."""
    for session in _pool:
        if session.session_id == session_id:
            session.user_count = max(0, session.user_count - 1)
            return


async def _create_session() -> PooledSession:
    """Create a new Mathpix session via the API."""
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
    return PooledSession(
        app_token=data["app_token"],
        session_id=data["strokes_session_id"],
        expires_at=time.time() + SESSION_TTL,
    )
