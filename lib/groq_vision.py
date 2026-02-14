"""Groq Llama 4 Maverick vision client for LaTeX transcription."""

import base64
import os

from openai import OpenAI

_client: OpenAI | None = None


def _get_client() -> OpenAI:
    global _client
    if _client is None:
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise RuntimeError("GROQ_API_KEY not set")
        _client = OpenAI(api_key=api_key, base_url="https://api.groq.com/openai/v1")
    return _client


_BASE_PROMPT = """\
Transcribe this handwritten math into LaTeX. Return only the LaTeX expression, no explanation or wrapping.

Common handwriting ambiguities — prefer these interpretations:
- "2" not "z" (handwritten 2 often looks like z)
- "x" not "×" for variables
- "1" not "l" for the digit one
- "0" not "O" for the digit zero
- "5" not "S" for the digit five
- Assume standard math notation: superscripts are exponents, subscripts are indices"""

_CONTEXT_TEMPLATE = """

The student is working on this problem:
{problem_context}

Use this context to disambiguate characters and notation."""


def transcribe_strokes_image(image_bytes: bytes, problem_context: str = "") -> str:
    """Send stroke image to Groq Llama 4 Maverick, return LaTeX transcription."""
    client = _get_client()
    b64 = base64.b64encode(image_bytes).decode("ascii")
    data_url = f"data:image/png;base64,{b64}"

    prompt = _BASE_PROMPT
    if problem_context:
        prompt += _CONTEXT_TEMPLATE.format(problem_context=problem_context)

    response = client.chat.completions.create(
        model="meta-llama/llama-4-maverick-17b-128e-instruct",
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            }
        ],
        max_tokens=256,
    )
    return response.choices[0].message.content.strip()
