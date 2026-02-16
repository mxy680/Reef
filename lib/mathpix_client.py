"""Mathpix handwriting transcription at the page level.

Each transcription call creates a fresh Mathpix session and sends ALL visible
strokes. Erase/clear events invalidate (cancel pending debounce) so the next
draw triggers a clean re-transcription.

Requires MATHPIX_APP_ID and MATHPIX_APP_KEY env vars. If missing,
transcription is silently skipped.
"""

import asyncio
import json
import os
from dataclasses import dataclass

import httpx

from lib.database import get_pool

MATHPIX_BASE = "https://api.mathpix.com"
DEBOUNCE_SECONDS = 1.5


@dataclass
class MathpixSession:
    strokes_session_id: str
    app_token: str


# (session_id, page) → pending debounce asyncio.Task
_debounce_tasks: dict[tuple[str, int], asyncio.Task] = {}


def _get_credentials() -> tuple[str, str]:
    app_id = os.environ.get("MATHPIX_APP_ID", "")
    app_key = os.environ.get("MATHPIX_APP_KEY", "")
    if not app_id or not app_key:
        raise RuntimeError("MATHPIX_APP_ID and MATHPIX_APP_KEY not set")
    return app_id, app_key


async def create_session() -> MathpixSession:
    app_id, app_key = _get_credentials()
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{MATHPIX_BASE}/v3/app-tokens",
            headers={
                "app_id": app_id,
                "app_key": app_key,
                "Content-Type": "application/json",
            },
            json={"include_strokes_session_id": True},
        )
        resp.raise_for_status()
        data = resp.json()

    return MathpixSession(
        strokes_session_id=data["strokes_session_id"],
        app_token=data["app_token"],
    )


def invalidate_session(session_id: str, page: int) -> None:
    key = (session_id, page)
    task = _debounce_tasks.pop(key, None)
    if task:
        task.cancel()
    print(f"[mathpix] invalidated session ({session_id}, page={page})")


def cleanup_sessions(session_id: str) -> None:
    keys_to_remove = [k for k in _debounce_tasks if k[0] == session_id]
    for key in keys_to_remove:
        task = _debounce_tasks.pop(key, None)
        if task:
            task.cancel()
    if keys_to_remove:
        print(f"[mathpix] cleaned up {len(keys_to_remove)} debounce task(s) for {session_id}")


def reef_strokes_to_mathpix(strokes: list[dict]) -> dict:
    """Convert Reef stroke format to Mathpix strokes format.

    Reef format (per stroke):
        {"points": [{"x": float, "y": float, "t": float, ...}, ...]}

    Mathpix format:
        {"strokes": {"x": [[x1, x2, ...], ...], "y": [[y1, y2, ...], ...]}}
    """
    all_x = []
    all_y = []

    for stroke in strokes:
        points = stroke.get("points", [])
        if not points:
            continue
        all_x.append([p["x"] for p in points])
        all_y.append([p["y"] for p in points])

    return {"strokes": {"x": all_x, "y": all_y}}


async def send_strokes(session: MathpixSession, strokes: list[dict]) -> dict:
    payload = reef_strokes_to_mathpix(strokes)
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{MATHPIX_BASE}/v3/strokes",
            headers={
                "app_token": session.app_token,
                "Content-Type": "application/json",
            },
            json={
                "strokes_session_id": session.strokes_session_id,
                "strokes": payload,
            },
        )
        resp.raise_for_status()
        return resp.json()


def schedule_transcription(session_id: str, page: int) -> None:
    key = (session_id, page)
    existing = _debounce_tasks.pop(key, None)
    if existing:
        existing.cancel()
    _debounce_tasks[key] = asyncio.create_task(
        _debounced_transcription(session_id, page)
    )


async def _debounced_transcription(session_id: str, page: int) -> None:
    await asyncio.sleep(DEBOUNCE_SECONDS)
    _debounce_tasks.pop((session_id, page), None)
    await _do_transcription(session_id, page)


async def _do_transcription(session_id: str, page: int) -> None:
    try:
        _get_credentials()
    except RuntimeError:
        return

    pool = get_pool()
    if not pool:
        return

    try:
        # Fetch all visible stroke_logs (resolve erases)
        async with pool.acquire() as conn:
            all_rows = await conn.fetch(
                """
                SELECT id, strokes, event_type
                FROM stroke_logs
                WHERE session_id = $1 AND page = $2 AND event_type IN ('draw', 'erase')
                ORDER BY received_at
                """,
                session_id, page,
            )

        visible_rows: list[dict] = []
        for row in all_rows:
            if row["event_type"] == "erase":
                visible_rows = [dict(row)]
            else:
                visible_rows.append(dict(row))

        if not visible_rows:
            return

        # Collect all visible strokes
        all_strokes: list[dict] = []
        for row in visible_rows:
            strokes_data = row["strokes"]
            if isinstance(strokes_data, str):
                strokes_data = json.loads(strokes_data)
            for stroke in strokes_data:
                if stroke.get("points"):
                    all_strokes.append(stroke)

        if not all_strokes:
            return

        # Fresh session each call — no incremental tracking
        session = await create_session()
        result = await send_strokes(session, all_strokes)

        latex = result.get("latex_styled", "") or result.get("text", "")
        text = result.get("text", "")
        confidence = result.get("confidence", 0.0)

        # UPSERT into page_transcriptions
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO page_transcriptions (session_id, page, latex, text, confidence, updated_at)
                VALUES ($1, $2, $3, $4, $5, NOW())
                ON CONFLICT (session_id, page) DO UPDATE SET
                    latex = EXCLUDED.latex,
                    text = EXCLUDED.text,
                    confidence = EXCLUDED.confidence,
                    updated_at = NOW()
                """,
                session_id, page, latex, text, confidence,
            )

        print(
            f"[mathpix] ({session_id}, page={page}): "
            f"sent {len(all_strokes)} strokes, "
            f"confidence={confidence:.2f}, "
            f"latex={latex[:80]}"
        )

    except Exception as e:
        print(f"[mathpix] error for ({session_id}, page={page}): {e}")
