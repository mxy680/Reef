"""Test Mathpix Snip / Convert API for document reconstruction.

Usage:
    python test_snip.py <path_or_url>          # PDF, DOCX, image, etc.
    python test_snip.py document.pdf            # local file
    python test_snip.py https://example.com/doc.pdf  # URL

Outputs Mathpix Markdown (.mmd) to stdout and saves conversion results.
"""

import asyncio
import sys
import time
from pathlib import Path

import httpx

from app.config import settings

BASE_URL = "https://api.mathpix.com"


def _headers() -> dict[str, str]:
    return {
        "app_id": settings.mathpix_app_id,
        "app_key": settings.mathpix_app_key,
    }


async def submit_pdf(client: httpx.AsyncClient, source: str) -> str:
    """Submit a PDF for processing. Returns pdf_id."""
    headers = _headers()

    if source.startswith("http://") or source.startswith("https://"):
        headers["Content-Type"] = "application/json"
        resp = await client.post(
            f"{BASE_URL}/v3/pdf",
            headers=headers,
            json={
                "url": source,
                "conversion_formats": {"docx": True, "tex.zip": True},
                "math_inline_delimiters": ["$", "$"],
                "math_display_delimiters": ["$$", "$$"],
            },
        )
    else:
        # Local file upload
        path = Path(source)
        if not path.exists():
            print(f"Error: file not found: {source}")
            sys.exit(1)

        with open(path, "rb") as f:
            resp = await client.post(
                f"{BASE_URL}/v3/pdf",
                headers=headers,
                files={"file": (path.name, f, "application/pdf")},
                data={
                    "options_json": '{"conversion_formats": {"docx": true, "tex.zip": true}, '
                    '"math_inline_delimiters": ["$", "$"], '
                    '"math_display_delimiters": ["$$", "$$"]}'
                },
            )

    resp.raise_for_status()
    data = resp.json()
    pdf_id = data["pdf_id"]
    print(f"Submitted — pdf_id: {pdf_id}")
    return pdf_id


async def poll_status(client: httpx.AsyncClient, pdf_id: str) -> dict:
    """Poll until processing completes. Returns final status."""
    headers = _headers()
    while True:
        resp = await client.get(f"{BASE_URL}/v3/pdf/{pdf_id}", headers=headers)
        resp.raise_for_status()
        data = resp.json()

        status = data.get("status", "unknown")
        pct = data.get("percent_done", 0)
        pages_done = data.get("num_pages_completed", 0)
        pages_total = data.get("num_pages", "?")
        print(f"  Status: {status} — {pct}% ({pages_done}/{pages_total} pages)")

        if status == "completed":
            return data
        if status == "error":
            print(f"Error: {data}")
            sys.exit(1)

        await asyncio.sleep(3)


async def download_result(client: httpx.AsyncClient, pdf_id: str, ext: str) -> str:
    """Download a conversion result by extension (.mmd, .docx, .tex.zip, etc.)."""
    headers = _headers()
    resp = await client.get(f"{BASE_URL}/v3/pdf/{pdf_id}{ext}", headers=headers)
    resp.raise_for_status()
    return resp.text


async def main():
    if len(sys.argv) < 2:
        print("Usage: python test_snip.py <path_or_url>")
        sys.exit(1)

    source = sys.argv[1]
    print(f"Processing: {source}\n")

    start = time.time()

    async with httpx.AsyncClient(timeout=60.0) as client:
        pdf_id = await submit_pdf(client, source)

        print("\nPolling for completion...")
        status = await poll_status(client, pdf_id)

        elapsed = time.time() - start
        print(f"\nCompleted in {elapsed:.1f}s")
        print(f"Pages: {status.get('num_pages', '?')}")

        # Download Mathpix Markdown
        print("\n" + "=" * 60)
        print("MATHPIX MARKDOWN OUTPUT")
        print("=" * 60 + "\n")
        mmd = await download_result(client, pdf_id, ".mmd")
        print(mmd)

        # Save to file
        out_path = Path(f"data/{pdf_id}.mmd")
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(mmd)
        print(f"\nSaved to {out_path}")


if __name__ == "__main__":
    asyncio.run(main())
