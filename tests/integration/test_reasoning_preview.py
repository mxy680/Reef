"""Integration tests for GET /api/reasoning-preview — prompt preview endpoint."""
import uuid

import pytest

from api.strokes import _active_sessions


def _sid():
    return f"test_{uuid.uuid4().hex[:12]}"


class TestReasoningPreview:
    def test_empty_page_returns_system_prompt(self, client):
        sid = _sid()
        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        assert resp.status_code == 200
        data = resp.json()
        assert "system_prompt" in data
        assert len(data["system_prompt"]) > 0
        assert data["sections"] == []

    @pytest.mark.anyio
    async def test_with_transcription_data(self, client, db):
        sid = _sid()
        await db.execute(
            "INSERT INTO page_transcriptions (session_id, page, latex, text, confidence) VALUES ($1, 1, 'x^2+1', 'x squared plus one', 0.92)",
            sid,
        )
        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        data = resp.json()
        titles = [s["title"] for s in data["sections"]]
        assert "Student's Current Work" in titles
        work_section = next(s for s in data["sections"] if s["title"] == "Student's Current Work")
        assert "x squared plus one" in work_section["content"]

    @pytest.mark.anyio
    async def test_with_problem_data(self, client, db):
        sid = _sid()
        doc_id = await db.fetchval(
            "INSERT INTO documents (filename, page_count, total_problems) VALUES ('test_doc', 1, 1) RETURNING id"
        )
        q_id = await db.fetchval(
            "INSERT INTO questions (document_id, number, label, text, parts, figures, annotation_indices, bboxes, answer_space_cm) VALUES ($1, 1, 'Problem 1', 'Find the derivative of x^2', '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb, 3.0) RETURNING id",
            doc_id,
        )
        # Populate _active_sessions so build_context_structured can find the question
        _active_sessions[sid] = {"document_name": "test_doc.pdf", "question_number": 1, "last_seen": ""}

        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        data = resp.json()
        titles = [s["title"] for s in data["sections"]]
        assert any("Original Problem" in t for t in titles)
        problem_section = next(s for s in data["sections"] if "Original Problem" in s["title"])
        assert "Find the derivative" in problem_section["content"]
