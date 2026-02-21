"""
REST endpoints for stroke logging.

iOS sends debounced stroke data via POST; server logs
each batch to the stroke_logs table in Postgres.
"""

import json
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from lib.database import get_pool
from lib.mathpix_client import (
    cleanup_sessions,
    get_session_info,
    invalidate_session,
    schedule_transcribe,
)

router = APIRouter()

# session_id → {document_name, question_number, last_seen}
_active_sessions: dict[str, dict] = {}


# ── Pydantic request models ────────────────────────────────

class ConnectRequest(BaseModel):
    session_id: str
    user_id: str = ""
    document_name: Optional[str] = None
    question_number: Optional[int] = None


class DisconnectRequest(BaseModel):
    session_id: str


class StrokesRequest(BaseModel):
    session_id: str
    user_id: str = ""
    page: int = 1
    strokes: list = []
    event_type: str = "draw"
    deleted_count: int = 0
    part_label: Optional[str] = None
    content_mode: Optional[str] = None


class ClearRequest(BaseModel):
    session_id: str
    page: int = 1


# ── REST endpoints ──────────────────────────────────────────

@router.post("/api/strokes/connect")
async def strokes_connect(req: ConnectRequest):
    # Evict stale session metadata (e.g. question-switch sessions)
    # Only remove from _active_sessions — don't destroy Mathpix page
    # sessions, which need to persist for incremental transcription
    stale = [sid for sid in _active_sessions if sid != req.session_id]
    for sid in stale:
        _active_sessions.pop(sid, None)

    _active_sessions[req.session_id] = {
        "document_name": req.document_name or "",
        "question_number": req.question_number,
        "last_seen": datetime.now(timezone.utc).isoformat(),
        "active_part": None,
        "content_mode": "math",
    }
    print(f"[strokes] session {req.session_id} connected (doc={req.document_name!r}, q={req.question_number}, evicted {len(stale)} stale)")

    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO stroke_logs (session_id, page, strokes, event_type, message, user_id)
                VALUES ($1, 0, '[]'::jsonb, 'system', $2, $3)
                """,
                req.session_id,
                "session started",
                req.user_id,
            )

    return {"status": "connected"}


@router.post("/api/strokes/disconnect")
async def strokes_disconnect(req: DisconnectRequest):
    _active_sessions.pop(req.session_id, None)
    cleanup_sessions(req.session_id)
    print(f"[strokes] session {req.session_id} disconnected")
    return {"status": "disconnected"}


@router.post("/api/strokes")
async def strokes_post(req: StrokesRequest):
    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO stroke_logs (session_id, page, strokes, event_type, deleted_count, user_id)
            VALUES ($1, $2, $3::jsonb, $4, $5, $6)
            """,
            req.session_id,
            req.page,
            json.dumps(req.strokes),
            req.event_type,
            req.deleted_count,
            req.user_id,
        )

    # Whole-page transcription (debounced)
    if req.event_type in ("draw", "erase"):
        schedule_transcribe(req.session_id, req.page)

    # Update last_seen and active part
    if req.session_id in _active_sessions:
        _active_sessions[req.session_id]["last_seen"] = datetime.now(timezone.utc).isoformat()
        if req.part_label is not None:
            _active_sessions[req.session_id]["active_part"] = req.part_label
        if req.content_mode is not None:
            _active_sessions[req.session_id]["content_mode"] = req.content_mode

    return {"status": "ok"}


@router.post("/api/strokes/clear")
async def strokes_clear(req: ClearRequest):
    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    async with pool.acquire() as conn:
        await conn.execute(
            "DELETE FROM stroke_logs WHERE session_id = $1 AND page = $2",
            req.session_id,
            req.page,
        )
        await conn.execute(
            "DELETE FROM page_transcriptions WHERE session_id = $1 AND page = $2",
            req.session_id,
            req.page,
        )
        await conn.execute(
            "DELETE FROM reasoning_logs WHERE session_id = $1 AND page = $2",
            req.session_id,
            req.page,
        )

    invalidate_session(req.session_id, req.page)
    return {"status": "ok"}


# ── Existing GET / DELETE endpoints ─────────────────────────

