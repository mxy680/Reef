"""Kokoro TTS integration for voice feedback.

Singleton pipeline with async interface. Runs synthesis in a thread
to avoid blocking the event loop.
"""

import asyncio
import io
import os
import threading

import soundfile as sf

_pipeline = None
_init_lock = threading.Lock()
_async_lock = asyncio.Lock()

KOKORO_VOICE = os.getenv("KOKORO_VOICE", "af_heart")
KOKORO_SPEED = float(os.getenv("KOKORO_SPEED", "0.95"))


def _get_pipeline():
    """Lazy-init the Kokoro pipeline (singleton, thread-safe via double-check locking)."""
    global _pipeline
    if _pipeline is None:
        with _init_lock:
            if _pipeline is None:
                from kokoro import KPipeline
                _pipeline = KPipeline(lang_code="a")
                print(f"[TTS] Kokoro pipeline initialized (voice={KOKORO_VOICE})")
    return _pipeline


def _synthesize_sync(text: str, voice: str, speed: float) -> bytes:
    """Synchronous TTS synthesis. Returns WAV bytes (24kHz 16-bit mono)."""
    pipeline = _get_pipeline()

    # Generate audio samples
    samples = None
    for _, _, audio in pipeline(text, voice=voice, speed=speed):
        if samples is None:
            samples = audio
        else:
            import numpy as np
            samples = np.concatenate([samples, audio])

    if samples is None:
        raise RuntimeError("Kokoro produced no audio output")

    # Encode as WAV
    buf = io.BytesIO()
    sf.write(buf, samples, 24000, format="WAV", subtype="PCM_16")
    return buf.getvalue()


async def synthesize(
    text: str,
    voice: str | None = None,
    speed: float | None = None,
) -> bytes:
    """Async TTS synthesis. Returns WAV bytes.

    Thread-safe: uses a lock to prevent concurrent Kokoro access.
    """
    voice = voice or KOKORO_VOICE
    speed = speed or KOKORO_SPEED

    async with _async_lock:
        return await asyncio.to_thread(_synthesize_sync, text, voice, speed)
