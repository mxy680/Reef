"""User profile endpoints."""

import json

from fastapi import APIRouter, HTTPException, Header
from lib.database import get_pool
from lib.models import UserProfileRequest, UserProfileResponse

router = APIRouter(prefix="/users", tags=["users"])


def _get_user_id(authorization: str) -> str:
    """Extract user ID from 'Bearer <user_id>' header."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    user_id = authorization[7:].strip()
    if not user_id:
        raise HTTPException(status_code=401, detail="Missing user identifier")
    return user_id


@router.put("/profile", response_model=UserProfileResponse)
async def upsert_profile(
    body: UserProfileRequest,
    authorization: str = Header(...),
):
    """Upsert user profile. Null fields don't overwrite existing data."""
    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    user_id = _get_user_id(authorization)
    subjects_json = json.dumps(body.subjects) if body.subjects is not None else None

    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO user_profiles (apple_user_id, display_name, email, grade, subjects, onboarding_completed, referral_source)
            VALUES ($1, $2, $3, $4, $5::jsonb, COALESCE($6, FALSE), $7)
            ON CONFLICT (apple_user_id) DO UPDATE SET
                display_name = COALESCE($2, user_profiles.display_name),
                email = COALESCE($3, user_profiles.email),
                grade = COALESCE($4, user_profiles.grade),
                subjects = COALESCE($5::jsonb, user_profiles.subjects),
                onboarding_completed = COALESCE($6, user_profiles.onboarding_completed),
                referral_source = COALESCE($7, user_profiles.referral_source),
                updated_at = NOW()
            RETURNING apple_user_id, display_name, email, grade, subjects, onboarding_completed, referral_source
            """,
            user_id,
            body.display_name,
            body.email,
            body.grade,
            subjects_json,
            body.onboarding_completed,
            body.referral_source,
        )

    return UserProfileResponse(
        apple_user_id=row["apple_user_id"],
        display_name=row["display_name"],
        email=row["email"],
        grade=row["grade"],
        subjects=json.loads(row["subjects"]) if row["subjects"] else [],
        onboarding_completed=row["onboarding_completed"] or False,
        referral_source=row["referral_source"],
    )


@router.get("/profile", response_model=UserProfileResponse)
async def get_profile(authorization: str = Header(...)):
    """Get current user's profile."""
    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    user_id = _get_user_id(authorization)

    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT apple_user_id, display_name, email, grade, subjects, onboarding_completed, referral_source FROM user_profiles WHERE apple_user_id = $1",
            user_id,
        )

    if row is None:
        raise HTTPException(status_code=404, detail="Profile not found")

    return UserProfileResponse(
        apple_user_id=row["apple_user_id"],
        display_name=row["display_name"],
        email=row["email"],
        grade=row["grade"],
        subjects=json.loads(row["subjects"]) if row["subjects"] else [],
        onboarding_completed=row["onboarding_completed"] or False,
        referral_source=row["referral_source"],
    )


@router.delete("/profile")
async def delete_profile(authorization: str = Header(...)):
    """Delete current user's profile."""
    pool = get_pool()
    if pool is None:
        raise HTTPException(status_code=503, detail="Database not available")

    user_id = _get_user_id(authorization)

    async with pool.acquire() as conn:
        result = await conn.execute(
            "DELETE FROM user_profiles WHERE apple_user_id = $1",
            user_id,
        )

    if result == "DELETE 0":
        raise HTTPException(status_code=404, detail="Profile not found")

    return {"status": "deleted"}
