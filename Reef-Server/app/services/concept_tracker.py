"""Track per-concept struggles across questions for cross-question concept threading.

Uses the Supabase ``concept_struggles`` table to record when a student makes
a mistake on a step tagged with specific concepts, and resolves them when
the student completes that step correctly.
"""

import logging
from typing import Any

from app.config import settings
from app.services.http_pool import get_client as get_http

log = logging.getLogger(__name__)


def _headers() -> dict[str, str]:
    return {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/json",
    }


async def record_struggle(
    user_id: str,
    document_id: str,
    concepts: list[str],
    question_number: int,
    step_index: int,
    part_label: str | None = None,
) -> None:
    """Upsert a 'struggling' row for each concept. Increments mistake_count on conflict."""
    if not concepts or not settings.supabase_service_role_key:
        return

    url = f"{settings.supabase_url}/rest/v1/concept_struggles"
    headers = _headers()
    headers["Prefer"] = "resolution=merge-duplicates,return=minimal"

    rows = [
        {
            "user_id": user_id,
            "document_id": document_id,
            "concept": concept,
            "question_number": question_number,
            "step_index": step_index,
            "part_label": part_label,
            "status": "struggling",
        }
        for concept in concepts
    ]

    client = get_http()
    for row in rows:
        # Use upsert — on conflict, increment mistake_count via RPC or just re-insert
        # Supabase REST doesn't support increment on upsert, so we do select-then-update
        check_url = f"{url}?user_id=eq.{user_id}&document_id=eq.{document_id}&concept=eq.{row['concept']}&question_number=eq.{question_number}&step_index=eq.{step_index}"
        resp = await client.get(check_url, headers=_headers())
        existing = resp.json() if resp.status_code == 200 else []

        if existing:
            # Update: increment mistake_count, reset status to struggling
            row_id = existing[0]["id"]
            new_count = existing[0].get("mistake_count", 1) + 1
            patch_url = f"{url}?id=eq.{row_id}"
            await client.patch(
                patch_url,
                headers=headers,
                json={"mistake_count": new_count, "status": "struggling", "resolved_at": None},
            )
        else:
            # Insert new row
            await client.post(url, headers=headers, json=row)


async def resolve_struggles(
    user_id: str,
    document_id: str,
    concepts: list[str],
    question_number: int,
    step_index: int,
) -> None:
    """Mark matching concept struggles as resolved."""
    if not concepts or not settings.supabase_service_role_key:
        return

    url = f"{settings.supabase_url}/rest/v1/concept_struggles"
    headers = _headers()
    headers["Prefer"] = "return=minimal"

    client = get_http()
    for concept in concepts:
        patch_url = (
            f"{url}?user_id=eq.{user_id}&document_id=eq.{document_id}"
            f"&concept=eq.{concept}&question_number=eq.{question_number}"
            f"&step_index=eq.{step_index}&status=eq.struggling"
        )
        await client.patch(
            patch_url,
            headers=headers,
            json={"status": "resolved", "resolved_at": "now()"},
        )


async def get_prior_struggles(
    user_id: str,
    document_id: str,
    concepts: list[str],
    current_question_number: int,
) -> list[dict[str, Any]]:
    """Return prior struggles for any of the given concepts from OTHER questions.

    Only returns rows where status='struggling' and question_number differs
    from the current one — this is purely cross-question context.
    """
    if not concepts or not settings.supabase_service_role_key:
        return []

    url = f"{settings.supabase_url}/rest/v1/concept_struggles"
    # Build OR filter for concepts
    concept_filter = ",".join(f"concept.eq.{c}" for c in concepts)

    params = {
        "user_id": f"eq.{user_id}",
        "document_id": f"eq.{document_id}",
        "status": "eq.struggling",
        "question_number": f"neq.{current_question_number}",
        "or": f"({concept_filter})",
        "select": "concept,question_number,step_index,mistake_count,part_label",
    }

    client = get_http()
    resp = await client.get(url, params=params, headers=_headers())
    if resp.status_code != 200:
        log.warning(f"[concept-tracker] Failed to query struggles: {resp.status_code}")
        return []
    return resp.json()
