"""
Modal serverless GPU endpoint for Surya layout detection.

Deploy: modal deploy modal/surya_layout.py
Test:   curl -X POST <url> -H 'Content-Type: application/json' -d '{"images":["<base64_jpeg>"]}'
"""

import modal

app = modal.App("reef-surya-layout")

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("torch", extra_index_url="https://download.pytorch.org/whl/cu121")
    .pip_install("transformers>=4.40.0,<5.0.0")
    .pip_install("surya-ocr>=0.8.0", "requests", "fastapi[standard]")
    .run_commands(
        # Pre-download the layout model into the image
        'python -c "'
        "from surya.settings import settings; "
        "from surya.common.s3 import download_directory; "
        "import os; "
        "ckpt = settings.LAYOUT_MODEL_CHECKPOINT.replace('s3://', ''); "
        "local = os.path.join(settings.MODEL_CACHE_DIR, ckpt); "
        "os.makedirs(local, exist_ok=True); "
        "download_directory(ckpt, local); "
        "print(f'Downloaded {ckpt} to {local}')\""
    )
)


@app.cls(
    image=image,
    gpu="T4",
    scaledown_window=300,
)
@modal.concurrent(max_inputs=1)
class SuryaLayout:
    @modal.enter()
    def load_model(self):
        from surya.foundation import FoundationPredictor
        from surya.layout import LayoutPredictor
        from surya.settings import settings

        self.foundation = FoundationPredictor(checkpoint=settings.LAYOUT_MODEL_CHECKPOINT)
        self.predictor = LayoutPredictor(self.foundation)
        print("Surya layout model loaded on GPU")

    @modal.fastapi_endpoint(method="POST")
    def predict(self, request: dict):
        import base64
        import io

        from PIL import Image

        raw_images = request.get("images", [])
        if not raw_images:
            return {"error": "No images provided"}

        # Decode base64 JPEG images
        images = []
        for b64 in raw_images:
            img_bytes = base64.b64decode(b64)
            img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
            images.append(img)

        # Run Surya layout detection
        results = self.predictor(images)

        # Serialize results
        pages = []
        for result in results:
            bboxes = []
            for box in result.bboxes:
                bboxes.append(
                    {
                        "bbox": list(box.bbox),
                        "label": box.label,
                        "confidence": getattr(box, "confidence", 1.0),
                    }
                )
            pages.append({"bboxes": bboxes})

        return {"pages": pages}
