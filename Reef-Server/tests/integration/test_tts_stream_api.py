"""Integration tests for api/tts_stream.py — HTTP TTS streaming."""
import asyncio

import httpx
import pytest
import respx

from api.tts_stream import _pending_tts, register_tts, register_tts_stream
from tests.helpers import load_fixture

DEEPINFRA_TTS_URL = "https://api.deepinfra.com/v1/openai/audio/speech"


def test_text_based_streams_pcm(client):
    fixture_bytes = load_fixture("deepinfra_tts.bin")
    tts_id = register_tts("Hello world.")
    with respx.mock:
        respx.post(DEEPINFRA_TTS_URL).mock(
            return_value=httpx.Response(200, content=fixture_bytes)
        )
        resp = client.get(f"/api/tts/stream/{tts_id}")
    assert resp.status_code == 200
    assert len(resp.content) > 0


def test_correct_headers(client):
    fixture_bytes = load_fixture("deepinfra_tts.bin")
    tts_id = register_tts("Hello.")
    with respx.mock:
        respx.post(DEEPINFRA_TTS_URL).mock(
            return_value=httpx.Response(200, content=fixture_bytes)
        )
        resp = client.get(f"/api/tts/stream/{tts_id}")
    assert resp.headers["x-sample-rate"] == "24000"
    assert resp.headers["x-channels"] == "1"
    assert resp.headers["x-sample-width"] == "2"


def test_404_missing_tts_id(client):
    resp = client.get("/api/tts/stream/nonexistent_id")
    assert resp.status_code == 404


def test_404_already_consumed(client):
    fixture_bytes = load_fixture("deepinfra_tts.bin")
    tts_id = register_tts("Test.")
    with respx.mock:
        respx.post(DEEPINFRA_TTS_URL).mock(
            return_value=httpx.Response(200, content=fixture_bytes)
        )
        client.get(f"/api/tts/stream/{tts_id}")  # first consume
        resp = client.get(f"/api/tts/stream/{tts_id}")  # second attempt
    assert resp.status_code == 404


def test_queue_based_streams(client):
    fixture_bytes = load_fixture("deepinfra_tts.bin")
    tts_id, queue = register_tts_stream()
    queue.put_nowait("Hello.")
    queue.put_nowait("World.")
    queue.put_nowait(None)
    with respx.mock:
        route = respx.post(DEEPINFRA_TTS_URL).mock(
            return_value=httpx.Response(200, content=fixture_bytes)
        )
        resp = client.get(f"/api/tts/stream/{tts_id}")
    assert resp.status_code == 200
    assert len(resp.content) > 0
    assert route.call_count == 2  # one per sentence
