"""Mathpix strokes-session transcription.

Sends ALL visible strokes to Mathpix /v3/strokes on each debounced draw,
reusing the same session within its 5-min TTL (billed once per session).

Requires MATHPIX_APP_ID and MATHPIX_APP_KEY env vars.
"""

import asyncio
import hashlib
import json
import os
import time
from collections import deque
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import httpx

from lib.database import get_pool

MATHPIX_BASE = "https://api.mathpix.com"
REASONING_DEBOUNCE_SECONDS = 1.5


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

# (session_id, page) → pending delayed-speak asyncio.Task
_pending_speak: dict[tuple[str, int], asyncio.Task] = {}

# (session_id, page) → asyncio.Event set when transcription finishes
_transcription_ready: dict[tuple[str, int], asyncio.Event] = {}


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
    _transcription_ready.pop(key, None)
    d_task = _pending_speak.pop(key, None)
    if d_task:
        d_task.cancel()
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
    # Clean up transcription events for this session
    tx_keys = [k for k in _transcription_ready if k[0] == session_id]
    for key in tx_keys:
        _transcription_ready.pop(key, None)
    # Clean up pending speak tasks for this session
    speak_keys = [k for k in _pending_speak if k[0] == session_id]
    for key in speak_keys:
        d_task = _pending_speak.pop(key, None)
        if d_task:
            d_task.cancel()
    if keys_to_remove or r_keys:
        print(f"[mathpix] cleaned up {len(keys_to_remove)} session(s) for {session_id}")


# ── Reasoning debounce ────────────────────────────────────


def schedule_reasoning(session_id: str, page: int) -> None:
    """Debounce 1.5s after last pen lift, wait for transcription, then reason."""
    key = (session_id, page)
    # Cancel any pending delayed speak for this key (new strokes arrived)
    d_task = _pending_speak.pop(key, None)
    if d_task:
        d_task.cancel()
    existing = _reasoning_tasks.pop(key, None)
    if existing:
        existing.cancel()
    _reasoning_tasks[key] = asyncio.create_task(
        _debounced_reasoning(session_id, page)
    )


async def _debounced_reasoning(session_id: str, page: int) -> None:
    t_debounce_start = time.perf_counter()
    await asyncio.sleep(REASONING_DEBOUNCE_SECONDS)
    key = (session_id, page)
    # Store reference to our own task so we can detect if we've been superseded
    my_task = _reasoning_tasks.get(key)
    _reasoning_tasks.pop(key, None)
    t_debounce_end = time.perf_counter()

    # Wait for transcription to finish (should already be done after 1.5s)
    key = (session_id, page)
    event = _transcription_ready.get(key)
    t_wait_start = time.perf_counter()
    if event and not event.is_set():
        try:
            await asyncio.wait_for(event.wait(), timeout=10.0)
        except asyncio.TimeoutError:
            print(f"[reasoning] transcription wait timed out for ({session_id}, page={page})")
    t_wait_end = time.perf_counter()
    waited_for_tx = t_wait_end - t_wait_start

    try:
        from lib.reasoning import run_reasoning
        from api.reasoning import push_reasoning

        t_reasoning_start = time.perf_counter()
        result = await run_reasoning(session_id, page)
        t_reasoning_end = time.perf_counter()

        # If new strokes arrived while we were reasoning, discard the result
        new_task = _reasoning_tasks.get(key)
        if new_task is not None and new_task is not my_task:
            print(f"[reasoning] discarding stale result for ({session_id}, page={page}): new strokes arrived")
            return

        action = result["action"]
        message = result["message"]
        delay_ms = result.get("delay_ms", 0)

        t_push_start = time.perf_counter()
        if action == "speak" and delay_ms > 0:
            key = (session_id, page)
            # Cancel any existing pending speak
            existing = _pending_speak.pop(key, None)
            if existing:
                existing.cancel()
            _pending_speak[key] = asyncio.create_task(
                _fire_delayed_speak(session_id, page, message, delay_ms / 1000.0)
            )
        elif action == "speak":
            await push_reasoning(session_id, action, message)
        t_push_end = time.perf_counter()
        # silent: do nothing (already logged to DB by run_reasoning)

        wait_str = f", tx_wait={waited_for_tx:.3f}s" if waited_for_tx > 0.01 else ""
        print(
            f"[latency] reasoning pipeline ({session_id}, p={page}): "
            f"debounce={t_debounce_end - t_debounce_start:.1f}s{wait_str}, "
            f"reasoning={t_reasoning_end - t_reasoning_start:.1f}s, "
            f"push={t_push_end - t_push_start:.3f}s, "
            f"action={action}, delay={delay_ms}ms"
        )
    except Exception as e:
        print(f"[reasoning] error for ({session_id}, page={page}): {e}")


