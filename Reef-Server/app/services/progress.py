"""Lightweight helper to update document status_message via Supabase REST."""

import asyncio
import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_CRITICAL_STATUSES = {"completed", "failed"}

_UNSET = object()  # sentinel — distinguishes "not provided" from explicit None


async def update_progress(document_id: str, message: str | None):
    """PATCH status_message on the documents table. Non-critical — never crashes the pipeline."""
    if not document_id or not settings.supabase_service_role_key:
        return
    try:
        url = f"{settings.supabase_url}/rest/v1/documents?id=eq.{document_id}"
        headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
        async with httpx.AsyncClient() as client:
            await client.patch(url, json={"status_message": message}, headers=headers)
    except Exception as e:
        print(f"  [progress] Failed to update status_message: {e}")


async def update_document_status(
    document_id: str,
    *,
    status=_UNSET,
    page_count=_UNSET,
    problem_count=_UNSET,
    error_message=_UNSET,
    status_message=_UNSET,
    input_tokens=_UNSET,
    output_tokens=_UNSET,
    llm_calls=_UNSET,
    gpu_seconds=_UNSET,
    pipeline_seconds=_UNSET,
    cost_cents=_UNSET,
    question_pages=_UNSET,
):
    """PATCH multiple fields on a document row at once.

    Pass ``None`` explicitly to set a column to NULL (e.g. clear status_message).
    Omit a parameter to leave that column untouched.  Non-critical — never crashes.
    """
    if not document_id or not settings.supabase_service_role_key:
        return
    payload: dict = {}
    if status is not _UNSET:
        payload["status"] = status
    if page_count is not _UNSET:
        payload["page_count"] = page_count
    if problem_count is not _UNSET:
        payload["problem_count"] = problem_count
    if error_message is not _UNSET:
        payload["error_message"] = error_message
    if status_message is not _UNSET:
        payload["status_message"] = status_message
    if input_tokens is not _UNSET:
        payload["input_tokens"] = input_tokens
    if output_tokens is not _UNSET:
        payload["output_tokens"] = output_tokens
    if llm_calls is not _UNSET:
        payload["llm_calls"] = llm_calls
    if gpu_seconds is not _UNSET:
        payload["gpu_seconds"] = gpu_seconds
    if pipeline_seconds is not _UNSET:
        payload["pipeline_seconds"] = pipeline_seconds
    if cost_cents is not _UNSET:
        payload["cost_cents"] = cost_cents
    if question_pages is not _UNSET:
        payload["question_pages"] = question_pages
    if not payload:
        return

    is_critical = status in _CRITICAL_STATUSES
    max_attempts = 3 if is_critical else 1

    url = f"{settings.supabase_url}/rest/v1/documents?id=eq.{document_id}"
    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }

    for attempt in range(1, max_attempts + 1):
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.patch(url, json=payload, headers=headers, timeout=10)
                resp.raise_for_status()
            return
        except Exception as e:
            if attempt < max_attempts:
                delay = 2 ** attempt
                logger.warning(
                    f"Status update attempt {attempt}/{max_attempts} failed for "
                    f"{document_id} (status={status}): {e}. Retrying in {delay}s..."
                )
                await asyncio.sleep(delay)
            else:
                if is_critical:
                    logger.error(
                        f"CRITICAL: Failed to set document {document_id} to "
                        f"'{status}' after {max_attempts} attempts: {e}"
                    )
                else:
                    logger.warning(f"Failed to update document status: {e}")
