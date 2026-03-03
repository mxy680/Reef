"""Lightweight helper to update document status_message via Supabase REST."""

import httpx

from app.config import settings

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
    if not payload:
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
            await client.patch(url, json=payload, headers=headers)
    except Exception as e:
        print(f"  [progress] Failed to update document status: {e}")
