"""Unit tests for lib/tts_client.py — Modal Kokoro TTS client."""
from unittest.mock import MagicMock, patch

import requests

from lib.tts_client import stream_tts


class TestStreamTts:
    def test_yields_pcm_chunks(self):
        mock_resp = MagicMock()
        mock_resp.iter_content.return_value = [b"chunk1", b"chunk2"]

        with patch("lib.tts_client.requests.post", return_value=mock_resp) as _:
            result = list(stream_tts("hi"))

        assert result == [b"chunk1", b"chunk2"]

    def test_request_params(self):
        mock_resp = MagicMock()
        mock_resp.iter_content.return_value = []

        with patch("lib.tts_client.requests.post", return_value=mock_resp) as mock_post:
            list(stream_tts("Hello"))

        mock_post.assert_called_once_with(
            mock_post.call_args[0][0],
            json={"text": "Hello", "voice": "af_heart", "speed": 0.95},
            stream=True,
            timeout=60,
        )

    def test_raises_on_http_error(self):
        mock_resp = MagicMock()
        mock_resp.raise_for_status.side_effect = requests.HTTPError("500 Server Error")

        with patch("lib.tts_client.requests.post", return_value=mock_resp):
            gen = stream_tts("hi")
            try:
                next(gen)
                assert False, "Expected HTTPError to be raised"
            except requests.HTTPError:
                pass
