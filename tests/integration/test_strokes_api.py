"""Integration tests for api/strokes.py — real DB stroke lifecycle via TestClient."""

import json
import uuid

import pytest

from api.strokes import _active_sessions


def _sid() -> str:
    """Generate a unique session ID for test isolation."""
    return f"test_{uuid.uuid4().hex[:12]}"


class TestConnect:
    def test_connect_inserts_system_event(self, client):
        sid = _sid()
        resp = client.post("/api/strokes/connect", json={"session_id": sid})
        assert resp.status_code == 200

        # GET stroke-logs for this session should show the system event
        resp = client.get(f"/api/stroke-logs?session_id={sid}")
        assert resp.status_code == 200
        logs = resp.json()["logs"]
        assert len(logs) == 1
        assert logs[0]["event_type"] == "system"
        assert logs[0]["message"] == "session started"

    def test_connect_with_metadata(self, client):
        sid = _sid()
        resp = client.post("/api/strokes/connect", json={
            "session_id": sid,
            "document_name": "homework.pdf",
            "question_number": 3,
        })
        assert resp.status_code == 200
        assert sid in _active_sessions
        assert _active_sessions[sid]["document_name"] == "homework.pdf"
        assert _active_sessions[sid]["question_number"] == 3

        # stroke-logs response includes metadata from active session
        resp = client.get(f"/api/stroke-logs?session_id={sid}")
        data = resp.json()
        assert data["document_name"] == "homework.pdf"
        assert data["question_number"] == 3

    def test_second_connect_evicts_first(self, client):
        sid1 = _sid()
        sid2 = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid1})
        assert sid1 in _active_sessions

        client.post("/api/strokes/connect", json={"session_id": sid2})
        assert sid2 in _active_sessions
        assert sid1 not in _active_sessions


class TestPartLabel:
    def test_part_label_stored_in_active_sessions(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})
        assert _active_sessions[sid]["active_part"] is None

        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
            "event_type": "draw",
            "part_label": "b",
        })
        assert _active_sessions[sid]["active_part"] == "b"

    def test_part_label_omitted_backward_compatible(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})

        # Send strokes without part_label
        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
            "event_type": "draw",
        })
        # active_part should remain None
        assert _active_sessions[sid]["active_part"] is None

    def test_part_label_not_overwritten_by_none(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})

        # Set part_label to "a"
        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
            "part_label": "a",
        })
        assert _active_sessions[sid]["active_part"] == "a"

        # Send without part_label — should keep "a"
        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [3], "y": [4]}],
        })
        assert _active_sessions[sid]["active_part"] == "a"


class TestPostStrokes:
    def test_post_strokes_persists_in_db(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})

        strokes = [{"x": [1, 2], "y": [3, 4]}]
        resp = client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": strokes,
            "event_type": "draw",
        })
        assert resp.status_code == 200

        # GET stroke-logs — should have system + draw events
        resp = client.get(f"/api/stroke-logs?session_id={sid}")
        logs = resp.json()["logs"]
        draw_logs = [l for l in logs if l["event_type"] == "draw"]
        assert len(draw_logs) == 1
        assert draw_logs[0]["stroke_count"] == 1
        assert draw_logs[0]["strokes"] == strokes


class TestClear:
    def test_clear_removes_session_logs(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})
        client.post("/api/strokes", json={
            "session_id": sid, "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
        })

        resp = client.post("/api/strokes/clear", json={"session_id": sid, "page": 1})
        assert resp.status_code == 200

        # stroke-logs for page 1 should be empty (connect was page 0, clear deletes page 1)
        resp = client.get(f"/api/stroke-logs?session_id={sid}&page=1")
        assert resp.json()["total"] == 0


class TestDisconnect:
    def test_disconnect_removes_session(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})
        assert sid in _active_sessions

        resp = client.post("/api/strokes/disconnect", json={"session_id": sid})
        assert resp.status_code == 200
        assert sid not in _active_sessions


# ── Helper to create a session with strokes ─────────────────


def _setup_session(client, sid: str, page: int = 1, strokes=None):
    """Connect + post strokes for a session. Returns the session_id."""
    client.post("/api/strokes/connect", json={"session_id": sid})
    if strokes is None:
        strokes = [{"x": [1, 2], "y": [3, 4]}]
    client.post("/api/strokes", json={
        "session_id": sid,
        "page": page,
        "strokes": strokes,
        "event_type": "draw",
    })
    return sid


# ── GET /api/stroke-logs filtering ──────────────────────────


