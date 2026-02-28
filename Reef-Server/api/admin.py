"""Admin dashboard endpoints."""

from fastapi import APIRouter, HTTPException, Header, Query
from lib.database import get_pool
from lib.models import (
    AdminCostResponse,
    AdminOverviewResponse,
    AdminReasoningStatsResponse,
    AdminUserListResponse,
    AdminUserRow,
    DailyCostRow,
)

router = APIRouter(prefix="/api/admin", tags=["admin"])

_ADMIN_EMAILS = {"markshteyn1@gmail.com"}


async def _require_admin(authorization: str) -> str:
    """Verify Bearer token belongs to an admin user. Returns user_id."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    user_id = authorization[7:].strip()
    if not user_id:
        raise HTTPException(status_code=401, detail="Missing user identifier")

    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT email FROM user_profiles WHERE apple_user_id = $1",
            user_id,
        )

    if row is None or row["email"] not in _ADMIN_EMAILS:
        raise HTTPException(status_code=403, detail="Admin access required")

    return user_id


@router.get("/overview", response_model=AdminOverviewResponse)
async def admin_overview(authorization: str = Header(...)):
    """Dashboard summary: total users, documents, reasoning calls, cost, active sessions."""
    await _require_admin(authorization)
    pool = get_pool()

    from api.strokes import _active_sessions

    async with pool.acquire() as conn:
        user_count = await conn.fetchval("SELECT COUNT(*) FROM user_profiles")
        doc_count = await conn.fetchval("SELECT COUNT(*) FROM documents")

        reasoning_row = await conn.fetchrow("""
            SELECT
                COUNT(*) AS total,
                COALESCE(SUM(estimated_cost), 0) AS cost,
                COUNT(*) FILTER (WHERE action = 'speak') AS speak,
                COUNT(*) FILTER (WHERE action = 'silent') AS silent
            FROM reasoning_logs
        """)

    return AdminOverviewResponse(
        total_users=user_count or 0,
        total_documents=doc_count or 0,
        total_reasoning_calls=reasoning_row["total"],
        total_cost=round(float(reasoning_row["cost"]), 4),
        speak_count=reasoning_row["speak"],
        silent_count=reasoning_row["silent"],
        active_sessions=len(_active_sessions),
    )


@router.get("/users", response_model=AdminUserListResponse)
async def admin_users(
    authorization: str = Header(...),
    search: str = Query("", description="Search by name or email"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    """User list with activity stats."""
    await _require_admin(authorization)
    pool = get_pool()

    search_filter = ""
    args: list = []
    idx = 1

    if search:
        search_filter = f"WHERE u.display_name ILIKE ${idx} OR u.email ILIKE ${idx}"
        args.append(f"%{search}%")
        idx += 1

    async with pool.acquire() as conn:
        total = await conn.fetchval(
            f"SELECT COUNT(*) FROM user_profiles u {search_filter}",
            *args,
        )

        rows = await conn.fetch(
            f"""
            SELECT
                u.apple_user_id,
                u.display_name,
                u.email,
                u.created_at::text AS created_at,
                MAX(s.received_at)::text AS last_active,
                COUNT(DISTINCT s.session_id) AS session_count,
                COALESCE(r.reasoning_calls, 0) AS reasoning_calls
            FROM user_profiles u
            LEFT JOIN stroke_logs s ON s.user_id = u.apple_user_id
            LEFT JOIN (
                SELECT
                    sl.user_id,
                    COUNT(rl.id) AS reasoning_calls
                FROM reasoning_logs rl
                JOIN stroke_logs sl ON sl.session_id = rl.session_id
                GROUP BY sl.user_id
            ) r ON r.user_id = u.apple_user_id
            {search_filter}
            GROUP BY u.apple_user_id, u.display_name, u.email, u.created_at, r.reasoning_calls
            ORDER BY last_active DESC NULLS LAST
            LIMIT ${idx} OFFSET ${idx + 1}
            """,
            *args,
            limit,
            offset,
        )

    users = [
        AdminUserRow(
            apple_user_id=row["apple_user_id"],
            display_name=row["display_name"],
            email=row["email"],
            created_at=row["created_at"],
            last_active=row["last_active"],
            session_count=row["session_count"],
            reasoning_calls=row["reasoning_calls"],
        )
        for row in rows
    ]

    return AdminUserListResponse(users=users, total=total or 0)


@router.get("/costs", response_model=AdminCostResponse)
async def admin_costs(
    authorization: str = Header(...),
    days: int = Query(30, ge=1, le=365),
):
    """Daily cost breakdown for the last N days."""
    await _require_admin(authorization)
    pool = get_pool()

    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT
                created_at::date::text AS date,
                COUNT(*) AS calls,
                SUM(prompt_tokens) AS prompt_tokens,
                SUM(completion_tokens) AS completion_tokens,
                SUM(estimated_cost) AS cost
            FROM reasoning_logs
            WHERE created_at >= NOW() - ($1 || ' days')::interval
            GROUP BY created_at::date
            ORDER BY date DESC
            """,
            str(days),
        )

    daily_rows = [
        DailyCostRow(
            date=row["date"],
            calls=row["calls"],
            prompt_tokens=row["prompt_tokens"],
            completion_tokens=row["completion_tokens"],
            cost=round(float(row["cost"]), 4),
        )
        for row in rows
    ]

    total_cost = sum(r.cost for r in daily_rows)
    total_calls = sum(r.calls for r in daily_rows)

    return AdminCostResponse(
        rows=daily_rows,
        total_cost=round(total_cost, 4),
        total_calls=total_calls,
    )


@router.get("/reasoning", response_model=AdminReasoningStatsResponse)
async def admin_reasoning(authorization: str = Header(...)):
    """Reasoning analytics: speak/silent ratio, avg tokens, errors, by source."""
    await _require_admin(authorization)
    pool = get_pool()

    async with pool.acquire() as conn:
        stats = await conn.fetchrow("""
            SELECT
                COUNT(*) AS total,
                COUNT(*) FILTER (WHERE action = 'speak') AS speak,
                COUNT(*) FILTER (WHERE action = 'silent') AS silent,
                COUNT(*) FILTER (WHERE error_type IS NOT NULL) AS errors,
                COALESCE(AVG(prompt_tokens), 0) AS avg_prompt,
                COALESCE(AVG(completion_tokens), 0) AS avg_completion
            FROM reasoning_logs
        """)

        source_rows = await conn.fetch("""
            SELECT source, COUNT(*) AS cnt
            FROM reasoning_logs
            GROUP BY source
        """)

    by_source = {row["source"]: row["cnt"] for row in source_rows}

    return AdminReasoningStatsResponse(
        total_calls=stats["total"],
        speak_count=stats["speak"],
        silent_count=stats["silent"],
        error_count=stats["errors"],
        avg_prompt_tokens=round(float(stats["avg_prompt"]), 1),
        avg_completion_tokens=round(float(stats["avg_completion"]), 1),
        by_source=by_source,
    )
