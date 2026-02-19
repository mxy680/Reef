"""Integration tests for api/tts.py — WebSocket TTS endpoint."""
import json
from unittest.mock import patch


class TestWsTts:
    @patch("api.tts.stream_tts", return_value=iter([b"\x00" * 100, b"\x01" * 50]))
    def test_synthesize_flow(self, mock_stream, client):
        with client.websocket_connect("/ws/tts") as ws:
            ws.send_text(json.dumps({"type": "synthesize", "text": "Hello world"}))
            # Should receive: tts_start (JSON), binary chunk 1, binary chunk 2, tts_end (JSON)
            start = ws.receive_json()
            assert start["type"] == "tts_start"
            assert start["sample_rate"] == 24000

            chunk1 = ws.receive_bytes()
            assert chunk1 == b"\x00" * 100

            chunk2 = ws.receive_bytes()
            assert chunk2 == b"\x01" * 50

            end = ws.receive_json()
            assert end["type"] == "tts_end"

    def test_empty_text_returns_error(self, client):
        with client.websocket_connect("/ws/tts") as ws:
            ws.send_text(json.dumps({"type": "synthesize", "text": ""}))
            resp = ws.receive_json()
            assert resp["type"] == "error"
            assert "Empty text" in resp["detail"]

    def test_unknown_type_returns_error(self, client):
        with client.websocket_connect("/ws/tts") as ws:
            ws.send_text(json.dumps({"type": "unknown_command"}))
            resp = ws.receive_json()
            assert resp["type"] == "error"
            assert "Unknown" in resp["detail"]
