"""
HTTP client for Modal-hosted Surya layout detection.

Drop-in replacement for local Surya inference — returns dataclasses with
the same .bbox and .label interface that the rest of the pipeline expects.
"""

import base64
import io
import os
from dataclasses import dataclass, field

import requests
from PIL import Image


@dataclass
class LayoutBox:
    """Drop-in for Surya's LayoutBox."""

    bbox: list[float]
    label: str
    confidence: float = 1.0


@dataclass
class LayoutResult:
    """Drop-in for Surya's LayoutResult."""

    bboxes: list[LayoutBox] = field(default_factory=list)


def detect_layout(images: list[Image.Image]) -> list[LayoutResult]:
    """Send images to Modal Surya endpoint and return LayoutResults.

    Encodes each PIL Image as base64 JPEG, POSTs to the Modal endpoint,
    and parses the response into LayoutResult/LayoutBox dataclasses.
    """
    url = os.environ["MODAL_SURYA_URL"]

    # Encode images as base64 JPEG
    encoded = []
    for img in images:
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        encoded.append(base64.b64encode(buf.getvalue()).decode())

    # POST to Modal endpoint
    resp = requests.post(url, json={"images": encoded}, timeout=300)
    resp.raise_for_status()
    data = resp.json()

    # Parse response into dataclasses
    results = []
    for page in data["pages"]:
        bboxes = [
            LayoutBox(
                bbox=b["bbox"],
                label=b["label"],
                confidence=b.get("confidence", 1.0),
            )
            for b in page["bboxes"]
        ]
        results.append(LayoutResult(bboxes=bboxes))

    return results
