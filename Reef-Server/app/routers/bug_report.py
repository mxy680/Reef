"""POST /api/bug-report — submit a bug report from the canvas."""

import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings

log = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["api"])


class BugReportRequest(BaseModel):
    description: str = Field(..., min_length=1, max_length=2000)
    document_id: str | None = None
    question_label: str | None = None


@router.post("/bug-report", status_code=201)
async def submit_bug_report(
    body: BugReportRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.supabase_service_role_key:
        raise HTTPException(status_code=503, detail="Database not configured")

    payload = {
        "user_id": user.id,
        "description": body.description,
        "document_id": body.document_id,
        "question_label": body.question_label,
    }

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            f"{settings.supabase_url}/rest/v1/bug_reports",
            json=payload,
            headers={
                "apikey": settings.supabase_service_role_key,
                "Authorization": f"Bearer {settings.supabase_service_role_key}",
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            },
        )

    if resp.status_code not in (200, 201):
        log.warning(f"[bug-report] Insert failed: {resp.status_code} {resp.text[:200]}")
        raise HTTPException(status_code=502, detail="Failed to save bug report")

    log.info(f"[bug-report] Submitted by {user.id}: {body.description[:60]}")
    return {"status": "ok"}
