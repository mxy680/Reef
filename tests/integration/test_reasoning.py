"""Integration tests for lib/reasoning.py — reasoning pipeline with mocked LLM.

TestBuildContext exercises real DB via the /api/reasoning-preview endpoint
(which calls build_context_structured — identical queries to build_context).

TestRunReasoning / TestRunQuestionReasoning / TestRunQuestionReasoningStreaming
replace LLM calls with respx HTTP interception (OpenRouter), DB pool with
FakePool, and build_context with monkeypatch.setattr to avoid cross-event-loop
issues.
"""
import asyncio
import uuid

import httpx
import pytest
import respx

from api.strokes import _active_sessions
from lib.reasoning import ReasoningContext
from tests.helpers import FakePool, make_chat_completion, make_sse_stream


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
    async def test_active_part_scopes_answer_key(self, client, db):
        sid = _sid()
        doc_id = await db.fetchval(
            "INSERT INTO documents (filename, page_count, total_problems) "
            "VALUES ('multipart', 1, 1) RETURNING id"
        )
        q_parts = [
            {"label": "a", "text": "Find x"},
            {"label": "b", "text": "Find y"},
            {"label": "c", "text": "Find z"},
        ]
        q_id = await db.fetchval(
            "INSERT INTO questions (document_id, number, label, text, parts, figures, "
            "annotation_indices, bboxes, answer_space_cm) "
            "VALUES ($1, 1, 'Problem 1', 'Multi-part question', $2::jsonb, '[]'::jsonb, "
            "'[]'::jsonb, '[]'::jsonb, 3.0) RETURNING id",
            doc_id, __import__("json").dumps(q_parts),
        )
        await db.execute(
            "INSERT INTO answer_keys (question_id, part_label, answer) VALUES ($1, 'a', 'x=1')",
            q_id,
        )
        await db.execute(
            "INSERT INTO answer_keys (question_id, part_label, answer) VALUES ($1, 'b', 'y=2')",
            q_id,
        )
        await db.execute(
            "INSERT INTO answer_keys (question_id, part_label, answer) VALUES ($1, 'c', 'z=3')",
            q_id,
        )
        _active_sessions[sid] = {
            "document_name": "multipart.pdf",
            "question_number": 1,
            "last_seen": "",
            "active_part": "b",
        }

        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        sections = resp.json()["sections"]
        titles = [s["title"] for s in sections]

        # Active part's answer key should be scoped
        assert any("Answer Key (Part b)" in t for t in titles)
        ak = next(s for s in sections if "Answer Key (Part b)" in s["title"])
        assert "y=2" in ak["content"]
        assert "x=1" not in ak["content"]

        # Earlier part shown as reference
        assert any("Previous Parts" in t for t in titles)
        prev = next(s for s in sections if "Previous Parts" in s["title"])
        assert "x=1" in prev["content"]

        # Later part (c) should NOT appear in answer keys
        for s in sections:
            if "Answer Key" in s["title"] or "Previous Parts" in s["title"]:
                assert "z=3" not in s["content"]

        # Problem parts: c should be hidden, b should have marker
        problem = next(s for s in sections if "Original Problem" in s["title"])
        assert "\u2190 currently working on this part" in problem["content"]
        assert "(c)" not in problem["content"]

    @pytest.mark.anyio
    async def test_no_active_part_shows_all(self, client, db):
        sid = _sid()
        doc_id = await db.fetchval(
            "INSERT INTO documents (filename, page_count, total_problems) "
            "VALUES ('nopart', 1, 1) RETURNING id"
        )
        q_parts = [
            {"label": "a", "text": "Find x"},
            {"label": "b", "text": "Find y"},
        ]
        q_id = await db.fetchval(
            "INSERT INTO questions (document_id, number, label, text, parts, figures, "
            "annotation_indices, bboxes, answer_space_cm) "
            "VALUES ($1, 1, 'Problem 1', 'Multi-part', $2::jsonb, '[]'::jsonb, "
            "'[]'::jsonb, '[]'::jsonb, 3.0) RETURNING id",
            doc_id, __import__("json").dumps(q_parts),
        )
        await db.execute(
            "INSERT INTO answer_keys (question_id, part_label, answer) VALUES ($1, 'a', 'x=1')",
            q_id,
        )
        await db.execute(
            "INSERT INTO answer_keys (question_id, part_label, answer) VALUES ($1, 'b', 'y=2')",
            q_id,
        )
        # No active_part set (backward compat)
        _active_sessions[sid] = {
            "document_name": "nopart.pdf",
            "question_number": 1,
            "last_seen": "",
            "active_part": None,
        }

        resp = client.get(f"/api/reasoning-preview?session_id={sid}&page=1")
        sections = resp.json()["sections"]
        titles = [s["title"] for s in sections]

        # Should show unified "Answer Key" — not scoped
        assert "Answer Key" in titles
        ak = next(s for s in sections if s["title"] == "Answer Key")
        assert "x=1" in ak["content"]
        assert "y=2" in ak["content"]

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


