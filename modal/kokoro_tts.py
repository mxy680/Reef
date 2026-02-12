"""
Modal serverless GPU endpoint for Kokoro TTS with PCM streaming.

Deploy: modal deploy modal/kokoro_tts.py
Test:   curl -X POST <url> -d '{"text":"Hello world"}' --output test.pcm
        ffplay -f s16le -ar 24000 -ac 1 test.pcm
"""

import modal

app = modal.App("reef-kokoro-tts")

image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("espeak-ng")
    .pip_install("torch", extra_index_url="https://download.pytorch.org/whl/cu121")
    .pip_install("kokoro>=0.9.4", "fastapi[standard]")
    .run_commands(
        # Pre-download the Kokoro model into the image
        "python -c \"from kokoro import KPipeline; p = KPipeline(lang_code='a'); print('Kokoro model cached')\""
    )
)


@app.cls(
    image=image,
    gpu="T4",
    scaledown_window=300,
)
@modal.concurrent(max_inputs=1)
class KokoroTTS:
    @modal.enter()
    def load_model(self):
        from kokoro import KPipeline

        self.pipeline = KPipeline(lang_code="a")
        print("Kokoro TTS pipeline loaded on GPU")

    @modal.fastapi_endpoint(method="POST")
    def synthesize(self, request: dict):
        """Synthesize text to speech, streaming raw PCM int16 chunks."""
        import io
        import numpy as np
        from fastapi.responses import StreamingResponse

        text = request.get("text", "")
        voice = request.get("voice", "af_heart")
        speed = request.get("speed", 0.95)

        if not text:
            return {"error": "No text provided"}

        def generate_pcm():
            for _, _, audio in self.pipeline(text, voice=voice, speed=speed):
                # audio may be a torch Tensor on GPU — move to CPU numpy first
                if hasattr(audio, 'cpu'):
                    audio = audio.cpu().numpy()
                pcm = (audio * 32767).astype(np.int16).tobytes()
                yield pcm

        return StreamingResponse(
            generate_pcm(),
            media_type="application/octet-stream",
            headers={
                "X-Sample-Rate": "24000",
                "X-Channels": "1",
                "X-Sample-Width": "2",
            },
        )
