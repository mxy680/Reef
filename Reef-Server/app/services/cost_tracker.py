"""Per-user API cost tracking — fire-and-forget ledger to Supabase.

Every API call (LLM, Mathpix, TTS) records a cost event with pre-calculated
USD. Never raises — all errors are logged and suppressed.
"""

import asyncio
import logging
from typing import Any

import httpx

from app.config import settings

log = logging.getLogger(__name__)

# Rates: (input_per_token, output_per_token) in USD
MODEL_RATES: dict[str, tuple[float, float]] = {
    "google/gemini-3-flash-preview": (0.50 / 1_000_000, 3.00 / 1_000_000),
    "google/gemini-2.5-flash": (0.15 / 1_000_000, 0.60 / 1_000_000),
    "deepseek/deepseek-r1": (0.55 / 1_000_000, 2.19 / 1_000_000),
    "deepseek/deepseek-v3.2": (0.25 / 1_000_000, 0.40 / 1_000_000),
}
_DEFAULT_RATE = (0.50 / 1_000_000, 3.00 / 1_000_000)

# Fixed costs per external API call
MATHPIX_PDF_PER_PAGE = 0.01
MATHPIX_STROKES_PER_REQUEST = 0.004
ELEVENLABS_PER_CHAR = 0.0003  # ~$0.30/1K chars for Flash v2.5


def calculate_llm_cost(model: str, input_tokens: int, output_tokens: int) -> float:
    """Calculate USD cost for an LLM call."""
    in_rate, out_rate = MODEL_RATES.get(model, _DEFAULT_RATE)
    return input_tokens * in_rate + output_tokens * out_rate


def _headers() -> dict[str, str]:
    return {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }


async def record_cost(
    user_id: str,
    feature: str,
    provider: str,
    cost_dollars: float,
    *,
    model: str | None = None,
    input_tokens: int = 0,
    output_tokens: int = 0,
    metadata: dict[str, Any] | None = None,
) -> None:
    """Insert a cost record into api_costs. Never raises."""
    if not settings.supabase_service_role_key:
        return
    try:
        url = f"{settings.supabase_url}/rest/v1/api_costs"
        row: dict[str, Any] = {
            "user_id": user_id,
            "feature": feature,
            "provider": provider,
            "cost_dollars": round(cost_dollars, 6),
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
        }
        if model:
            row["model"] = model
        if metadata:
            row["metadata"] = metadata
        async with httpx.AsyncClient(timeout=10) as client:
            await client.post(url, json=row, headers=_headers())
    except Exception as e:
        log.warning(f"[cost-tracker] Failed to record cost: {e}")


async def record_llm_cost(
    user_id: str,
    feature: str,
    model: str,
    input_tokens: int,
    output_tokens: int,
    *,
    metadata: dict[str, Any] | None = None,
) -> None:
    """Calculate and record LLM cost from token counts."""
    cost = calculate_llm_cost(model, input_tokens, output_tokens)
    await record_cost(
        user_id, feature, "openrouter", cost,
        model=model, input_tokens=input_tokens, output_tokens=output_tokens,
        metadata=metadata,
    )


def fire_cost(coro) -> None:
    """Fire-and-forget a cost recording coroutine."""
    async def _safe():
        try:
            await coro
        except Exception as e:
            log.warning(f"[cost-tracker] {e}")
    asyncio.create_task(_safe())
