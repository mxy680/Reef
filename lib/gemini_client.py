"""Thin wrapper for Gemini API using google.genai SDK."""

import os

from google import genai
from google.genai import types


class GeminiClient:
    """Client for interacting with the Gemini API."""

    def __init__(self, api_key: str | None = None, model: str = "gemini-2.5-flash"):
        """
        Initialize the Gemini client.

        Args:
            api_key: Gemini API key. If None, uses GEMINI_API_KEY env var.
            model: Model name to use.
        """
        api_key = api_key or os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError(
                "Gemini API key required. Set GEMINI_API_KEY env var or pass api_key."
            )
        self.client = genai.Client(api_key=api_key)
        self.model = model

    def generate(
        self,
        prompt: str,
        images: list[bytes] | None = None,
        response_mime_type: str | None = None,
        response_schema: dict | None = None,
        temperature: float | None = None,
    ) -> str:
        """
        Generate text response, optionally with images.

        Args:
            prompt: Text prompt to send.
            images: Optional list of image bytes to include.
            response_mime_type: Optional MIME type for response (e.g., "application/json").
            response_schema: Optional JSON schema for structured output. Auto-sets response_mime_type to application/json.
            temperature: Sampling temperature (0.0-2.0). Higher values reduce recitation filtering.

        Returns:
            Generated text response.
        """
        # Build content parts
        contents: list = [prompt]
        if images:
            for img_bytes in images:
                contents.append(
                    types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg")
                )

        # Auto-set JSON mime type when schema is provided
        if response_schema and not response_mime_type:
            response_mime_type = "application/json"

        # Build generation config
        config = types.GenerateContentConfig(
            temperature=temperature,
            response_mime_type=response_mime_type,
            response_schema=response_schema,
        )

        response = self.client.models.generate_content(
            model=self.model,
            contents=contents,
            config=config,
        )

        # Log blocked responses for debugging
        if not response.text and response.candidates:
            candidate = response.candidates[0]
            print(f"  [gemini] Empty response — finish_reason={candidate.finish_reason}")
            if candidate.safety_ratings:
                for r in candidate.safety_ratings:
                    if r.blocked or r.probability != "NEGLIGIBLE":
                        print(f"  [gemini]   {r.category}: {r.probability} (blocked={r.blocked})")

        return response.text
