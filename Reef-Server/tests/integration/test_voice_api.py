"""Integration tests for api/voice.py — voice transcription endpoints."""
import uuid

import httpx
import pytest
import respx

import lib.groq_transcribe

TRANSCRIPTIONS_URL = "https://api.groq.com/openai/v1/audio/transcriptions"


async def _noop(*args, **kwargs):
    pass


def _sid():
    return f"test_{uuid.uuid4().hex[:12]}"


def test_happy_path(client, monkeypatch):
    monkeypatch.setattr("lib.groq_transcribe._client", None)
    sid = _sid()
    with respx.mock:
        respx.post(TRANSCRIPTIONS_URL).mock(
            return_value=httpx.Response(200, json={"text": "hello world"})
        )
        resp = client.post(
            "/api/voice/transcribe",
            files={"audio": ("test.wav", b"fake audio bytes", "audio/wav")},
            data={"session_id": sid, "page": "1"},
        )
    assert resp.status_code == 200
    assert resp.json()["transcription"] == "hello world"


def test_empty_audio(client):
    sid = _sid()
    resp = client.post(
        "/api/voice/transcribe",
        files={"audio": ("test.wav", b"", "audio/wav")},
        data={"session_id": sid, "page": "1"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"error": "No audio received"}


@pytest.mark.anyio
async def test_db_logging(client, db, monkeypatch):
    monkeypatch.setattr("lib.groq_transcribe._client", None)
    sid = _sid()
    with respx.mock:
        respx.post(TRANSCRIPTIONS_URL).mock(
            return_value=httpx.Response(200, json={"text": "test text"})
        )
        client.post(
            "/api/voice/transcribe",
            files={"audio": ("test.wav", b"fake", "audio/wav")},
            data={"session_id": sid, "page": "1"},
        )
    row = await db.fetchrow(
        "SELECT event_type, message FROM stroke_logs WHERE session_id = $1 AND event_type = 'voice'",
        sid,
    )
    assert row is not None
    assert row["event_type"] == "voice"
    assert row["message"] == "test text"


def test_returns_transcription(client, monkeypatch):
    monkeypatch.setattr("lib.groq_transcribe._client", None)
    monkeypatch.setattr("api.voice._async_question_reasoning", _noop)
    sid = _sid()
    with respx.mock:
        respx.post(TRANSCRIPTIONS_URL).mock(
            return_value=httpx.Response(200, json={"text": "what is x?"})
        )
        resp = client.post(
            "/api/voice/question",
            files={"audio": ("test.wav", b"fake audio", "audio/wav")},
            data={"session_id": sid, "page": "1"},
        )
    assert resp.status_code == 200
    assert resp.json()["transcription"] == "what is x?"
