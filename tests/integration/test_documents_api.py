"""Integration tests for DELETE /ai/documents/{filename} — real DB via TestClient."""

import uuid

import pytest


def _fname() -> str:
    """Generate a unique document filename for test isolation."""
    return f"test_{uuid.uuid4().hex[:8]}.pdf"


class TestDeleteDocument:
    @pytest.mark.anyio
    async def test_delete_existing(self, client, db):
        fname = _fname()
        await db.execute(
            "INSERT INTO documents (filename, page_count, total_problems) VALUES ($1, 2, 5)",
            fname,
        )

        resp = client.delete(f"/ai/documents/{fname}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["deleted"] == 1
        assert data["filename"] == fname

    @pytest.mark.anyio
    async def test_cascades_to_questions_and_keys(self, client, db):
        fname = _fname()
        doc_id = await db.fetchval(
            "INSERT INTO documents (filename, page_count, total_problems) VALUES ($1, 1, 1) RETURNING id",
            fname,
        )
        q_id = await db.fetchval(
            "INSERT INTO questions (document_id, number, label, text) VALUES ($1, 1, '1', 'Solve x') RETURNING id",
            doc_id,
        )
        await db.execute(
            "INSERT INTO answer_keys (question_id, part_label, answer) VALUES ($1, 'a', '42')",
            q_id,
        )

        client.delete(f"/ai/documents/{fname}")

        q_count = await db.fetchval("SELECT COUNT(*) FROM questions WHERE document_id = $1", doc_id)
        ak_count = await db.fetchval("SELECT COUNT(*) FROM answer_keys WHERE question_id = $1", q_id)
        assert q_count == 0
        assert ak_count == 0

    def test_not_found(self, client):
        resp = client.delete(f"/ai/documents/nonexistent_{uuid.uuid4().hex[:8]}.pdf")
        assert resp.status_code == 404

    @pytest.mark.anyio
    async def test_multiple_same_filename(self, client, db):
        fname = _fname()
        await db.execute(
            "INSERT INTO documents (filename, page_count, total_problems) VALUES ($1, 1, 1)",
            fname,
        )
        await db.execute(
            "INSERT INTO documents (filename, page_count, total_problems) VALUES ($1, 2, 3)",
            fname,
        )

        resp = client.delete(f"/ai/documents/{fname}")
        assert resp.status_code == 200
        assert resp.json()["deleted"] == 2
