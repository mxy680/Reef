"""Integration tests for api/voice.py — voice transcription endpoints."""
import uuid
from unittest.mock import AsyncMock, patch

import pytest


def _sid():
    return f"test_{uuid.uuid4().hex[:12]}"


class TestVoiceTranscribe:
    @patch("api.voice.transcribe", return_value="hello world")
    def test_happy_path(self, mock_transcribe, client):
        sid = _sid()
        resp = client.post(
            "/api/voice/transcribe",
            files={"audio": ("test.wav", b"fake audio bytes", "audio/wav")},
            data={"session_id": sid, "page": "1"},
        )
        assert resp.status_code == 200
        assert resp.json()["transcription"] == "hello world"
        mock_transcribe.assert_called_once()

    def test_empty_audio(self, client):
        sid = _sid()
        resp = client.post(
            "/api/voice/transcribe",
            files={"audio": ("test.wav", b"", "audio/wav")},
            data={"session_id": sid, "page": "1"},
        )
        assert resp.status_code == 200
        assert resp.json() == {"error": "No audio received"}

    @patch("api.voice.transcribe", return_value="test text")
    @pytest.mark.anyio
    async def test_db_logging(self, mock_transcribe, client, db):
        sid = _sid()
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


class TestVoiceQuestion:
    @patch("api.voice._async_question_reasoning", new_callable=AsyncMock)
    @patch("api.voice.transcribe", return_value="what is x?")
    def test_returns_transcription(self, mock_transcribe, mock_reasoning, client):
        sid = _sid()
        resp = client.post(
            "/api/voice/question",
            files={"audio": ("test.wav", b"fake audio", "audio/wav")},
            data={"session_id": sid, "page": "1"},
        )
        assert resp.status_code == 200
        assert resp.json()["transcription"] == "what is x?"
