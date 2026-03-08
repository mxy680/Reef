"""Mathpix PDF OCR client — submit, poll, download MMD + images.

Uses httpx.AsyncClient for all HTTP calls. The main entry point is
``process_pdf(pdf_bytes)`` which returns ``(mmd_text, {filename: image_bytes})``.
"""

import asyncio
import logging
import re

import httpx

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------------


class MathpixError(Exception):
    """General Mathpix API error."""


class MathpixTimeoutError(MathpixError):
    """Polling timed out waiting for Mathpix to finish processing."""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_IMAGE_URL_RE = re.compile(r"!\[[^\]]*\]\((https://cdn\.mathpix\.com/[^)]+)\)")


def extract_image_urls(mmd: str) -> list[str]:
    """Extract all CDN image URLs from Mathpix MMD text."""
    return _IMAGE_URL_RE.findall(mmd)


def mmd_url_to_filename(url: str) -> str:
    """Convert a Mathpix CDN URL to a local-friendly filename.

    E.g. ``https://cdn.mathpix.com/cropped/2024_abc123.jpg?...``
    -> ``mathpix_2024_abc123.jpg``
    """
    # Strip query params
    path = url.split("?")[0]
    # Get the last path segment
    basename = path.rsplit("/", 1)[-1]
    return f"mathpix_{basename}"


# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------


class MathpixClient:
    """Async client for the Mathpix PDF API."""

    API_BASE = "https://api.mathpix.com"

    def __init__(self, app_id: str, app_key: str):
        self._headers = {
            "app_id": app_id,
            "app_key": app_key,
        }

    async def submit_pdf(self, pdf_bytes: bytes) -> str:
        """Submit a PDF for processing. Returns the ``pdf_id``."""
        url = f"{self.API_BASE}/v3/pdf"
        options = {
            "math_inline_delimiters": ["$", "$"],
            "math_display_delimiters": ["\\[", "\\]"],
            "rm_spaces": True,
        }
        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.post(
                url,
                headers=self._headers,
                files={"file": ("document.pdf", pdf_bytes, "application/pdf")},
                data={"options_json": _json_dumps(options)},
            )
            resp.raise_for_status()
            data = resp.json()
        pdf_id = data.get("pdf_id")
        if not pdf_id:
            raise MathpixError(f"No pdf_id in response: {data}")
        logger.info(f"  [mathpix] Submitted PDF, got pdf_id={pdf_id}")
        return pdf_id

    async def poll_until_complete(
        self,
        pdf_id: str,
        *,
        interval: float = 3.0,
        max_attempts: int = 100,
    ) -> None:
        """Poll until the PDF processing completes or errors."""
        url = f"{self.API_BASE}/v3/pdf/{pdf_id}"
        async with httpx.AsyncClient(timeout=30) as client:
            for attempt in range(1, max_attempts + 1):
                resp = await client.get(url, headers=self._headers)
                resp.raise_for_status()
                data = resp.json()
                status = data.get("status")

                if status == "completed":
                    logger.info(
                        f"  [mathpix] PDF {pdf_id} completed after {attempt} polls"
                    )
                    return
                if status == "error":
                    raise MathpixError(
                        f"Mathpix processing error: {data.get('error', data)}"
                    )

                await asyncio.sleep(interval)

        raise MathpixTimeoutError(
            f"Mathpix PDF {pdf_id} did not complete after {max_attempts} polls "
            f"({max_attempts * interval:.0f}s)"
        )

    async def download_mmd(self, pdf_id: str) -> str:
        """Download the MMD output for a completed PDF."""
        url = f"{self.API_BASE}/v3/pdf/{pdf_id}.mmd"
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.get(url, headers=self._headers)
            resp.raise_for_status()
            return resp.text

    async def download_image(self, url: str) -> bytes:
        """Fetch a single image from the Mathpix CDN."""
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.get(url)
            resp.raise_for_status()
            return resp.content

    async def process_pdf(
        self, pdf_bytes: bytes
    ) -> tuple[str, dict[str, bytes]]:
        """Full flow: submit -> poll -> download MMD + images.

        Returns ``(mmd_text, {filename: image_bytes})``.
        """
        pdf_id = await self.submit_pdf(pdf_bytes)
        await self.poll_until_complete(pdf_id)
        mmd = await self.download_mmd(pdf_id)

        # Download all referenced images in parallel (bounded concurrency)
        image_urls = extract_image_urls(mmd)
        images: dict[str, bytes] = {}
        if image_urls:
            sem = asyncio.Semaphore(8)

            async def _fetch(img_url: str) -> tuple[str, bytes]:
                async with sem:
                    data = await self.download_image(img_url)
                    return mmd_url_to_filename(img_url), data

            results = await asyncio.gather(
                *[_fetch(u) for u in image_urls], return_exceptions=True
            )
            for r in results:
                if isinstance(r, Exception):
                    logger.warning(f"  [mathpix] Image download failed: {r}")
                else:
                    images[r[0]] = r[1]

        logger.info(
            f"  [mathpix] PDF {pdf_id}: {len(mmd)} chars MMD, "
            f"{len(images)} images downloaded"
        )
        return mmd, images


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

import json as _json_module


def _json_dumps(obj: object) -> str:
    return _json_module.dumps(obj)
