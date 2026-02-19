"""Unit tests for lib/groq_transcribe.py — Groq Whisper client."""
import os

import httpx
import pytest
import respx

import lib.groq_transcribe
from lib.groq_transcribe import _get_client, transcribe
from tests.conftest import REEF_TEST_MODE
from tests.helpers import load_fixture

TRANSCRIPTIONS_URL = "https://api.groq.com/openai/v1/audio/transcriptions"


def _reset_singleton():
    """Reset the module-level OpenAI client singleton."""
    lib.groq_transcribe._client = None


def _restore_singleton(original):
    """Restore the module-level OpenAI client singleton."""
    lib.groq_transcribe._client = original


class TestTranscribe:
    def test_returns_transcription_text(self):
        fixture = load_fixture("groq_whisper.json")
        original = lib.groq_transcribe._client
        _reset_singleton()
        try:
            with respx.mock:
                respx.post(TRANSCRIPTIONS_URL).mock(
                    return_value=httpx.Response(200, json=fixture)
                )
                result = transcribe(b"fake-audio")
        finally:
            _restore_singleton(original)

        assert result == fixture["text"]

    def test_uses_correct_model(self):
        fixture = load_fixture("groq_whisper.json")
        original = lib.groq_transcribe._client
        _reset_singleton()
        try:
            with respx.mock:
                route = respx.post(TRANSCRIPTIONS_URL).mock(
                    return_value=httpx.Response(200, json=fixture)
                )
                transcribe(b"fake-audio")
                req = route.calls[0].request
                body = req.content.decode("latin-1")
        finally:
            _restore_singleton(original)

        assert "whisper-large-v3-turbo" in body
        assert "recording.wav" in body
        assert "audio/wav" in body

    def test_missing_api_key_raises(self):
        original = lib.groq_transcribe._client
        _reset_singleton()
        saved_key = os.environ.pop("GROQ_API_KEY", None)
        try:
            with pytest.raises(RuntimeError, match="GROQ_API_KEY not set"):
                _get_client()
        finally:
            if saved_key is not None:
                os.environ["GROQ_API_KEY"] = saved_key
            _restore_singleton(original)


@pytest.mark.skipif(REEF_TEST_MODE != "e2e", reason="E2E only")
class TestTranscribeE2E:
    def test_real_groq_whisper_call(self):
        # Minimal valid WAV header (44-byte RIFF/WAVE with empty PCM data)
        wav_header = (
            b"RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00"
            b"\x01\x00\x01\x00\x80\xbb\x00\x00\x00w\x01\x00"
            b"\x02\x00\x10\x00data\x00\x00\x00\x00"
        )
        original = lib.groq_transcribe._client
        _reset_singleton()
        try:
            result = transcribe(wav_header)
        finally:
            _restore_singleton(original)

        assert isinstance(result, str)
