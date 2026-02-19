"""Dev-only endpoint for the tutor evaluation harness.

Allows the harness to trigger reasoning on-demand without waiting for
the 2.5s debounce timer. Only registered when ENVIRONMENT=development.
"""

from fastapi import APIRouter, Query

from lib.reasoning import run_reasoning

router = APIRouter()


@router.post("/api/harness/trigger-reasoning")
async def trigger_reasoning(
    session_id: str = Query(...),
    page: int = Query(default=1),
):
    """Trigger reasoning immediately for a given session/page.

    Returns the reasoning result: {"action": "speak"|"silent", "message": "..."}.
    """
    result = await run_reasoning(session_id, page)
    return result