# ── TestRunReasoning — FakePool + respx + monkeypatch ──────────────


OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"


class TestRunReasoning:
    def test_empty_context_returns_silent(self, monkeypatch):
        from lib.reasoning import run_reasoning

        async def fake_build_context(sid, page):
            return ReasoningContext(text="")

        monkeypatch.setattr("lib.reasoning.build_context", fake_build_context)
        monkeypatch.setattr("lib.reasoning.get_pool", lambda: None)

        result = asyncio.run(run_reasoning(_sid(), 1))
        assert result["action"] == "silent"
        assert result["message"] == "No context available"

    def test_speak_logged_to_db(self, monkeypatch):
        """run_reasoning now uses streaming — mock with SSE response."""
        from lib.reasoning import run_reasoning

        async def fake_build_context(sid, page):
            return ReasoningContext(text="x squared")

        fake_pool = FakePool()
        monkeypatch.setattr("lib.reasoning.build_context", fake_build_context)
        monkeypatch.setattr("lib.reasoning.get_pool", lambda: fake_pool)

        sse_bytes = make_sse_stream([
            '{"action": "speak", ',
            '"message": "Try factoring.", ',
            '"delay_ms": 0}',
        ])

        with respx.mock:
            respx.post(OPENROUTER_URL).mock(
                return_value=httpx.Response(
                    200,
                    content=sse_bytes,
                    headers={"content-type": "text/event-stream"},
                )
            )
            result = asyncio.run(run_reasoning(_sid(), 1))

        assert result["action"] == "speak"
        assert result["message"] == "Try factoring."
        assert result["delay_ms"] == 0

        # Verify DB insert was called with correct action/message
        assert len(fake_pool.conn.calls) == 1
        call_args = fake_pool.conn.calls[0]
        # Tuple: (query, session_id, page, context, action, message, pt, ct, cost, delay_ms)
        assert call_args[4] == "speak"
        assert call_args[5] == "Try factoring."
        assert call_args[9] == 0  # delay_ms

    def test_silent_early_exit(self, monkeypatch):
        """Streaming detects 'silent' action and exits early."""
        from lib.reasoning import run_reasoning

        async def fake_build_context(sid, page):
            return ReasoningContext(text="x squared")

        fake_pool = FakePool()
        monkeypatch.setattr("lib.reasoning.build_context", fake_build_context)
        monkeypatch.setattr("lib.reasoning.get_pool", lambda: fake_pool)

        # The stream starts with action: silent — should early-exit
        sse_bytes = make_sse_stream([
            '{"action": "silent", ',
            '"message": "Student is working correctly", ',
            '"delay_ms": 0}',
        ])

        with respx.mock:
            respx.post(OPENROUTER_URL).mock(
                return_value=httpx.Response(
                    200,
                    content=sse_bytes,
                    headers={"content-type": "text/event-stream"},
                )
            )
            result = asyncio.run(run_reasoning(_sid(), 1))

        assert result["action"] == "silent"
        assert result["early_exit"] is True

    def test_db_insert_has_token_counts(self, monkeypatch):
        from lib.reasoning import run_reasoning

        async def fake_build_context(sid, page):
            return ReasoningContext(text="some work")

        fake_pool = FakePool()
        monkeypatch.setattr("lib.reasoning.build_context", fake_build_context)
        monkeypatch.setattr("lib.reasoning.get_pool", lambda: fake_pool)

        sse_bytes = make_sse_stream([
            '{"action": "silent", ',
            '"message": "Student is working, no errors detected", ',
            '"delay_ms": 0}',
        ])

        with respx.mock:
            respx.post(OPENROUTER_URL).mock(
                return_value=httpx.Response(
                    200,
                    content=sse_bytes,
                    headers={"content-type": "text/event-stream"},
                )
            )
            asyncio.run(run_reasoning(_sid(), 1))

        assert len(fake_pool.conn.calls) == 1
        call_args = fake_pool.conn.calls[0]
        # Tuple: (query, sid, page, context, action, message, prompt_tokens, completion_tokens, cost, delay_ms)
        prompt_tokens = call_args[6]
        completion_tokens = call_args[7]
        estimated_cost = call_args[8]
        assert prompt_tokens > 0
        assert completion_tokens > 0
        assert estimated_cost > 0


# ── TestRunQuestionReasoning ─────────────────────────────────────────


