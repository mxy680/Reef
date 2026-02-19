"""Integration tests for lib/reasoning.py — reasoning pipeline with mocked LLM.

TestBuildContext exercises real DB via the /api/reasoning-preview endpoint
(which calls build_context_structured — identical queries to build_context).

TestRunReasoning / TestRunQuestionReasoning / TestRunQuestionReasoningStreaming
mock build_context (already covered above), _get_client, and get_pool to avoid
cross-event-loop issues with the TestClient's asyncpg pool.
"""
import asyncio
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from api.strokes import _active_sessions


def _sid():
    return f"test_{uuid.uuid4().hex[:12]}"


# ── TestBuildContext — real DB via /api/reasoning-preview ─────────────


class TestBuildContext:
    """Tests for build_context logic via GET /api/reasoning-preview."""

    def test_no_transcription_returns_empty(self, client):
        sid = _sid()
        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        assert resp.status_code == 200
        data = resp.json()
        assert data["sections"] == []
        assert len(data["system_prompt"]) > 0

    @pytest.mark.anyio
    async def test_with_transcription(self, client, db):
        sid = _sid()
        await db.execute(
            "INSERT INTO page_transcriptions (session_id, page, latex, text, confidence) "
            "VALUES ($1, 1, 'x+1', 'x plus one', 0.9)",
            sid,
        )
        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        sections = resp.json()["sections"]
        titles = [s["title"] for s in sections]
        assert "Student's Current Work" in titles
        work = next(s for s in sections if s["title"] == "Student's Current Work")
        assert "x plus one" in work["content"]

    @pytest.mark.anyio
    async def test_with_problem_and_answer_key(self, client, db):
        sid = _sid()
        doc_id = await db.fetchval(
            "INSERT INTO documents (filename, page_count, total_problems) "
            "VALUES ('homework', 1, 1) RETURNING id"
        )
        q_id = await db.fetchval(
            "INSERT INTO questions (document_id, number, label, text, parts, figures, "
            "annotation_indices, bboxes, answer_space_cm) "
            "VALUES ($1, 1, 'Problem 1', 'Solve x+1=2', '[]'::jsonb, '[]'::jsonb, "
            "'[]'::jsonb, '[]'::jsonb, 3.0) RETURNING id",
            doc_id,
        )
        await db.execute(
            "INSERT INTO answer_keys (question_id, part_label, answer) VALUES ($1, NULL, 'x=1')",
            q_id,
        )
        _active_sessions[sid] = {
            "document_name": "homework.pdf",
            "question_number": 1,
            "last_seen": "",
        }

        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        sections = resp.json()["sections"]
        titles = [s["title"] for s in sections]
        assert any("Original Problem" in t for t in titles)
        assert any("Answer Key" in t for t in titles)
        problem = next(s for s in sections if "Original Problem" in s["title"])
        assert "Solve x+1=2" in problem["content"]
        ak = next(s for s in sections if "Answer Key" in s["title"])
        assert "x=1" in ak["content"]

    @pytest.mark.anyio
    async def test_with_reasoning_history(self, client, db):
        sid = _sid()
        await db.execute(
            "INSERT INTO page_transcriptions (session_id, page, latex, text, confidence) "
            "VALUES ($1, 1, 'y', 'y', 0.9)",
            sid,
        )
        await db.execute(
            "INSERT INTO reasoning_logs (session_id, page, action, message, "
            "prompt_tokens, completion_tokens, estimated_cost) "
            "VALUES ($1, 1, 'speak', 'Try factoring', 100, 10, 0.001)",
            sid,
        )
        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        sections = resp.json()["sections"]
        titles = [s["title"] for s in sections]
        assert "Recent Tutor History" in titles
        history = next(s for s in sections if s["title"] == "Recent Tutor History")
        assert "Try factoring" in history["content"]

    @pytest.mark.anyio
    async def test_fallback_to_session_question_cache(self, client, db):
        sid = _sid()
        doc_id = await db.fetchval(
            "INSERT INTO documents (filename, page_count, total_problems) "
            "VALUES ('cached_doc', 1, 1) RETURNING id"
        )
        q_id = await db.fetchval(
            "INSERT INTO questions (document_id, number, label, text, parts, figures, "
            "annotation_indices, bboxes, answer_space_cm) "
            "VALUES ($1, 1, 'Q1', 'What is 2+2?', '[]'::jsonb, '[]'::jsonb, "
            "'[]'::jsonb, '[]'::jsonb, 2.0) RETURNING id",
            doc_id,
        )
        await db.execute(
            "INSERT INTO session_question_cache (session_id, question_id) "
            "VALUES ($1, $2) ON CONFLICT (session_id) DO UPDATE SET question_id = $2",
            sid, q_id,
        )
        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        sections = resp.json()["sections"]
        assert any("What is 2+2?" in s["content"] for s in sections)


