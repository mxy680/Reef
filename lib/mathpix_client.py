"""Mathpix strokes-session transcription.

Sends ALL visible strokes to Mathpix /v3/strokes on each debounced draw,
reusing the same session within its 5-min TTL (billed once per session).

Requires MATHPIX_APP_ID and MATHPIX_APP_KEY env vars.
"""

import asyncio
import hashlib
import json
import os
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import httpx

from lib.database import get_pool

MATHPIX_BASE = "https://api.mathpix.com"
DEBOUNCE_SECONDS = 0.5
REASONING_DEBOUNCE_SECONDS = 2.5


@dataclass
class MathpixSession:
    strokes_session_id: str
    app_token: str
    expires_at: datetime


# (session_id, page) → MathpixSession
_sessions: dict[tuple[str, int], MathpixSession] = {}

# (session_id, page) → pending debounce asyncio.Task
_debounce_tasks: dict[tuple[str, int], asyncio.Task] = {}

# (session_id, page) → pending reasoning asyncio.Task (separate debounce)
_reasoning_tasks: dict[tuple[str, int], asyncio.Task] = {}

# (session_id, page) → deque of pre-erase transcription texts (max 3, newest last)
_erase_snapshots: dict[tuple[str, int], deque[str]] = {}


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
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=4, seconds=30),
    )


async def get_or_create_session(
    session_id: str, page: int
) -> MathpixSession:
    key = (session_id, page)
    existing = _sessions.get(key)
    if existing and datetime.now(timezone.utc) < existing.expires_at:
        return existing
    session = await create_session()
    _sessions[key] = session
    print(f"[mathpix] opened session ({session_id}, page={page})")
    return session


def invalidate_session(session_id: str, page: int) -> None:
    key = (session_id, page)
    _sessions.pop(key, None)
    _last_stroke_hash.pop(key, None)
    _erase_snapshots.pop(key, None)
    task = _debounce_tasks.pop(key, None)
    if task:
        task.cancel()
    r_task = _reasoning_tasks.pop(key, None)
    if r_task:
        r_task.cancel()
    print(f"[mathpix] invalidated session ({session_id}, page={page})")


def get_session_info(session_id: str, page: int) -> dict | None:
    """Return session expiry and strokes_session_id, or None if no session."""
    key = (session_id, page)
    session = _sessions.get(key)
    if session and datetime.now(timezone.utc) < session.expires_at:
        return {
            "expires_at": session.expires_at.isoformat(),
            "strokes_session_id": session.strokes_session_id,
        }
    return None


def cleanup_sessions(session_id: str) -> None:
    keys_to_remove = [k for k in _sessions if k[0] == session_id]
    for key in keys_to_remove:
        _sessions.pop(key, None)
        _last_stroke_hash.pop(key, None)
        task = _debounce_tasks.pop(key, None)
        if task:
            task.cancel()
        r_task = _reasoning_tasks.pop(key, None)
        if r_task:
            r_task.cancel()
    # Also cancel reasoning tasks for pages not in _sessions
    r_keys = [k for k in _reasoning_tasks if k[0] == session_id]
    for key in r_keys:
        r_task = _reasoning_tasks.pop(key, None)
        if r_task:
            r_task.cancel()
    # Clean up stroke hashes for this session
    hash_keys = [k for k in _last_stroke_hash if k[0] == session_id]
    for key in hash_keys:
        _last_stroke_hash.pop(key, None)
    # Clean up erase snapshots for this session
    snap_keys = [k for k in _erase_snapshots if k[0] == session_id]
    for key in snap_keys:
        _erase_snapshots.pop(key, None)
    if keys_to_remove or r_keys:
        print(f"[mathpix] cleaned up {len(keys_to_remove)} session(s) for {session_id}")


# ── Reasoning debounce ────────────────────────────────────


def schedule_reasoning(session_id: str, page: int) -> None:
    """Debounce 2.5s, then run the reasoning model (separate from transcription debounce)."""
    key = (session_id, page)
    existing = _reasoning_tasks.pop(key, None)
    if existing:
        existing.cancel()
    _reasoning_tasks[key] = asyncio.create_task(
        _debounced_reasoning(session_id, page)
    )


async def _debounced_reasoning(session_id: str, page: int) -> None:
    await asyncio.sleep(REASONING_DEBOUNCE_SECONDS)
    _reasoning_tasks.pop((session_id, page), None)

    try:
        from lib.reasoning import run_reasoning
        from api.reasoning import push_reasoning

        result = await run_reasoning(session_id, page)
        await push_reasoning(session_id, result["action"], result["message"])
    except Exception as e:
        print(f"[reasoning] error for ({session_id}, page={page}): {e}")


# ── Whole-page transcription ──────────────────────────────

# (session_id, page) → hash of visible stroke set (skip-if-unchanged)
_last_stroke_hash: dict[tuple[str, int], str] = {}

DIAGRAM_CONFIDENCE_THRESHOLD = 0.8   # below → diagram


def schedule_transcribe(session_id: str, page: int) -> None:
    """Debounce 500ms, then transcribe all visible strokes on this page."""
    key = (session_id, page)
    existing = _debounce_tasks.pop(key, None)
    if existing:
        existing.cancel()
    _debounce_tasks[key] = asyncio.create_task(
        _debounced_transcribe(session_id, page)
    )


