"""
HTTP streaming client for Modal-hosted Kokoro TTS.

Streams raw PCM int16 chunks from the Modal GPU endpoint.
No torch/kokoro/soundfile dependencies needed.
"""

import os
from typing import Generator

import requests

MODAL_TTS_URL = os.environ.get("MODAL_TTS_URL", "")


def stream_tts(
    text: str,
    voice: str = "af_heart",
    speed: float = 0.95,
) -> Generator[bytes, None, None]:
    """POST to Modal TTS endpoint, yield PCM int16 chunks.

    Each chunk is raw PCM: 24kHz, mono, 16-bit signed little-endian.
    """
    resp = requests.post(
        MODAL_TTS_URL,
        json={"text": text, "voice": voice, "speed": speed},
        stream=True,
        timeout=60,
    )
    resp.raise_for_status()

    for chunk in resp.iter_content(chunk_size=8192):
        if chunk:
            yield chunk
