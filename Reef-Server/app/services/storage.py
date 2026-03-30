"""Supabase Storage helpers — download/upload document PDFs via REST."""

import httpx

from app.config import settings


async def download_document_pdf(user_id: str, document_id: str) -> bytes:
    """Download ``{userId}/{docId}/original.pdf`` from the ``documents`` bucket."""
    path = f"{user_id}/{document_id}/original.pdf"
    url = f"{settings.supabase_url}/storage/v1/object/documents/{path}"
    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
    }
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=headers, timeout=60)
        resp.raise_for_status()
        return resp.content


async def upload_question_figure(
    document_id: str, filename: str, image_bytes: bytes
) -> str:
    """Upload a question figure to ``{docId}/figures/{filename}`` and return the storage URL."""
    path = f"{document_id}/figures/{filename}"
    url = f"{settings.supabase_url}/storage/v1/object/documents/{path}"
    # Detect content type from extension
    ct = "image/jpeg" if filename.lower().endswith((".jpg", ".jpeg")) else "image/png"
    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": ct,
        "x-upsert": "true",
    }
    async with httpx.AsyncClient() as client:
        resp = await client.put(url, content=image_bytes, headers=headers, timeout=30)
        resp.raise_for_status()
    return url


async def upload_document_pdf(
    user_id: str, document_id: str, pdf_bytes: bytes
) -> None:
    """Upload ``output.pdf`` to ``{userId}/{docId}/output.pdf`` (upserts)."""
    path = f"{user_id}/{document_id}/output.pdf"
    url = f"{settings.supabase_url}/storage/v1/object/documents/{path}"
    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/pdf",
        "x-upsert": "true",
    }
    async with httpx.AsyncClient() as client:
        resp = await client.put(url, content=pdf_bytes, headers=headers, timeout=120)
        resp.raise_for_status()
