"""Unit tests for lib/tts_client.py — Modal Kokoro TTS client."""
import json

import pytest
import requests
import responses

from tests.conftest import REEF_TEST_MODE
from tests.helpers import load_fixture
from lib.tts_client import stream_tts

TTS_URL = "https://fake-modal-tts.example.com/tts"


@pytest.mark.skipif(REEF_TEST_MODE != "contract", reason="Contract tests only")
class TestStreamTts:
    @responses.activate
    def test_yields_pcm_chunks(self, monkeypatch):
        monkeypatch.setattr("lib.tts_client.MODAL_TTS_URL", TTS_URL)
        pcm_bytes = load_fixture("modal_tts.bin")
        responses.add(responses.POST, TTS_URL, body=pcm_bytes, status=200)

        result = b"".join(stream_tts("hi"))

        assert result == pcm_bytes

    @responses.activate
    def test_request_params(self, monkeypatch):
        monkeypatch.setattr("lib.tts_client.MODAL_TTS_URL", TTS_URL)
        responses.add(responses.POST, TTS_URL, body=b"", status=200)

        list(stream_tts("Hello", voice="af_heart", speed=0.95))

        sent = json.loads(responses.calls[0].request.body)
        assert sent == {"text": "Hello", "voice": "af_heart", "speed": 0.95}

    @responses.activate
    def test_raises_on_http_error(self, monkeypatch):
        monkeypatch.setattr("lib.tts_client.MODAL_TTS_URL", TTS_URL)
        responses.add(responses.POST, TTS_URL, status=500)

        with pytest.raises(requests.HTTPError):
            list(stream_tts("hi"))