class TestGetStrokeLogs:
    def test_filter_by_session_id(self, client):
        sid1 = _sid()
        sid2 = _sid()
        _setup_session(client, sid1)
        _setup_session(client, sid2)

        resp = client.get(f"/api/stroke-logs?session_id={sid1}")
        data = resp.json()
        # system + draw for sid1 only
        assert all(log["session_id"] == sid1 for log in data["logs"])
        assert data["total"] == 2  # connect system event + draw

    def test_filter_by_page(self, client):
        sid = _sid()
        _setup_session(client, sid, page=1)
        _setup_session(client, sid, page=2)

        resp = client.get(f"/api/stroke-logs?session_id={sid}&page=1")
        data = resp.json()
        assert all(log["page"] == 1 for log in data["logs"])

    def test_limit_param(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})
        for _ in range(3):
            client.post("/api/strokes", json={
                "session_id": sid, "page": 1,
                "strokes": [{"x": [1], "y": [2]}],
                "event_type": "draw",
            })

        resp = client.get(f"/api/stroke-logs?session_id={sid}&limit=2")
        data = resp.json()
        assert len(data["logs"]) == 2
        assert data["total"] == 4  # 1 system + 3 draw

    def test_empty_session(self, client):
        resp = client.get(f"/api/stroke-logs?session_id=nonexistent_{uuid.uuid4().hex[:8]}")
        data = resp.json()
        assert data["total"] == 0
        assert data["logs"] == []


# ── DELETE /api/stroke-logs ──────────────────────────────────


class TestDeleteStrokeLogs:
    def test_delete_by_session_id(self, client):
        sid1 = _sid()
        sid2 = _sid()
        _setup_session(client, sid1)
        _setup_session(client, sid2)

        resp = client.delete(f"/api/stroke-logs?session_id={sid1}")
        assert resp.status_code == 200

        # sid1 gone
        resp = client.get(f"/api/stroke-logs?session_id={sid1}")
        assert resp.json()["total"] == 0

        # sid2 survives
        resp = client.get(f"/api/stroke-logs?session_id={sid2}")
        assert resp.json()["total"] > 0

    def test_delete_all(self, client):
        _setup_session(client, _sid())
        _setup_session(client, _sid())

        resp = client.delete("/api/stroke-logs")
        assert resp.status_code == 200
        assert resp.json()["deleted"] > 0

        resp = client.get("/api/stroke-logs")
        assert resp.json()["total"] == 0

    @pytest.mark.anyio
    async def test_cascades_page_transcriptions(self, client, db):
        sid = _sid()
        _setup_session(client, sid)

        await db.execute(
            """INSERT INTO page_transcriptions (session_id, page, latex, text, confidence)
               VALUES ($1, 1, '\\\\frac{1}{2}', 'one half', 0.95)""",
            sid,
        )

        client.delete(f"/api/stroke-logs?session_id={sid}")

        count = await db.fetchval(
            "SELECT COUNT(*) FROM page_transcriptions WHERE session_id = $1", sid
        )
        assert count == 0

    @pytest.mark.anyio
    async def test_cascades_reasoning_logs(self, client, db):
        sid = _sid()
        _setup_session(client, sid)

        await db.execute(
            """INSERT INTO reasoning_logs (session_id, page, action, message, prompt_tokens, completion_tokens, estimated_cost)
               VALUES ($1, 1, 'speak', 'hello', 100, 50, 0.001)""",
            sid,
        )

        client.delete(f"/api/stroke-logs?session_id={sid}")

        count = await db.fetchval(
            "SELECT COUNT(*) FROM reasoning_logs WHERE session_id = $1", sid
        )
        assert count == 0

    def test_returns_count(self, client):
        sid = _sid()
        _setup_session(client, sid)

        # Should have 2 rows: system + draw
        resp = client.delete(f"/api/stroke-logs?session_id={sid}")
        assert resp.json()["deleted"] == 2


# ── GET /api/reasoning-logs ──────────────────────────────────


