"""
End-to-end tests for instant question metadata via WebSocket query params.

Tests that:
1. Connecting with document_name + question_number immediately resolves question_id
2. GET /api/stroke-logs returns correct question label/document instantly
3. Switching questions (new WebSocket) immediately shows the new question
4. Disconnecting clears the metadata (no stale data)
5. Fallback: connecting without metadata still works via trigram matching

Run against a live server:
    uv run python -m pytest tests/test_question_switching.py -v -s
"""

import asyncio
import json
import uuid

import httpx
import pytest
import websockets

BASE_URL = "http://localhost:8000"
WS_URL = "ws://localhost:8000"

# Test data — must match what's in the DB
DOC_NAME = "document.pdf"       # iOS sends with extension
DOC_STEM = "document"           # DB stores without extension
Q1_NUMBER = 1
Q2_NUMBER = 2


def new_session_id() -> str:
    return str(uuid.uuid4())


async def connect_ws(session_id: str, document_name: str = "", question_number: int | None = None):
    """Connect to stroke WebSocket with optional question metadata."""
    params = f"session_id={session_id}&user_id=test"
    if document_name:
        params += f"&document_name={document_name}"
    if question_number is not None:
        params += f"&question_number={question_number}"
    ws = await websockets.connect(f"{WS_URL}/ws/strokes?{params}")
    return ws


async def get_stroke_logs(session_id: str) -> dict:
    """Poll GET /api/stroke-logs for a session."""
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{BASE_URL}/api/stroke-logs", params={"session_id": session_id})
        resp.raise_for_status()
        return resp.json()


async def cleanup_session(session_id: str):
    """Delete all stroke logs for a test session."""
    async with httpx.AsyncClient() as client:
        await client.delete(f"{BASE_URL}/api/stroke-logs", params={"session_id": session_id})


@pytest.mark.asyncio
async def test_instant_question_metadata():
    """Connecting with document_name + question_number should immediately
    make GET return the correct matched_question_label and document_name."""
    sid = new_session_id()
    try:
        ws = await connect_ws(sid, document_name=DOC_NAME, question_number=Q1_NUMBER)

        # Give server a moment to process the connection
        await asyncio.sleep(0.3)

        data = await get_stroke_logs(sid)
        print(f"\n  matched_question_label: {data['matched_question_label']!r}")
        print(f"  document_name: {data['document_name']!r}")

        assert data["matched_question_label"] == "Problem 1", \
            f"Expected 'Problem 1', got {data['matched_question_label']!r}"
        assert data["document_name"] == DOC_NAME, \
            f"Expected {DOC_NAME!r}, got {data['document_name']!r}"

        await ws.close()
    finally:
        await cleanup_session(sid)


@pytest.mark.asyncio
async def test_question_switching():
    """Switching from Q1 to Q2 should instantly show Q2 metadata, not Q1."""
    sid1 = new_session_id()
    sid2 = new_session_id()
    try:
        # Connect to Q1
        ws1 = await connect_ws(sid1, document_name=DOC_NAME, question_number=Q1_NUMBER)
        await asyncio.sleep(0.3)

        data1 = await get_stroke_logs(sid1)
        assert data1["matched_question_label"] == "Problem 1"
        print(f"\n  Q1 session: label={data1['matched_question_label']!r}")

        # "Switch" — close Q1, open Q2 (simulates iOS swiping to next question)
        await ws1.close()
        await asyncio.sleep(0.2)

        ws2 = await connect_ws(sid2, document_name=DOC_NAME, question_number=Q2_NUMBER)
        await asyncio.sleep(0.3)

        data2 = await get_stroke_logs(sid2)
        print(f"  Q2 session: label={data2['matched_question_label']!r}")

        assert data2["matched_question_label"] == "Problem 2", \
            f"Expected 'Problem 2', got {data2['matched_question_label']!r}"

        # Also verify Q1 session no longer shows in active sessions
        # (its WebSocket is closed)
        assert sid1 not in data2.get("active_sessions", []), \
            f"Stale session {sid1} still in active_sessions"

        await ws2.close()
    finally:
        await cleanup_session(sid1)
        await cleanup_session(sid2)


@pytest.mark.asyncio
async def test_disconnect_clears_metadata():
    """After WebSocket disconnect, GET should not return stale question metadata
    from _active_sessions (should fall back to trigram/cache matching)."""
    sid = new_session_id()
    try:
        ws = await connect_ws(sid, document_name=DOC_NAME, question_number=Q1_NUMBER)
        await asyncio.sleep(0.3)

        # Verify metadata is there while connected
        data = await get_stroke_logs(sid)
        assert data["matched_question_label"] == "Problem 1"

        # Disconnect
        await ws.close()
        await asyncio.sleep(0.3)

        # After disconnect, no active WebSocket — should not have question label
        # (no strokes written, so trigram matching has nothing to match)
        data = await get_stroke_logs(sid)
        print(f"\n  After disconnect: label={data['matched_question_label']!r}")

        # The label should be empty since there's no active WS and no canvas text
        assert data["matched_question_label"] == "", \
            f"Expected empty label after disconnect, got {data['matched_question_label']!r}"

    finally:
        await cleanup_session(sid)


@pytest.mark.asyncio
async def test_no_metadata_still_works():
    """Connecting without document_name/question_number should still work
    (no question metadata, but WebSocket functions normally)."""
    sid = new_session_id()
    try:
        ws = await connect_ws(sid)  # No document_name or question_number
        await asyncio.sleep(0.3)

        data = await get_stroke_logs(sid)
        print(f"\n  No metadata: label={data['matched_question_label']!r}")

        # Should have no question label (no metadata provided, no canvas text)
        assert data["matched_question_label"] == ""
        # But session should be active
        assert sid in data["active_sessions"]

        await ws.close()
    finally:
        await cleanup_session(sid)


@pytest.mark.asyncio
async def test_rapid_switching():
    """Rapidly switching between 3 questions should always show the latest one."""
    sessions = [new_session_id() for _ in range(3)]
    questions = [1, 5, 10]
    expected_labels = ["Problem 1", "Problem 5", "Problem 10"]

    try:
        for i, (sid, qnum, expected) in enumerate(zip(sessions, questions, expected_labels)):
            ws = await connect_ws(sid, document_name=DOC_NAME, question_number=qnum)
            await asyncio.sleep(0.2)

            data = await get_stroke_logs(sid)
            label = data["matched_question_label"]
            print(f"\n  Rapid switch {i+1}: Q{qnum} -> label={label!r}")

            assert label == expected, \
                f"Switch {i+1}: expected {expected!r}, got {label!r}"

            await ws.close()
            await asyncio.sleep(0.1)
    finally:
        for sid in sessions:
            await cleanup_session(sid)
