"""Shared test helpers — FakePool, fixture loader, response builders."""

import json
import os

FIXTURES_DIR = os.path.join(os.path.dirname(__file__), "fixtures")


# ── Fixture loading ───────────────────────────────────────


def load_fixture(name: str):
    """Load a test fixture by name from tests/fixtures/.

    Returns dict for .json, bytes for .bin, str for everything else.
    """
    path = os.path.join(FIXTURES_DIR, name)
    if name.endswith(".json"):
        with open(path) as f:
            return json.load(f)
    elif name.endswith(".bin"):
        with open(path, "rb") as f:
            return f.read()
    else:
        with open(path) as f:
            return f.read()


# ── Response builders ─────────────────────────────────────


def make_chat_completion(content: str) -> dict:
    """Create an OpenAI-compatible chat completion response with custom content."""
    return {
        "id": "chatcmpl-test",
        "object": "chat.completion",
        "created": 1700000000,
        "model": "test-model",
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": content},
                "finish_reason": "stop",
            }
        ],
        "usage": {"prompt_tokens": 100, "completion_tokens": 20, "total_tokens": 120},
    }


def make_sse_stream(chunks: list[str | None]) -> bytes:
    """Generate SSE stream bytes for OpenAI-compatible streaming responses.

    Args:
        chunks: list of content strings. None means empty delta (no content key).
    """
    lines = []
    for chunk in chunks:
        delta = {"content": chunk} if chunk is not None else {}
        event = {
            "id": "chatcmpl-test",
            "object": "chat.completion.chunk",
            "created": 1700000000,
            "model": "test-model",
            "choices": [{"index": 0, "delta": delta, "finish_reason": None}],
        }
        lines.append(f"data: {json.dumps(event)}\n\n")
    # Final chunk with finish_reason
    stop_event = {
        "id": "chatcmpl-test",
        "object": "chat.completion.chunk",
        "created": 1700000000,
        "model": "test-model",
        "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
    }
    lines.append(f"data: {json.dumps(stop_event)}\n\n")
    lines.append("data: [DONE]\n\n")
    return "".join(lines).encode()


def make_embed_response(num_texts: int, dimensions: int = 384) -> dict:
    """Create a Modal-compatible embedding response."""
    embeddings = [[0.01] * dimensions for _ in range(num_texts)]
    return {"embeddings": embeddings}


# ── Fake asyncpg pool ─────────────────────────────────────


class FakeConn:
    """Records execute() calls — plain Python, not MagicMock."""

    def __init__(self):
        self.calls = []

    async def execute(self, query, *args):
        self.calls.append((query, *args))


class _FakeAcquireCtx:
    def __init__(self, conn):
        self.conn = conn

    async def __aenter__(self):
        return self.conn

    async def __aexit__(self, *a):
        pass


class FakePool:
    """Avoids cross-event-loop asyncpg issues in reasoning tests."""

    def __init__(self):
        self.conn = FakeConn()

    def acquire(self):
        return _FakeAcquireCtx(self.conn)
