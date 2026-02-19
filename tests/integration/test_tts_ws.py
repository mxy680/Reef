"""Integration tests for api/tts.py — WebSocket TTS endpoint."""
import json

import responses

from tests.helpers import load_fixture

MODAL_TTS_URL = "https://fake-modal-tts.example.com/tts"


def test_empty_text_returns_error(client):
    with client.websocket_connect("/ws/tts") as ws:
        ws.send_text(json.dumps({"type": "synthesize", "text": ""}))
        resp = ws.receive_json()
        assert resp["type"] == "error"
        assert "Empty text" in resp["detail"]


def test_unknown_type_returns_error(client):
    with client.websocket_connect("/ws/tts") as ws:
        ws.send_text(json.dumps({"type": "unknown_command"}))
        resp = ws.receive_json()
        assert resp["type"] == "error"
        assert "Unknown" in resp["detail"]


@responses.activate
def test_synthesize_flow(client, monkeypatch):
    monkeypatch.setattr("lib.tts_client.MODAL_TTS_URL", MODAL_TTS_URL)
    fixture_bytes = load_fixture("modal_tts.bin")
    responses.add(responses.POST, MODAL_TTS_URL, body=fixture_bytes, status=200)

    with client.websocket_connect("/ws/tts") as ws:
        ws.send_text(json.dumps({"type": "synthesize", "text": "Hello world"}))

        start = ws.receive_json()
        assert start["type"] == "tts_start"
        assert start["sample_rate"] == 24000
        assert start["channels"] == 1
        assert start["sample_width"] == 2

        # Collect binary chunks until a JSON frame arrives
        received = bytearray()
        while True:
            msg = ws.receive()  # raw ASGI dict: {"type": "websocket.send", "bytes"|"text": ...}
            if msg.get("bytes"):
                received.extend(msg["bytes"])
            else:
                data = json.loads(msg["text"])
                assert data["type"] == "tts_end"
                break

        assert bytes(received) == fixture_bytes
