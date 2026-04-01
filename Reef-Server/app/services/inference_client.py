"""Shared utility for parsing LLM responses."""

import re


def extract_json(text: str) -> str:
    """Extract JSON from a response that may contain markdown code fences or explanation."""
    match = re.search(r"```(?:json)?\s*\n?(.*?)\n?```", text, re.DOTALL)
    if match:
        return match.group(1).strip()
    match = re.search(r"\{[\s\S]*\}", text)
    if match:
        return match.group(0).strip()
    return text.strip()
