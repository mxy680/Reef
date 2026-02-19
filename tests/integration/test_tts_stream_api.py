"""Integration tests for api/tts_stream.py — HTTP TTS streaming."""
import asyncio
import os
from unittest.mock import AsyncMock, patch

import pytest

from api.tts_stream import _pending_tts, register_tts, register_tts_stream


class TestTtsStream:
    @patch("api.tts_stream._fetch_tts_chunk", new_callable=AsyncMock, return_value=b"\x00" * 100)
    @patch.dict(os.environ, {"DEEPINFRA_API_KEY": "fake_key"})
    def test_text_based_streams_pcm(self, mock_fetch, client):
        tts_id = register_tts("Hello world.")
        resp = client.get(f"/api/tts/stream/{tts_id}")
        assert resp.status_code == 200
        assert len(resp.content) > 0
        mock_fetch.assert_called()

    @patch("api.tts_stream._fetch_tts_chunk", new_callable=AsyncMock, return_value=b"\x00" * 100)
    @patch.dict(os.environ, {"DEEPINFRA_API_KEY": "fake_key"})
    def test_correct_headers(self, mock_fetch, client):
        tts_id = register_tts("Hello.")
        resp = client.get(f"/api/tts/stream/{tts_id}")
        assert resp.headers["x-sample-rate"] == "24000"
        assert resp.headers["x-channels"] == "1"
        assert resp.headers["x-sample-width"] == "2"

    def test_404_missing_tts_id(self, client):
        resp = client.get("/api/tts/stream/nonexistent_id")
        assert resp.status_code == 404

    @patch("api.tts_stream._fetch_tts_chunk", new_callable=AsyncMock, return_value=b"\x00" * 50)
    @patch.dict(os.environ, {"DEEPINFRA_API_KEY": "fake_key"})
    def test_404_already_consumed(self, mock_fetch, client):
        tts_id = register_tts("Test.")
        client.get(f"/api/tts/stream/{tts_id}")  # first consume
        resp = client.get(f"/api/tts/stream/{tts_id}")  # second attempt
        assert resp.status_code == 404

    @patch("api.tts_stream._fetch_tts_chunk", new_callable=AsyncMock, return_value=b"\x00" * 80)
    @patch.dict(os.environ, {"DEEPINFRA_API_KEY": "fake_key"})
    def test_queue_based_streams(self, mock_fetch, client):
        tts_id, queue = register_tts_stream()
        # Pre-fill queue with sentences + None sentinel
        queue.put_nowait("Hello.")
        queue.put_nowait("World.")
        queue.put_nowait(None)
        resp = client.get(f"/api/tts/stream/{tts_id}")
        assert resp.status_code == 200
        assert len(resp.content) > 0
        assert mock_fetch.call_count == 2  # one per sentence
