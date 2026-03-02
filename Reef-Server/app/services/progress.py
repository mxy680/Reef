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
