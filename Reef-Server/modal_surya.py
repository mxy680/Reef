"""Modal serverless GPU function for Surya layout detection.

Deploy: modal deploy modal_surya.py
Test:   modal serve modal_surya.py
"""

import modal

app = modal.App("reef-surya")

surya_image = (
    modal.Image.debian_slim(python_version="3.12")
    .pip_install(
        "surya-ocr",
        "Pillow",
        "torch",
    )
    .run_commands(
        # Pre-download Surya model weights at build time
        "python -c '"
        "from surya.settings import settings; "
        "from surya.foundation import FoundationPredictor; "
        "from surya.layout import LayoutPredictor; "
        "fp = FoundationPredictor(checkpoint=settings.LAYOUT_MODEL_CHECKPOINT); "
        "lp = LayoutPredictor(fp); "
        "print(\"Surya models cached\")"
        "'"
    )
)


@app.cls(
    image=surya_image,
    gpu="T4",
    timeout=300,
    scaledown_window=120,
)
class SuryaLayout:
    @modal.enter()
    def setup(self):
        from surya.foundation import FoundationPredictor
        from surya.layout import LayoutPredictor
        from surya.settings import settings

        print("[SuryaLayout] Loading models...")
        self.foundation = FoundationPredictor(
            checkpoint=settings.LAYOUT_MODEL_CHECKPOINT
        )
        self.predictor = LayoutPredictor(self.foundation)
        print("[SuryaLayout] Ready!")

    @modal.method()
    def detect_layout(self, image_bytes_list: list[bytes]) -> list[list[dict]]:
        """Run layout detection on a list of page images.

        Args:
            image_bytes_list: List of JPEG/PNG image bytes (one per page).

        Returns:
            List of pages, each containing a list of bboxes:
            [{"bbox": [x1, y1, x2, y2], "label": str}, ...]
        """
        from PIL import Image
        import io

        images = []
        for img_bytes in image_bytes_list:
            img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
            images.append(img)

        results = self.predictor(images)

        # Serialize to plain dicts (Modal can't transfer Surya objects)
        output = []
        for page_result in results:
            page_bboxes = []
            for block in page_result.bboxes:
                page_bboxes.append({
                    "bbox": list(block.bbox),
                    "label": block.label,
                })
            output.append(page_bboxes)

        return output