# ── Helpers for mock pool ────────────────────────────────────────────


def _make_mock_pool():
    """Create a mock asyncpg pool that records execute() calls."""
    mock_conn = AsyncMock()
    mock_ctx = AsyncMock()
    mock_ctx.__aenter__.return_value = mock_conn
    mock_ctx.__aexit__.return_value = None
    mock_pool = MagicMock()
    mock_pool.acquire.return_value = mock_ctx
    return mock_pool, mock_conn


# ── TestRunReasoning — mock build_context + LLM + pool ──────────────


class TestRunReasoning:
    @patch("lib.reasoning.get_pool", return_value=None)
    @patch("lib.reasoning.build_context", new_callable=AsyncMock, return_value="")
    def test_empty_context_returns_silent(self, mock_ctx, mock_pool):
        from lib.reasoning import run_reasoning

        result = asyncio.run(run_reasoning(_sid(), 1))
        assert result["action"] == "silent"
        assert result["message"] == "No context available"

    @patch("lib.reasoning.get_pool")
    @patch("lib.reasoning._get_client")
    @patch("lib.reasoning.build_context", new_callable=AsyncMock, return_value="x squared")
    def test_speak_logged_to_db(self, mock_ctx, mock_get_client, mock_get_pool):
        from lib.reasoning import run_reasoning

        mock_llm = MagicMock()
        mock_llm.generate.return_value = '{"action": "speak", "message": "Try factoring."}'
        mock_get_client.return_value = mock_llm

        mock_pool, mock_conn = _make_mock_pool()
        mock_get_pool.return_value = mock_pool

        result = asyncio.run(run_reasoning(_sid(), 1))
        assert result["action"] == "speak"
        assert result["message"] == "Try factoring."

        # Verify DB insert was called with correct action/message
        mock_conn.execute.assert_called_once()
        call_args = mock_conn.execute.call_args
        # Positional args: (query, session_id, page, context, action, message, ...)
        assert call_args[0][4] == "speak"
        assert call_args[0][5] == "Try factoring."

    @patch("lib.reasoning.get_pool")
    @patch("lib.reasoning._get_client")
    @patch("lib.reasoning.build_context", new_callable=AsyncMock, return_value="some work")
    def test_db_insert_has_token_counts(self, mock_ctx, mock_get_client, mock_get_pool):
        from lib.reasoning import run_reasoning

        mock_llm = MagicMock()
        mock_llm.generate.return_value = '{"action": "silent", "message": "Student is working"}'
        mock_get_client.return_value = mock_llm

        mock_pool, mock_conn = _make_mock_pool()
        mock_get_pool.return_value = mock_pool

        asyncio.run(run_reasoning(_sid(), 1))

        call_args = mock_conn.execute.call_args
        # Args: (query, sid, page, context, action, message, prompt_tokens, completion_tokens, cost)
        prompt_tokens = call_args[0][6]
        completion_tokens = call_args[0][7]
        estimated_cost = call_args[0][8]
        assert prompt_tokens > 0
        assert completion_tokens > 0
        assert estimated_cost > 0


# ── TestRunQuestionReasoning ─────────────────────────────────────────