@router.get("/api/stroke-logs")
async def get_stroke_logs(
    limit: int = Query(default=50, ge=1, le=200),
    session_id: Optional[str] = Query(default=None),
    page: Optional[int] = Query(default=None),
):
    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    async with pool.acquire() as conn:
        # Build query with optional filters
        conditions = []
        params = []
        idx = 1

        if session_id:
            conditions.append(f"session_id = ${idx}")
            params.append(session_id)
            idx += 1

        if page is not None:
            conditions.append(f"page = ${idx}")
            params.append(page)
            idx += 1

        where = f"WHERE {' AND '.join(conditions)}" if conditions else ""

        total = await conn.fetchval(
            f"SELECT COUNT(*) FROM stroke_logs {where}", *params
        )

        rows = await conn.fetch(
            f"""
            SELECT id, session_id, page, received_at,
                   jsonb_array_length(strokes) AS stroke_count,
                   strokes, event_type, deleted_count, message, user_id
            FROM stroke_logs
            {where}
            ORDER BY received_at DESC
            LIMIT ${idx}
            """,
            *params,
            limit,
        )

    # Look up document_name and question label from active session
    active_doc_name = ""
    matched_question_label = ""
    # Fall back to any active session if no session_id query param
    lookup_sid = session_id
    if not lookup_sid and _active_sessions:
        lookup_sid = max(_active_sessions, key=lambda s: _active_sessions[s].get("last_seen", ""))
    if lookup_sid and lookup_sid in _active_sessions:
        info = _active_sessions[lookup_sid]
        active_doc_name = info.get("document_name", "")
        qn = info.get("question_number")
        if qn is not None:
            matched_question_label = f"Q{qn}"

    return {
        "logs": [
            {
                "id": r["id"],
                "session_id": r["session_id"],
                "page": r["page"],
                "received_at": r["received_at"].isoformat(),
                "stroke_count": r["stroke_count"],
                "strokes": json.loads(r["strokes"]),
                "event_type": r["event_type"],
                "deleted_count": r["deleted_count"],
                "message": r["message"],
                "user_id": r["user_id"],
            }
            for r in rows
        ],
        "total": total,
        "active_connections": len(_active_sessions),
        "active_sessions": sorted(
            _active_sessions.keys(),
            key=lambda sid: _active_sessions[sid].get("last_seen", ""),
        ),
        "document_name": active_doc_name,
        "question_number": _active_sessions.get(lookup_sid, {}).get("question_number") if lookup_sid else None,
        "matched_question_label": matched_question_label,
        "mathpix_session": get_session_info(session_id, page or 1) if session_id else None,
    }


@router.delete("/api/stroke-logs")
async def clear_stroke_logs(
    session_id: Optional[str] = Query(default=None),
):
    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    async with pool.acquire() as conn:
        if session_id:
            result = await conn.execute(
                "DELETE FROM stroke_logs WHERE session_id = $1", session_id
            )
            await conn.execute(
                "DELETE FROM page_transcriptions WHERE session_id = $1", session_id
            )
            await conn.execute(
                "DELETE FROM reasoning_logs WHERE session_id = $1", session_id
            )
        else:
            result = await conn.execute("DELETE FROM stroke_logs")
            await conn.execute("DELETE FROM page_transcriptions")
            await conn.execute("DELETE FROM reasoning_logs")

    count = int(result.split()[-1])
    return {"deleted": count}


@router.get("/api/reasoning-logs")
async def get_reasoning_logs(
    session_id: str = Query(...),
    limit: int = Query(default=50, ge=1, le=200),
):
    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, session_id, page, created_at, action, message,
                   prompt_tokens, completion_tokens, estimated_cost,
                   source, question_text
            FROM reasoning_logs
            WHERE session_id = $1
            ORDER BY created_at DESC
            LIMIT $2
            """,
            session_id,
            limit,
        )
        usage_row = await conn.fetchrow(
            """
            SELECT COUNT(*) AS calls,
                   COALESCE(SUM(prompt_tokens), 0) AS prompt_tokens,
                   COALESCE(SUM(completion_tokens), 0) AS completion_tokens,
                   COALESCE(SUM(estimated_cost), 0) AS estimated_cost
            FROM reasoning_logs
            WHERE session_id = $1
            """,
            session_id,
        )

    return {
        "logs": [
            {
                "id": r["id"],
                "session_id": r["session_id"],
                "page": r["page"],
                "created_at": r["created_at"].isoformat(),
                "action": r["action"],
                "message": r["message"],
                "prompt_tokens": r["prompt_tokens"],
                "completion_tokens": r["completion_tokens"],
                "estimated_cost": float(r["estimated_cost"]),
                "source": r["source"],
                "question_text": r["question_text"],
            }
            for r in rows
        ],
        "usage": {
            "calls": usage_row["calls"],
            "prompt_tokens": usage_row["prompt_tokens"],
            "completion_tokens": usage_row["completion_tokens"],
            "estimated_cost": float(usage_row["estimated_cost"]),
        } if usage_row else None,
    }


@router.get("/api/page-transcription")
async def get_page_transcription(
    session_id: str = Query(...),
    page: int = Query(default=1),
):
    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT latex, text, confidence, line_data, updated_at
            FROM page_transcriptions
            WHERE session_id = $1 AND page = $2
            """,
            session_id,
            page,
        )

    if not row:
        return {"latex": "", "text": "", "confidence": 0, "line_data": None, "updated_at": None}

    line_data = row["line_data"]
    if isinstance(line_data, str):
        line_data = json.loads(line_data)

    return {
        "latex": row["latex"],
        "text": row["text"],
        "confidence": row["confidence"],
        "line_data": line_data,
        "updated_at": row["updated_at"].isoformat() if row["updated_at"] else None,
    }


@router.get("/api/reasoning-preview")
async def get_reasoning_preview(
    session_id: str = Query(...),
    page: int = Query(default=1),
):
    from lib.reasoning import SYSTEM_PROMPT, build_context_structured
    sections = await build_context_structured(session_id, page)
    return {
        "system_prompt": SYSTEM_PROMPT,
        "sections": sections,
    }
