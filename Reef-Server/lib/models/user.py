"""Pydantic models for user profile endpoints."""

from pydantic import BaseModel


class UserProfileRequest(BaseModel):
    display_name: str | None = None
    email: str | None = None
    grade: str | None = None
    subjects: list[str] | None = None
    onboarding_completed: bool | None = None
    referral_source: str | None = None


class UserProfileResponse(BaseModel):
    apple_user_id: str
    display_name: str | None = None
    email: str | None = None
    grade: str | None = None
    subjects: list[str] | None = None
    onboarding_completed: bool = False
    referral_source: str | None = None
