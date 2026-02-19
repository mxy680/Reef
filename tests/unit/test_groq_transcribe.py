"""Unit tests for lib/groq_transcribe.py — Groq Whisper client."""
import os
from unittest.mock import MagicMock, patch

import pytest

import lib.groq_transcribe
from lib.groq_transcribe import _get_client, transcribe


class TestTranscribe:
    def test_returns_transcription_text(self):
        mock_client = MagicMock()
        mock_client.audio.transcriptions.create.return_value = MagicMock(text="hello world")
        with patch("lib.groq_transcribe._get_client", return_value=mock_client):
            result = transcribe(b"audio")
        assert result == "hello world"

    def test_uses_correct_model(self):
        mock_client = MagicMock()
        mock_client.audio.transcriptions.create.return_value = MagicMock(text="hi")
        with patch("lib.groq_transcribe._get_client", return_value=mock_client):
            transcribe(b"audio")
        mock_client.audio.transcriptions.create.assert_called_once_with(
            model="whisper-large-v3-turbo",
            file=("recording.wav", b"audio", "audio/wav"),
        )

    def test_missing_api_key_raises(self):
        original_client = lib.groq_transcribe._client
        lib.groq_transcribe._client = None
        try:
            with patch.dict(os.environ, {}, clear=True):
                with pytest.raises(RuntimeError, match="GROQ_API_KEY not set"):
                    _get_client()
        finally:
            lib.groq_transcribe._client = original_client
