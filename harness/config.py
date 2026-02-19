"""Harness configuration — DB URL, server URL, evaluator LLM settings."""

import os


def get_database_url() -> str:
    url = os.getenv("DATABASE_URL", "")
    if not url:
        raise RuntimeError("DATABASE_URL not set")
    return url


def get_server_url() -> str:
    return os.getenv("HARNESS_SERVER_URL", "http://localhost:8000")


def get_evaluator_api_key() -> str:
    key = os.getenv("HARNESS_EVALUATOR_KEY", "") or os.getenv("OPENROUTER_API_KEY", "")
    if not key:
        raise RuntimeError(
            "Set HARNESS_EVALUATOR_KEY or OPENROUTER_API_KEY for the evaluator LLM"
        )
    return key


def get_evaluator_model() -> str:
    return os.getenv("HARNESS_EVALUATOR_MODEL", "google/gemini-2.5-flash-preview")


EVALUATOR_BASE_URL = "https://openrouter.ai/api/v1"
