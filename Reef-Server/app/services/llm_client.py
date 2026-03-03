"""Thin wrapper for OpenAI-compatible APIs (OpenRouter, etc.)."""

import base64
import copy
import logging
import os
import time
from dataclasses import dataclass

from openai import (
    APIConnectionError,
    APITimeoutError,
    InternalServerError,
    OpenAI,
    RateLimitError,
)

logger = logging.getLogger(__name__)

_RETRYABLE = (APIConnectionError, APITimeoutError, RateLimitError, InternalServerError)


@dataclass
class LLMResult:
    """Result from an LLM call including usage metrics."""
    content: str
    input_tokens: int = 0
    output_tokens: int = 0


def _make_strict(schema: dict) -> dict:
    """Recursively patch a Pydantic JSON schema for OpenAI strict mode.

    - Adds additionalProperties: false to all objects
    - Ensures required includes all properties
    """
    schema = copy.deepcopy(schema)

    def _patch(node: dict) -> None:
        if "$ref" in node:
            ref = node["$ref"]
            node.clear()
            node["$ref"] = ref
            return
        if node.get("type") == "object" or "properties" in node:
            node["additionalProperties"] = False
            if "properties" in node:
                node["required"] = list(node["properties"].keys())
            for prop in node.get("properties", {}).values():
                _patch(prop)
        if "items" in node:
            _patch(node["items"])
        if "anyOf" in node:
            for variant in node["anyOf"]:
                _patch(variant)
        for ref in node.get("$defs", {}).values():
            _patch(ref)

    _patch(schema)
    return schema


class LLMClient:
    """Client for interacting with any OpenAI-compatible API."""

    def __init__(
        self,
        api_key: str | None = None,
        model: str = "gpt-4.1-nano",
        base_url: str | None = None,
    ):
        api_key = api_key or os.getenv("OPENAI_API_KEY")
        if not api_key:
            raise ValueError(
                "API key required. Set OPENAI_API_KEY env var or pass api_key."
            )
        kwargs: dict = {"api_key": api_key}
        if base_url:
            kwargs["base_url"] = base_url
        self.client = OpenAI(**kwargs)
        self.model = model

    def generate(
        self,
        prompt: str,
        images: list[bytes] | None = None,
        temperature: float | None = None,
        response_schema: dict | None = None,
        max_retries: int = 3,
        timeout: float = 120.0,
    ) -> LLMResult:
        content: list[dict] = [{"type": "text", "text": prompt}]
        if images:
            for img_bytes in images:
                b64 = base64.b64encode(img_bytes).decode()
                content.append({
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{b64}"},
                })

        kwargs: dict = {
            "model": self.model,
            "messages": [{"role": "user", "content": content}],
            "timeout": timeout,
        }
        if temperature is not None:
            kwargs["temperature"] = temperature
        if response_schema is not None:
            kwargs["response_format"] = {
                "type": "json_schema",
                "json_schema": {
                    "name": "response",
                    "strict": True,
                    "schema": _make_strict(response_schema),
                },
            }

        last_exc: Exception | None = None
        for attempt in range(1, max_retries + 1):
            try:
                response = self.client.chat.completions.create(**kwargs)
                usage = response.usage
                return LLMResult(
                    content=response.choices[0].message.content,
                    input_tokens=usage.prompt_tokens if usage else 0,
                    output_tokens=usage.completion_tokens if usage else 0,
                )
            except _RETRYABLE as e:
                last_exc = e
                if attempt < max_retries:
                    delay = min(2 ** attempt, 16)
                    logger.warning(
                        f"LLM attempt {attempt}/{max_retries} failed "
                        f"({type(e).__name__}): {e}. Retrying in {delay}s..."
                    )
                    time.sleep(delay)
                else:
                    logger.error(f"LLM call failed after {max_retries} attempts: {e}")
        raise last_exc  # type: ignore[misc]
