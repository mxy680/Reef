"""Integration tests for api/strokes.py — real DB stroke lifecycle via TestClient."""

import uuid

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
