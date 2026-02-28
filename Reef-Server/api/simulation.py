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
import lib.reasoning as reasoning_module
from lib.reasoning import run_reasoning, run_question_reasoning
from api.strokes import _active_sessions

router = APIRouter(prefix="/api/simulation", tags=["simulation"])

# session_id -> {"document_id": int}
_simulation_sessions: dict[str, dict] = {}


class ModelOverrideRequest(BaseModel):
    model_id: str | None = None  # None to clear override
    structured_output: bool = False  # Use JSON schema instead of punctuation parsing


@router.post("/set-model")
async def simulation_set_model(req: ModelOverrideRequest):
    """Override the reasoning model at runtime (dev-only, for benchmarking)."""
    reasoning_module._model_override = req.model_id
    reasoning_module._use_structured_output = req.structured_output
    active = req.model_id or reasoning_module.REASONING_MODEL
    print(f"[simulation] Model override: {active}, structured_output={req.structured_output}")
    return {"model": active, "is_override": req.model_id is not None, "structured_output": req.structured_output}


# -- Request/Response models --------------------------------------------------

class AnswerKeyEntry(BaseModel):
    part_label: str | None = None
    answer: str


class PartEntry(BaseModel):
    label: str
    text: str


class StartRequest(BaseModel):
    problem_text: str
    answer_key: list[AnswerKeyEntry]
    parts: list[PartEntry] = []
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

@router.get("/sessions")
async def simulation_sessions():
    """List active simulation sessions with problem metadata."""
    pool = get_pool()
    if not pool:
        return {"sessions": []}

    sessions = []
    for session_id, data in _simulation_sessions.items():
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                SELECT q.text AS problem_text, q.label,
                       json_agg(json_build_object('part_label', ak.part_label, 'answer', ak.answer)) AS answer_key
                FROM questions q
                JOIN documents d ON q.document_id = d.id
                LEFT JOIN answer_keys ak ON ak.question_id = q.id
                WHERE d.id = $1
                GROUP BY q.id
                """,
                data["document_id"],
            )
        if row:
            sessions.append({
                "session_id": session_id,
                "problem_text": row["problem_text"],
                "label": row["label"],
                "answer_key": json.loads(row["answer_key"]) if isinstance(row["answer_key"], str) else row["answer_key"],
            })

    return {"sessions": sessions}


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

        parts_json = json.dumps([{"label": p.label, "text": p.text} for p in req.parts]) if req.parts else "[]"
        question_id = await conn.fetchval(
            """
            INSERT INTO questions (document_id, number, label, text, parts)
            VALUES ($1, $2, $3, $4, $5::jsonb) RETURNING id
            """,
            document_id,
            req.question_number,
            req.label,
            req.problem_text,
            parts_json,
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
        "active_part": None,
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