class TestRunQuestionReasoning:
    def test_forces_speak_action(self, monkeypatch):
        from lib.reasoning import run_question_reasoning

        async def fake_build_context(sid, page):
            return ReasoningContext(text="context")

        fake_pool = FakePool()
        monkeypatch.setattr("lib.reasoning.build_context", fake_build_context)
        monkeypatch.setattr("lib.reasoning.get_pool", lambda: fake_pool)

        with respx.mock:
            respx.post(OPENROUTER_URL).mock(
                return_value=httpx.Response(
                    200,
                    json=make_chat_completion('{"action": "silent", "message": "I would stay quiet", "delay_ms": 0}'),
                )
            )
            result = asyncio.run(run_question_reasoning(_sid(), 1, "What is x?"))

        # Voice questions always force speak regardless of model output
        assert result["action"] == "speak"

    def test_source_voice_question(self, monkeypatch):
        from lib.reasoning import run_question_reasoning

        async def fake_build_context(sid, page):
            return ReasoningContext(text="context")

        fake_pool = FakePool()
        monkeypatch.setattr("lib.reasoning.build_context", fake_build_context)
        monkeypatch.setattr("lib.reasoning.get_pool", lambda: fake_pool)

        with respx.mock:
            respx.post(OPENROUTER_URL).mock(
                return_value=httpx.Response(
                    200,
                    json=make_chat_completion('{"action": "speak", "message": "x equals 5.", "delay_ms": 0}'),
                )
            )
            asyncio.run(run_question_reasoning(_sid(), 1, "What is x?"))

        assert len(fake_pool.conn.calls) == 1
        call_args = fake_pool.conn.calls[0]
        # Tuple: (query, sid, page, context, action, message, pt, ct, cost, source, question_text, delay_ms)
        source = call_args[9]
        question_text = call_args[10]
        assert source == "voice_question"
        assert question_text == "What is x?"
        assert call_args[11] == 0  # delay_ms forced to 0 for voice questions


# ── TestRunQuestionReasoningStreaming ─────────────────────────────────


class TestRunQuestionReasoningStreaming:
    def test_sentences_pushed_to_queue(self, monkeypatch):
        from lib.reasoning import run_question_reasoning_streaming

        async def fake_build_context(sid, page):
            return ReasoningContext(text="context")

        fake_pool = FakePool()
        monkeypatch.setattr("lib.reasoning.build_context", fake_build_context)
        monkeypatch.setattr("lib.reasoning.get_pool", lambda: fake_pool)

        sse_bytes = make_sse_stream([
            "First sentence. ",
            "Second sentence.",
        ])

        async def run():
            queue = asyncio.Queue()
            await run_question_reasoning_streaming(_sid(), 1, "Help me", queue)
            items = []
            while not queue.empty():
                items.append(queue.get_nowait())
            return items

        with respx.mock:
            respx.post(OPENROUTER_URL).mock(
                return_value=httpx.Response(
                    200,
                    content=sse_bytes,
                    headers={"content-type": "text/event-stream"},
                )
            )
            items = asyncio.run(run())

        assert None in items
        sentences = [i for i in items if i is not None]
        assert len(sentences) >= 1

    def test_none_sentinel_at_end(self, monkeypatch):
        from lib.reasoning import run_question_reasoning_streaming

        async def fake_build_context(sid, page):
            return ReasoningContext(text="context")

        fake_pool = FakePool()
        monkeypatch.setattr("lib.reasoning.build_context", fake_build_context)
        monkeypatch.setattr("lib.reasoning.get_pool", lambda: fake_pool)

        sse_bytes = make_sse_stream(["Hello."])

        async def run():
            queue = asyncio.Queue()
            await run_question_reasoning_streaming(_sid(), 1, "test", queue)
            items = []
            while not queue.empty():
                items.append(queue.get_nowait())
            return items

        with respx.mock:
            respx.post(OPENROUTER_URL).mock(
                return_value=httpx.Response(
                    200,
                    content=sse_bytes,
                    headers={"content-type": "text/event-stream"},
                )
            )
            items = asyncio.run(run())

        assert items[-1] is None

    def test_sentinel_on_error(self, monkeypatch):
        from lib.reasoning import run_question_reasoning_streaming

        async def fake_build_context(sid, page):
            return ReasoningContext(text="context")

        fake_pool = FakePool()
        monkeypatch.setattr("lib.reasoning.build_context", fake_build_context)
        monkeypatch.setattr("lib.reasoning.get_pool", lambda: fake_pool)

        async def run():
            queue = asyncio.Queue()
            await run_question_reasoning_streaming(_sid(), 1, "test", queue)
            items = []
            while not queue.empty():
                items.append(queue.get_nowait())
            return items

        with respx.mock:
            respx.post(OPENROUTER_URL).mock(
                return_value=httpx.Response(500, json={"error": "Internal Server Error"})
            )
            items = asyncio.run(run())

        assert None in items