class TestRunQuestionReasoning:
    @patch("lib.reasoning.get_pool")
    @patch("lib.reasoning._get_client")
    @patch("lib.reasoning.build_context", new_callable=AsyncMock, return_value="context")
    def test_forces_speak_action(self, mock_ctx, mock_get_client, mock_get_pool):
        from lib.reasoning import run_question_reasoning

        mock_llm = MagicMock()
        mock_llm.generate.return_value = '{"action": "silent", "message": "I would stay quiet"}'
        mock_get_client.return_value = mock_llm

        mock_pool, _ = _make_mock_pool()
        mock_get_pool.return_value = mock_pool

        result = asyncio.run(run_question_reasoning(_sid(), 1, "What is x?"))
        assert result["action"] == "speak"

    @patch("lib.reasoning.get_pool")
    @patch("lib.reasoning._get_client")
    @patch("lib.reasoning.build_context", new_callable=AsyncMock, return_value="context")
    def test_source_voice_question(self, mock_ctx, mock_get_client, mock_get_pool):
        from lib.reasoning import run_question_reasoning

        mock_llm = MagicMock()
        mock_llm.generate.return_value = '{"action": "speak", "message": "x equals 5"}'
        mock_get_client.return_value = mock_llm

        mock_pool, mock_conn = _make_mock_pool()
        mock_get_pool.return_value = mock_pool

        asyncio.run(run_question_reasoning(_sid(), 1, "What is x?"))

        call_args = mock_conn.execute.call_args
        # Args: (query, sid, page, context, action, message, pt, ct, cost, source, question_text)
        source = call_args[0][9]
        question_text = call_args[0][10]
        assert source == "voice_question"
        assert question_text == "What is x?"


# ── TestRunQuestionReasoningStreaming ─────────────────────────────────


class TestRunQuestionReasoningStreaming:
    @patch("lib.reasoning.get_pool")
    @patch("lib.reasoning._get_client")
    @patch("lib.reasoning.build_context", new_callable=AsyncMock, return_value="context")
    def test_sentences_pushed_to_queue(self, mock_ctx, mock_get_client, mock_get_pool):
        from lib.reasoning import run_question_reasoning_streaming

        async def mock_agenerate_stream(**kwargs):
            for t in ['{"action": "speak", "message": "', "First sentence. ", "Second sentence.", '"}']:
                yield t

        mock_llm = MagicMock()
        mock_llm.agenerate_stream = mock_agenerate_stream
        mock_get_client.return_value = mock_llm

        mock_pool, _ = _make_mock_pool()
        mock_get_pool.return_value = mock_pool

        async def run():
            queue = asyncio.Queue()
            await run_question_reasoning_streaming(_sid(), 1, "Help me", queue)
            items = []
            while not queue.empty():
                items.append(queue.get_nowait())
            return items

        items = asyncio.run(run())
        assert None in items
        sentences = [i for i in items if i is not None]
        assert len(sentences) >= 1

    @patch("lib.reasoning.get_pool")
    @patch("lib.reasoning._get_client")
    @patch("lib.reasoning.build_context", new_callable=AsyncMock, return_value="context")
    def test_none_sentinel_at_end(self, mock_ctx, mock_get_client, mock_get_pool):
        from lib.reasoning import run_question_reasoning_streaming

        async def mock_agenerate_stream(**kwargs):
            yield '{"action":"speak","message":"Hello."}'

        mock_llm = MagicMock()
        mock_llm.agenerate_stream = mock_agenerate_stream
        mock_get_client.return_value = mock_llm

        mock_pool, _ = _make_mock_pool()
        mock_get_pool.return_value = mock_pool

        async def run():
            queue = asyncio.Queue()
            await run_question_reasoning_streaming(_sid(), 1, "test", queue)
            items = []
            while not queue.empty():
                items.append(queue.get_nowait())
            return items

        items = asyncio.run(run())
        assert items[-1] is None

    @patch("lib.reasoning.get_pool")
    @patch("lib.reasoning._get_client")
    @patch("lib.reasoning.build_context", new_callable=AsyncMock, return_value="context")
    def test_sentinel_on_error(self, mock_ctx, mock_get_client, mock_get_pool):
        from lib.reasoning import run_question_reasoning_streaming

        async def mock_agenerate_stream(**kwargs):
            raise RuntimeError("LLM broke")
            if False:
                yield  # make it a valid async generator

        mock_llm = MagicMock()
        mock_llm.agenerate_stream = mock_agenerate_stream
        mock_get_client.return_value = mock_llm

        mock_pool, _ = _make_mock_pool()
        mock_get_pool.return_value = mock_pool

        async def run():
            queue = asyncio.Queue()
            await run_question_reasoning_streaming(_sid(), 1, "test", queue)
            items = []
            while not queue.empty():
                items.append(queue.get_nowait())
            return items

        items = asyncio.run(run())
        assert None in items
