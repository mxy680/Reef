"""Client for the Reef inference API (Claude Opus 4.6 via inference.studyreef.com).

Shared across answer key generation, reconstruction, and any other module
that needs to call the self-hosted inference endpoint.
"""

import json
import logging
import re

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


async def call_inference_api(prompt: str, images: list[bytes] | None = None) -> tuple[str, str]:
    """Call the Reef inference API (Claude Opus 4.6) via SSE streaming.

    Args:
        prompt: The text prompt.
        images: Optional list of image bytes (JPEG/PNG) to include as vision input.

    Returns (content, model_name).
    """
    import base64 as _b64

    model_name = "claude-opus-4-6"

    # Images require extra turns: 1 turn to Read the image file, 1+ to respond
    max_turns = 3 if images else 1
    body: dict = {"prompt": prompt, "max_turns": max_turns}
    if images:
        body["images"] = [
            {"data": _b64.b64encode(img).decode(), "media_type": "image/jpeg"}
            for img in images
        ]

    # Vision requests with large images need more time (Opus reasoning)
    read_timeout = 120.0 if images else 60.0
    timeout = httpx.Timeout(connect=10.0, read=read_timeout, write=10.0, pool=5.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        async with client.stream(
            "POST",
            f"{settings.reef_inference_url}/v1/chat",
            headers={
                "Authorization": f"Bearer {settings.reef_inference_token}",
                "Content-Type": "application/json",
            },
            json=body,
        ) as resp:
            resp.raise_for_status()
            result_text = ""
            async for line in resp.aiter_lines():
                if not line.startswith("data: "):
                    continue
                payload = line[6:]
                if payload == "[DONE]":
                    break
                try:
                    event = json.loads(payload)
                    event_type = event.get("type", "")
                    if event_type == "done":
                        inner = event.get("data", {})
                        result_text = inner.get("result", "")
                        if inner.get("is_error"):
                            logger.warning(f"[inference] API returned error: {inner.get('result', '')[:200]}")
                        break
                    elif event_type == "error":
                        logger.warning(f"[inference] Stream error event: {payload[:200]}")
                        break
                except json.JSONDecodeError:
                    logger.debug(f"[inference] Malformed SSE line: {payload[:80]}")
                    continue

    if not result_text:
        raise RuntimeError("Inference API returned no result")

    return result_text, model_name


def extract_json(text: str) -> str:
    """Extract JSON from a response that may contain markdown code fences or explanation."""
    match = re.search(r"```(?:json)?\s*\n?(.*?)\n?```", text, re.DOTALL)
    if match:
        return match.group(1).strip()
    match = re.search(r"\{[\s\S]*\}", text)
    if match:
        return match.group(0).strip()
    return text.strip()