async def _fire_delayed_speak(
    session_id: str, page: int, message: str, delay_seconds: float
) -> None:
    """Wait delay_seconds then push the message as 'speak'."""
    await asyncio.sleep(delay_seconds)
    _pending_speak.pop((session_id, page), None)
    try:
        from api.reasoning import push_reasoning
        await push_reasoning(session_id, "speak", message)
        print(f"[reasoning] delayed speak fired ({delay_seconds:.1f}s) for ({session_id}, page={page}): {message[:60]}")
    except Exception as e:
        print(f"[reasoning] delayed speak error for ({session_id}, page={page}): {e}")


# ── Whole-page transcription ──────────────────────────────

# (session_id, page) → hash of visible stroke set (skip-if-unchanged)
_last_stroke_hash: dict[tuple[str, int], str] = {}

DIAGRAM_CONFIDENCE_THRESHOLD = 0.8   # below → diagram


def schedule_transcribe(session_id: str, page: int) -> None:
    """Transcribe immediately on pen lift. Cancels any in-flight transcription."""
    key = (session_id, page)
    existing = _debounce_tasks.pop(key, None)
    if existing:
        existing.cancel()
    # Reset the ready event so reasoning knows to wait
    _transcription_ready[key] = asyncio.Event()
    _debounce_tasks[key] = asyncio.create_task(
        _run_transcribe(session_id, page)
    )


def _signal_transcription_done(session_id: str, page: int) -> None:
    """Mark transcription as complete so reasoning can proceed."""
    key = (session_id, page)
    event = _transcription_ready.get(key)
    if event:
        event.set()


async def _run_transcribe(session_id: str, page: int) -> None:
    t_start = time.perf_counter()

    _debounce_tasks.pop((session_id, page), None)

    # Diagram mode: skip Mathpix, upsert empty transcription
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
        _signal_transcription_done(session_id, page)
        return

    # Erase snapshot: if most recent stroke event is an erase, capture pre-erase text
    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            last_event = await conn.fetch(
                """
                SELECT event_type FROM stroke_logs
                WHERE session_id = $1 AND page = $2 AND event_type IN ('draw', 'erase')
                ORDER BY received_at DESC LIMIT 1
                """,
                session_id, page,
            )
            if last_event and last_event[0]["event_type"] == "erase":
                tx_row = await conn.fetchrow(
                    "SELECT text FROM page_transcriptions WHERE session_id = $1 AND page = $2",
                    session_id, page,
                )
                if tx_row and tx_row["text"]:
                    key = (session_id, page)
                    if key not in _erase_snapshots:
                        _erase_snapshots[key] = deque(maxlen=3)
                    _erase_snapshots[key].append(tx_row["text"])
                    print(f"[mathpix] ({session_id}, page={page}): captured pre-erase snapshot")

    try:
        _get_credentials()
    except RuntimeError:
        # No Mathpix credentials — signal done so reasoning can proceed
        _signal_transcription_done(session_id, page)
        return

    pool = get_pool()
    if not pool:
        _signal_transcription_done(session_id, page)
        return

    try:
        # 1. Fetch all draw/erase events and resolve visibility
        t_fetch_strokes = time.perf_counter()
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
            _signal_transcription_done(session_id, page)
            return

        # 3. Hash visible stroke set — skip if unchanged
        stroke_hash = hashlib.sha256("\n".join(hash_parts).encode()).hexdigest()
        key = (session_id, page)
        t_after_hash = time.perf_counter()
        if _last_stroke_hash.get(key) == stroke_hash:
            print(
                f"[mathpix] ({session_id}, page={page}): strokes unchanged, skipping Mathpix call "
                f"(fetch+hash={t_after_hash - t_fetch_strokes:.3f}s)"
            )
            _signal_transcription_done(session_id, page)
            return
        _last_stroke_hash[key] = stroke_hash

        # 4. Send all strokes to Mathpix in one request
        t_mathpix_start = time.perf_counter()
        session = await get_or_create_session(session_id, page)
        t_session = time.perf_counter()

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
        t_mathpix_end = time.perf_counter()

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
        t_upsert_start = time.perf_counter()
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
        t_upsert_end = time.perf_counter()

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
        print(
            f"[latency] transcribe ({session_id}, p={page}): "
            f"fetch+hash={t_after_hash - t_fetch_strokes:.3f}s, "
            f"mathpix_session={t_session - t_mathpix_start:.3f}s, "
            f"mathpix_api={t_mathpix_end - t_session:.3f}s, "
            f"db_upsert={t_upsert_end - t_upsert_start:.3f}s, "
            f"total={t_upsert_end - t_start:.3f}s"
        )

    except Exception as e:
        print(f"[mathpix] error for ({session_id}, page={page}): {e}")
    finally:
        _signal_transcription_done(session_id, page)