class TestGetReasoningLogs:
    def test_empty_session(self, client):
        sid = _sid()
        resp = client.get(f"/api/reasoning-logs?session_id={sid}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["logs"] == []
        assert data["usage"]["calls"] == 0

    @pytest.mark.anyio
    async def test_returns_inserted_logs(self, client, db):
        sid = _sid()
        await db.execute(
            """INSERT INTO reasoning_logs (session_id, page, action, message, prompt_tokens, completion_tokens, estimated_cost)
               VALUES ($1, 1, 'speak', 'Try factoring', 200, 100, 0.002)""",
            sid,
        )

        resp = client.get(f"/api/reasoning-logs?session_id={sid}")
        data = resp.json()
        assert len(data["logs"]) == 1
        assert data["logs"][0]["action"] == "speak"
        assert data["logs"][0]["message"] == "Try factoring"

    @pytest.mark.anyio
    async def test_usage_aggregation(self, client, db):
        sid = _sid()
        for pt, ct, cost in [(100, 50, 0.001), (200, 80, 0.002)]:
            await db.execute(
                """INSERT INTO reasoning_logs (session_id, page, action, message, prompt_tokens, completion_tokens, estimated_cost)
                   VALUES ($1, 1, 'speak', 'msg', $2, $3, $4)""",
                sid, pt, ct, cost,
            )

        resp = client.get(f"/api/reasoning-logs?session_id={sid}")
        usage = resp.json()["usage"]
        assert usage["calls"] == 2
        assert usage["prompt_tokens"] == 300
        assert usage["completion_tokens"] == 130
        assert abs(usage["estimated_cost"] - 0.003) < 0.0001

    @pytest.mark.anyio
    async def test_limit_param(self, client, db):
        sid = _sid()
        for i in range(3):
            await db.execute(
                """INSERT INTO reasoning_logs (session_id, page, action, message, prompt_tokens, completion_tokens, estimated_cost)
                   VALUES ($1, 1, 'speak', $2, 10, 5, 0.0001)""",
                sid, f"msg{i}",
            )

        resp = client.get(f"/api/reasoning-logs?session_id={sid}&limit=1")
        assert len(resp.json()["logs"]) == 1


# ── GET /api/page-transcription ──────────────────────────────


class TestGetPageTranscription:
    def test_empty_defaults(self, client):
        sid = _sid()
        resp = client.get(f"/api/page-transcription?session_id={sid}&page=1")
        assert resp.status_code == 200
        data = resp.json()
        assert data["latex"] == ""
        assert data["text"] == ""
        assert data["confidence"] == 0

    @pytest.mark.anyio
    async def test_returns_transcription(self, client, db):
        sid = _sid()
        await db.execute(
            """INSERT INTO page_transcriptions (session_id, page, latex, text, confidence)
               VALUES ($1, 1, '\\\\sqrt{2}', 'square root of 2', 0.88)""",
            sid,
        )

        resp = client.get(f"/api/page-transcription?session_id={sid}&page=1")
        data = resp.json()
        assert data["latex"] == "\\\\sqrt{2}"
        assert data["text"] == "square root of 2"
        assert data["confidence"] == 0.88

    @pytest.mark.anyio
    async def test_line_data_json(self, client, db):
        sid = _sid()
        line_data = json.dumps([{"type": "math", "value": "x+1"}])
        await db.execute(
            """INSERT INTO page_transcriptions (session_id, page, latex, text, confidence, line_data)
               VALUES ($1, 1, 'x+1', 'x plus 1', 0.9, $2::jsonb)""",
            sid, line_data,
        )

        resp = client.get(f"/api/page-transcription?session_id={sid}&page=1")
        data = resp.json()
        assert isinstance(data["line_data"], list)
        assert data["line_data"][0]["type"] == "math"


# ── Disconnect unknown session ───────────────────────────────


class TestDisconnectUnknown:
    def test_unknown_session_noop(self, client):
        sid = f"unknown_{uuid.uuid4().hex[:8]}"
        resp = client.post("/api/strokes/disconnect", json={"session_id": sid})
        assert resp.status_code == 200
        assert resp.json()["status"] == "disconnected"


class TestContentMode:
    def test_content_mode_stored_in_active_sessions(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})

        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
            "event_type": "draw",
            "content_mode": "diagram",
        })
        assert _active_sessions[sid]["content_mode"] == "diagram"

    def test_content_mode_defaults_to_math(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})

        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
            "event_type": "draw",
        })
        assert _active_sessions[sid]["content_mode"] == "math"

    def test_content_mode_not_overwritten_by_none(self, client):
        sid = _sid()
        client.post("/api/strokes/connect", json={"session_id": sid})

        # Set to diagram
        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [1], "y": [2]}],
            "content_mode": "diagram",
        })
        assert _active_sessions[sid]["content_mode"] == "diagram"

        # Send without content_mode — should keep "diagram"
        client.post("/api/strokes", json={
            "session_id": sid,
            "page": 1,
            "strokes": [{"x": [3], "y": [4]}],
        })
        assert _active_sessions[sid]["content_mode"] == "diagram"