async def _debounced_transcribe(session_id: str, page: int) -> None:
    await asyncio.sleep(DEBOUNCE_SECONDS)
    _debounce_tasks.pop((session_id, page), None)

    # Diagram mode: skip Mathpix, upsert empty transcription, schedule reasoning
    from api.strokes import _active_sessions
    info = _active_sessions.get(session_id, {})
    if info.get("content_mode") == "diagram":
        pool = get_pool()
        if pool:
            async with pool.acquire() as conn:
                await conn.execute(
                    """
                    INSERT INTO page_transcriptions (session_id, page, latex, text, confidence, updated_at)
                    VALUES ($1, $2, '', '', 0, NOW())
                    ON CONFLICT (session_id, page) DO UPDATE SET
                        latex = '', text = '', confidence = 0, updated_at = NOW()
                    """,
                    session_id, page,
                )
        print(f"[mathpix] ({session_id}, page={page}): diagram mode, skipped Mathpix")
        schedule_reasoning(session_id, page)
        return

    try:
        _get_credentials()
    except RuntimeError:
        # No Mathpix credentials — still trigger reasoning
        schedule_reasoning(session_id, page)
        return

    pool = get_pool()
    if not pool:
        return

    try:
        # 1. Fetch all draw/erase events and resolve visibility
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                """
                SELECT id, strokes, event_type
                FROM stroke_logs
                WHERE session_id = $1 AND page = $2 AND event_type IN ('draw', 'erase')
                ORDER BY received_at
                """,
                session_id, page,
            )

        visible_rows: list[dict] = []
        for row in rows:
            if row["event_type"] == "erase":
                visible_rows = [dict(row)]
            else:
                visible_rows.append(dict(row))

        # 2. Collect all visible strokes
        all_x: list[list[float]] = []
        all_y: list[list[float]] = []
        stroke_count = 0
        hash_parts: list[str] = []

        for row in visible_rows:
            strokes_data = row["strokes"]
            if isinstance(strokes_data, str):
                strokes_data = json.loads(strokes_data)

            for stroke in strokes_data:
                pts = stroke.get("points", [])
                if pts:
                    xs = [p["x"] for p in pts]
                    ys = [p["y"] for p in pts]
                    all_x.append(xs)
                    all_y.append(ys)
                    stroke_count += 1
                    # Include in hash: log_id + stroke points for uniqueness
                    hash_parts.append(f"{row['id']}:{json.dumps(pts, sort_keys=True)}")

        if not all_x:
            print(f"[mathpix] ({session_id}, page={page}): no visible strokes, skipping")
            schedule_reasoning(session_id, page)
            return

        # 3. Hash visible stroke set — skip if unchanged
        stroke_hash = hashlib.sha256("\n".join(hash_parts).encode()).hexdigest()
        key = (session_id, page)
        if _last_stroke_hash.get(key) == stroke_hash:
            print(f"[mathpix] ({session_id}, page={page}): strokes unchanged, skipping Mathpix call")
            schedule_reasoning(session_id, page)
            return
        _last_stroke_hash[key] = stroke_hash

        # 4. Send all strokes to Mathpix in one request
        session = await get_or_create_session(session_id, page)

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{MATHPIX_BASE}/v3/strokes",
                headers={
                    "app_token": session.app_token,
                    "Content-Type": "application/json",
                },
                json={
                    "strokes_session_id": session.strokes_session_id,
                    "strokes": {"strokes": {"x": all_x, "y": all_y}},
                    "include_smiles": True,
                    "include_geometry_data": True,
                    "include_line_data": True,
                },
            )
            resp.raise_for_status()
            result = resp.json()

        # 5. Parse response
        latex = result.get("latex_styled", "") or result.get("text", "")
        raw_line_data = result.get("line_data")
        confidence = result.get("confidence", 0.0)
        if isinstance(confidence, str):
            confidence = float(confidence)
        has_error = "error" in result
        is_handwritten = result.get("is_handwritten", True)

        # Determine content_type from line_data
        content_type = "math"
        if raw_line_data and len(raw_line_data) > 0:
            first_line = raw_line_data[0]
            line_type = first_line.get("type", "")
            subtype = first_line.get("subtype", "")
            if line_type == "diagram" and subtype.startswith("chemistry"):
                content_type = "chemistry"
            elif line_type == "diagram":
                content_type = "other"

        # Diagram detection: error, low confidence, or not-handwritten → diagram
        if has_error or not is_handwritten or confidence < DIAGRAM_CONFIDENCE_THRESHOLD:
            content_type = "diagram"
            latex = ""

        text = latex

        # 6. Upsert into page_transcriptions
        line_data_json = json.dumps(raw_line_data) if raw_line_data else None
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO page_transcriptions (session_id, page, latex, text, confidence, line_data, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6::jsonb, NOW())
                ON CONFLICT (session_id, page) DO UPDATE SET
                    latex = EXCLUDED.latex,
                    text = EXCLUDED.text,
                    confidence = EXCLUDED.confidence,
                    line_data = EXCLUDED.line_data,
                    updated_at = NOW()
                """,
                session_id, page, latex, text, confidence, line_data_json,
            )

        from collections import Counter
        line_types = ""
        if raw_line_data:
            counts = Counter(ld.get("type", "unknown") for ld in raw_line_data)
            line_types = ", ".join(f"{t}={n}" for t, n in counts.most_common())
        print(
            f"[mathpix] ({session_id}, page={page}): "
            f"sent {stroke_count} strokes, "
            f"confidence={confidence:.2f}, "
            f"content_type={content_type}, "
            f"line_data=[{line_types}], "
            f"latex={latex[:80]}"
        )

        # 7. Schedule reasoning
        schedule_reasoning(session_id, page)

    except Exception as e:
        print(f"[mathpix] error for ({session_id}, page={page}): {e}")
