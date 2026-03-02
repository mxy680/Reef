"""Lightweight helper to update document status_message via Supabase REST."""

import httpx

from app.config import settings


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
    status: str | None = None,
    page_count: int | None = None,
    problem_count: int | None = None,
    error_message: str | None = None,
    status_message: str | None = None,
):
    """PATCH multiple fields on a document row at once. Non-critical — never crashes."""
    if not document_id or not settings.supabase_service_role_key:
        return
    payload: dict = {}
    if status is not None:
        payload["status"] = status
    if page_count is not None:
        payload["page_count"] = page_count
    if problem_count is not None:
        payload["problem_count"] = problem_count
    if error_message is not None:
        payload["error_message"] = error_message
    if status_message is not None:
        payload["status_message"] = status_message
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
