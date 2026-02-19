"""Simulation endpoints for testing the tutor without an iPad.

Dev-only (ENVIRONMENT=development). Lets Claude Code act as a student:
set up a problem, write work step by step, ask questions, and observe
the tutor's responses. Bypasses Mathpix transcription and debounce.
"""

import json
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from lib.database import get_pool
from lib.reasoning import run_reasoning, run_question_reasoning
from api.strokes import _active_sessions

router = APIRouter(prefix="/api/simulation", tags=["simulation"])

# session_id -> {"document_id": int}
_simulation_sessions: dict[str, dict] = {}


# -- Request/Response models --------------------------------------------------

class AnswerKeyEntry(BaseModel):
    part_label: str | None = None
    answer: str


class StartRequest(BaseModel):
    problem_text: str
    answer_key: list[AnswerKeyEntry]
    label: str = "Problem 1"
    question_number: int = 1
    subject: str = "math"


class WriteRequest(BaseModel):
    session_id: str
    transcription: str


class AskRequest(BaseModel):
    session_id: str
    question: str


class ResetRequest(BaseModel):
    session_id: str


# -- Endpoints -----------------------------------------------------------------

@router.post("/start")
async def simulation_start(req: StartRequest):
    """Set up a simulation session with a problem and answer key."""
    pool = get_pool()
    if not pool:
        raise HTTPException(status_code=503, detail="Database not available")

    session_id = f"sim_{uuid.uuid4().hex[:12]}"
    doc_filename = f"sim_{session_id}"

    async with pool.acquire() as conn:
        document_id = await conn.fetchval(
            """
            INSERT INTO documents (filename, page_count, total_problems)
            VALUES ($1, 1, 1) RETURNING id
            """,
            doc_filename,
        )

        question_id = await conn.fetchval(
            """
            INSERT INTO questions (document_id, number, label, text)
            VALUES ($1, $2, $3, $4) RETURNING id
            """,
            document_id,
            req.question_number,
            req.label,
            req.problem_text,
        )

        for ak in req.answer_key:
            await conn.execute(
                """
                INSERT INTO answer_keys (question_id, part_label, answer)
                VALUES ($1, $2, $3)
                """,
                question_id,
                ak.part_label,
                ak.answer,
            )

    # Register in _active_sessions so build_context() finds the question
    _active_sessions[session_id] = {
        "document_name": doc_filename,
        "question_number": req.question_number,
        "last_seen": datetime.now(timezone.utc).isoformat(),
    }

    _simulation_sessions[session_id] = {"document_id": document_id}

    print(f"[simulation] Started session {session_id} (doc={document_id}, q={req.question_number})")
    return {"session_id": session_id, "status": "ready"}


@router.post("/write")
async def simulation_write(req: WriteRequest):
    """Write student work (bypasses Mathpix) and run reasoning."""
    if req.session_id not in _simulation_sessions:
        raise HTTPException(status_code=404, detail=f"Unknown session: {req.session_id}")

    pool = get_pool()
    if not pool:
        raise HTTPException(status_code=503, detail="Database not available")

    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO page_transcriptions (session_id, page, text, latex, confidence)
            VALUES ($1, 1, $2, $3, 1.0)
            ON CONFLICT (session_id, page)
            DO UPDATE SET text = $2, latex = $3, confidence = 1.0, updated_at = NOW()
            """,
            req.session_id,
            req.transcription,
            req.transcription,
        )

    result = await run_reasoning(req.session_id, page=1)
    return result


@router.post("/ask")
async def simulation_ask(req: AskRequest):
    """Simulate a voice question from the student."""
    if req.session_id not in _simulation_sessions:
        raise HTTPException(status_code=404, detail=f"Unknown session: {req.session_id}")

    result = await run_question_reasoning(req.session_id, page=1, question=req.question)
    return result


@router.post("/reset")
async def simulation_reset(req: ResetRequest):
    """Clean up all DB data for a simulation session."""
    session_data = _simulation_sessions.pop(req.session_id, None)
    if not session_data:
        raise HTTPException(status_code=404, detail=f"Unknown session: {req.session_id}")

    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            await conn.execute(
                "DELETE FROM stroke_logs WHERE session_id = $1", req.session_id
            )
            await conn.execute(
                "DELETE FROM page_transcriptions WHERE session_id = $1", req.session_id
            )
            await conn.execute(
                "DELETE FROM reasoning_logs WHERE session_id = $1", req.session_id
            )
            await conn.execute(
                "DELETE FROM documents WHERE id = $1", session_data["document_id"]
            )

    _active_sessions.pop(req.session_id, None)

    print(f"[simulation] Reset session {req.session_id}")
    return {"status": "cleaned up"}
